-- Guarda cuándo un técnico ve una solicitud

create table if not exists vistas_solicitud (
  solicitud_id uuid not null references solicitudes(id) on delete cascade,
  prestador_id uuid not null references prestadores(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key (solicitud_id, prestador_id)
);
create index if not exists vistas_solicitud_prestador_idx on vistas_solicitud (prestador_id);

alter table vistas_solicitud enable row level security;

drop policy if exists "tecnico registra su vista" on vistas_solicitud;
create policy "tecnico registra su vista" on vistas_solicitud for insert
  with check (prestador_id = auth.uid());

drop policy if exists "vistas propias o admin" on vistas_solicitud;
create policy "vistas propias o admin" on vistas_solicitud for select
  using (prestador_id = auth.uid() or es_admin());
