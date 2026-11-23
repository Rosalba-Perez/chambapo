-- Crea las tablas principales de la app
create extension if not exists postgis;

create type rol as enum ('cliente', 'prestador', 'admin');
create type estado_solicitud as enum (
  'publicada', 'con_postulaciones', 'asignada', 'en_camino', 'en_curso',
  'finalizada', 'cancelada', 'expirada');
create type franja as enum ('madrugada', 'manana', 'tarde', 'noche');

-- Tabla de perfiles de usuario
create table perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  rol rol not null default 'cliente',
  nombre text not null,
  telefono text,
  foto_url text,
  fcm_token text,
  suspendido boolean not null default false,
  creado_en timestamptz not null default now()
);

create table prestadores (
  id uuid primary key references perfiles(id) on delete cascade,
  oficios text[] not null default '{}',
  descripcion text,
  zona_habitual text,
  documento_url text,
  verificado boolean not null default false,
  disponible boolean not null default false,
  ubicacion geography(point, 4326),
  ubicacion_en timestamptz,
  calificacion_prom numeric(3,2) default 0,
  servicios_completados int not null default 0
);
create index prestadores_ubicacion_idx on prestadores using gist (ubicacion);

-- Tablas de solicitudes y servicios
create table categorias (
  id serial primary key,
  nombre text unique not null
);
insert into categorias (nombre) values
  ('plomeria'), ('electricidad'), ('aire_acondicionado'), ('electrodomesticos'),
  ('pintura'), ('cerrajeria'), ('carpinteria'), ('albanileria');

create table solicitudes (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references perfiles(id),
  categoria_id int not null references categorias(id),
  descripcion text not null,
  fotos text[] default '{}',
  presupuesto numeric(12,0),
  fecha_deseada timestamptz,
  ubicacion geography(point, 4326) not null,
  barrio text,
  estado estado_solicitud not null default 'publicada',
  radio_actual_km numeric(5,2) not null default 2,
  prestador_id uuid references perfiles(id),
  precio_acordado numeric(12,0),
  dia_semana smallint,
  franja_horaria franja,
  dias_anticipacion int default 0,
  prob_contratacion numeric(4,3),
  contratada boolean,
  creado_en timestamptz not null default now(),
  cerrado_en timestamptz
);
create index solicitudes_ubicacion_idx on solicitudes using gist (ubicacion);
create index solicitudes_estado_idx on solicitudes (estado);

create table postulaciones (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references solicitudes(id) on delete cascade,
  prestador_id uuid not null references perfiles(id),
  precio numeric(12,0) not null,
  minutos_llegada int not null,
  creado_en timestamptz not null default now(),
  unique (solicitud_id, prestador_id)
);

create table posiciones (
  id bigserial primary key,
  solicitud_id uuid not null references solicitudes(id) on delete cascade,
  prestador_id uuid not null references perfiles(id),
  lat double precision not null,
  lng double precision not null,
  creado_en timestamptz not null default now()
);

create table mensajes (
  id bigserial primary key,
  solicitud_id uuid not null references solicitudes(id) on delete cascade,
  emisor_id uuid not null references perfiles(id),
  texto text not null,
  creado_en timestamptz not null default now()
);

create table calificaciones (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references solicitudes(id),
  autor_id uuid not null references perfiles(id),
  receptor_id uuid not null references perfiles(id),
  puntaje smallint not null check (puntaje between 1 and 5),
  resena text,
  creado_en timestamptz not null default now(),
  unique (solicitud_id, autor_id)
);

create table reportes (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid references solicitudes(id),
  autor_id uuid not null references perfiles(id),
  reportado_id uuid not null references perfiles(id),
  motivo text not null,
  atendido boolean not null default false,
  creado_en timestamptz not null default now()
);

create table parametros (
  clave text primary key,
  valor numeric not null
);
insert into parametros values
  ('radio_inicial_km', 2), ('radio_incremento_km', 2), ('radio_maximo_km', 10),
  ('tiempo_espera_min', 10), ('horas_expiracion', 24);

create or replace function solicitudes_derivadas() returns trigger as $$
declare h int;
begin
  new.dia_semana := extract(isodow from new.creado_en at time zone 'America/Bogota') - 1;
  h := extract(hour from new.creado_en at time zone 'America/Bogota');
  new.franja_horaria := case when h < 6 then 'madrugada' when h < 12 then 'manana'
                             when h < 18 then 'tarde' else 'noche' end;
  new.dias_anticipacion := coalesce(
      greatest(0, (new.fecha_deseada::date - new.creado_en::date)), 0);
  return new;
end $$ language plpgsql;
create trigger trg_solicitudes_derivadas before insert on solicitudes
  for each row execute function solicitudes_derivadas();

alter publication supabase_realtime add table posiciones, mensajes, postulaciones, solicitudes;

-- Permisos: quién puede ver y editar cada cosa
alter table perfiles enable row level security;
alter table prestadores enable row level security;
alter table solicitudes enable row level security;
alter table postulaciones enable row level security;
alter table posiciones enable row level security;
alter table mensajes enable row level security;
alter table calificaciones enable row level security;
alter table reportes enable row level security;
alter table categorias enable row level security;
alter table parametros enable row level security;

create or replace function es_admin() returns boolean as $$
  select exists (select 1 from perfiles where id = auth.uid() and rol = 'admin');
$$ language sql stable security definer;

create policy "perfil propio o admin" on perfiles for select
  using (id = auth.uid() or es_admin() or true);
create policy "editar perfil propio" on perfiles for update using (id = auth.uid());
create policy "crear perfil propio" on perfiles for insert with check (id = auth.uid());

create policy "prestadores visibles" on prestadores for select using (true);
create policy "prestador edita lo suyo" on prestadores for all using (id = auth.uid());

create policy "categorias lectura" on categorias for select using (true);
create policy "parametros lectura" on parametros for select using (true);

create policy "cliente ve sus solicitudes" on solicitudes for select
  using (cliente_id = auth.uid() or prestador_id = auth.uid() or es_admin()
         or exists (select 1 from prestadores p where p.id = auth.uid() and p.verificado));
create policy "cliente crea solicitud" on solicitudes for insert with check (cliente_id = auth.uid());
create policy "cliente edita su solicitud" on solicitudes for update using (cliente_id = auth.uid());

create policy "postulaciones visibles a las partes" on postulaciones for select
  using (prestador_id = auth.uid() or es_admin()
         or exists (select 1 from solicitudes s where s.id = solicitud_id and s.cliente_id = auth.uid()));
create policy "prestador postula" on postulaciones for insert
  with check (prestador_id = auth.uid()
              and exists (select 1 from prestadores p where p.id = auth.uid() and p.verificado));

create policy "posiciones del servicio" on posiciones for select
  using (prestador_id = auth.uid()
         or exists (select 1 from solicitudes s where s.id = solicitud_id and s.cliente_id = auth.uid()));
create policy "prestador publica posicion" on posiciones for insert
  with check (prestador_id = auth.uid()
              and exists (select 1 from solicitudes s where s.id = solicitud_id
                          and s.prestador_id = auth.uid() and s.estado in ('asignada','en_camino','en_curso')));

create policy "mensajes entre las partes" on mensajes for select
  using (exists (select 1 from solicitudes s where s.id = solicitud_id
                 and (s.cliente_id = auth.uid() or s.prestador_id = auth.uid())));
create policy "enviar mensaje" on mensajes for insert
  with check (emisor_id = auth.uid()
              and exists (select 1 from solicitudes s where s.id = solicitud_id
                          and (s.cliente_id = auth.uid() or s.prestador_id = auth.uid())));

create policy "calificaciones publicas" on calificaciones for select using (true);
create policy "calificar" on calificaciones for insert with check (autor_id = auth.uid());

create policy "reportar" on reportes for insert with check (autor_id = auth.uid());
create policy "reportes admin" on reportes for select using (autor_id = auth.uid() or es_admin());

create or replace function prestadores_cercanos(p_solicitud uuid, p_radio_km numeric)
returns table (prestador_id uuid, distancia_km numeric, fcm_token text) as $$
  select p.id,
         round((st_distance(p.ubicacion, s.ubicacion) / 1000)::numeric, 2),
         pf.fcm_token
  from solicitudes s
  join categorias c on c.id = s.categoria_id
  join prestadores p on p.disponible and p.verificado
       and c.nombre = any (p.oficios)
       and st_dwithin(p.ubicacion, s.ubicacion, p_radio_km * 1000)
  join perfiles pf on pf.id = p.id and not pf.suspendido
  where s.id = p_solicitud
  order by 2;
$$ language sql stable security definer;

create policy "admin gestiona perfiles" on perfiles for update using (es_admin());
create policy "admin gestiona prestadores" on prestadores for update using (es_admin());
create policy "admin atiende reportes" on reportes for update using (es_admin());
create policy "admin ajusta parametros" on parametros for update using (es_admin());

create or replace function solicitud_coordenadas(p_id uuid)
returns table (lat double precision, lng double precision) as $$
  select st_y(ubicacion::geometry), st_x(ubicacion::geometry) from solicitudes where id = p_id;
$$ language sql stable security invoker;
