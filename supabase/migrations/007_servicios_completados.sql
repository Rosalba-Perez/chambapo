-- Cuenta los servicios completados de cada técnico

create or replace function public.recalcular_servicios_prestador() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update prestadores p
     set servicios_completados = (select count(*) from solicitudes s where s.prestador_id = p.id and s.estado = 'finalizada')
   where p.id in (new.prestador_id, old.prestador_id);
  return new;
end $$;

drop trigger if exists trg_servicios_prestador on solicitudes;
create trigger trg_servicios_prestador
  after update of estado, prestador_id on solicitudes
  for each row
  when ((old.estado = 'finalizada') is distinct from (new.estado = 'finalizada') or old.prestador_id is distinct from new.prestador_id)
  execute function public.recalcular_servicios_prestador();

update prestadores p
   set servicios_completados = (select count(*) from solicitudes s where s.prestador_id = p.id and s.estado = 'finalizada');
