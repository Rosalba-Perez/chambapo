-- Agrega los pasos del servicio: llegada, código de inicio y fin del trabajo

alter table solicitudes
  add column if not exists llegada_reportada_en  timestamptz,
  add column if not exists llegada_confirmada_en timestamptz,
  add column if not exists iniciado_en           timestamptz,
  add column if not exists fin_reportado_en      timestamptz,
  add column if not exists rechazos_llegada      smallint not null default 0,
  add column if not exists rechazos_fin          smallint not null default 0,
  add column if not exists en_revision           boolean  not null default false;

create table if not exists codigos_inicio (
  solicitud_id uuid primary key references solicitudes(id) on delete cascade,
  codigo       text not null,
  intentos     smallint not null default 0,
  creado_en    timestamptz not null default now()
);
alter table codigos_inicio enable row level security;

create table if not exists eventos_servicio (
  id           bigserial primary key,
  solicitud_id uuid not null references solicitudes(id) on delete cascade,
  actor_id     uuid references perfiles(id),
  tipo         text not null,
  detalle      text,
  creado_en    timestamptz not null default now()
);
create index if not exists eventos_servicio_solicitud_idx on eventos_servicio (solicitud_id, creado_en);
alter table eventos_servicio enable row level security;

drop policy if exists "eventos visibles a las partes" on eventos_servicio;
create policy "eventos visibles a las partes" on eventos_servicio for select
  using (es_admin() or exists (select 1 from solicitudes s where s.id = solicitud_id
                               and (s.cliente_id = auth.uid() or s.prestador_id = auth.uid())));
