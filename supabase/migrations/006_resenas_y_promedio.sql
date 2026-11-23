-- Muestra el tipo de trabajo en las reseñas y calcula el promedio del técnico

create or replace function public.resenas_prestador(p_id uuid)
returns table (autor text, puntaje smallint, resena text, creado_en timestamptz, categoria text)
language sql stable security definer set search_path = public as $$
  select a.nombre, c.puntaje, c.resena, c.creado_en, cat.nombre
  from calificaciones c
  join perfiles a     on a.id = c.autor_id
  join solicitudes s  on s.id = c.solicitud_id
  join categorias cat on cat.id = s.categoria_id
  where c.receptor_id = p_id
  order by c.creado_en desc
  limit 20
$$;
revoke all on function public.resenas_prestador(uuid) from public, anon;
grant execute on function public.resenas_prestador(uuid) to authenticated;

create or replace function public.actualizar_promedio_prestador() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update prestadores
     set calificacion_prom = (select round(avg(puntaje)::numeric, 2) from calificaciones where receptor_id = new.receptor_id)
   where id = new.receptor_id;
  return new;
end $$;

drop trigger if exists trg_promedio_prestador on calificaciones;
create trigger trg_promedio_prestador after insert on calificaciones
  for each row execute function public.actualizar_promedio_prestador();

update prestadores p
   set calificacion_prom = x.prom
  from (select receptor_id, round(avg(puntaje)::numeric, 2) prom from calificaciones group by receptor_id) x
 where x.receptor_id = p.id;

create or replace function public.proteger_columnas() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or es_admin() or pg_trigger_depth() > 1 then
    return new;
  end if;

  if tg_table_name = 'perfiles' then
    if tg_op = 'UPDATE' and (new.id is distinct from old.id or new.rol is distinct from old.rol
                             or new.suspendido is distinct from old.suspendido) then
      raise exception 'No puedes cambiar el rol ni el estado de la cuenta' using errcode = '42501';
    end if;
    if tg_op = 'INSERT' then
      new.suspendido := false;
    end if;

  elsif tg_table_name = 'prestadores' then
    if tg_op = 'UPDATE' and (new.id is distinct from old.id or new.verificado is distinct from old.verificado
                             or new.calificacion_prom is distinct from old.calificacion_prom
                             or new.servicios_completados is distinct from old.servicios_completados) then
      raise exception 'Solo un administrador puede verificar prestadores o cambiar su calificación' using errcode = '42501';
    end if;
    if tg_op = 'INSERT' then
      new.verificado := false;
      new.calificacion_prom := 0;
      new.servicios_completados := 0;
    end if;

  elsif tg_table_name = 'solicitudes' then
    if tg_op = 'UPDATE' and (new.id is distinct from old.id or new.cliente_id is distinct from old.cliente_id
                             or new.estado is distinct from old.estado or new.prestador_id is distinct from old.prestador_id
                             or new.precio_acordado is distinct from old.precio_acordado
                             or new.contratada is distinct from old.contratada
                             or new.prob_contratacion is distinct from old.prob_contratacion
                             or new.radio_actual_km is distinct from old.radio_actual_km
                             or new.cerrado_en is distinct from old.cerrado_en
                             or new.llegada_reportada_en is distinct from old.llegada_reportada_en
                             or new.llegada_confirmada_en is distinct from old.llegada_confirmada_en
                             or new.iniciado_en is distinct from old.iniciado_en
                             or new.fin_reportado_en is distinct from old.fin_reportado_en
                             or new.rechazos_llegada is distinct from old.rechazos_llegada
                             or new.rechazos_fin is distinct from old.rechazos_fin
                             or new.en_revision is distinct from old.en_revision) then
      raise exception 'El estado y la asignación de una solicitud solo cambian a través de la app' using errcode = '42501';
    end if;
    if tg_op = 'INSERT' then
      new.estado := 'publicada';
      new.prestador_id := null;
      new.precio_acordado := null;
      new.contratada := null;
      new.cerrado_en := null;
      new.llegada_reportada_en := null;
      new.llegada_confirmada_en := null;
      new.iniciado_en := null;
      new.fin_reportado_en := null;
      new.rechazos_llegada := 0;
      new.rechazos_fin := 0;
      new.en_revision := false;
    end if;
  end if;

  return new;
end $$;
