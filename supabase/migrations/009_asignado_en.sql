-- Guarda el momento en que el cliente elige al técnico

alter table solicitudes add column if not exists asignado_en timestamptz;

update solicitudes s set asignado_en = p.creado_en
from postulaciones p
where s.asignado_en is null and s.prestador_id is not null
  and p.solicitud_id = s.id and p.prestador_id = s.prestador_id;

create or replace function public.proteger_asignado_en() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or es_admin() or pg_trigger_depth() > 1 then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.asignado_en := null;
  elsif new.asignado_en is distinct from old.asignado_en then
    raise exception 'No puedes cambiar la hora de asignación' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists proteger_asignado_en on solicitudes;
create trigger proteger_asignado_en before insert or update on solicitudes
  for each row execute function public.proteger_asignado_en();
