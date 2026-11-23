-- Mensajes no leídos, motivo de cancelación y cierre de revisiones

alter table mensajes add column if not exists leido_en timestamptz;
create index if not exists mensajes_no_leidos_idx on mensajes (solicitud_id) where leido_en is null;

create or replace function public.marcar_leidos(p_solicitud uuid) returns void
language sql security definer set search_path = public as $$
  update mensajes m set leido_en = now()
  from solicitudes s
  where s.id = p_solicitud and m.solicitud_id = s.id
    and m.emisor_id <> auth.uid() and m.leido_en is null
    and auth.uid() in (s.cliente_id, s.prestador_id)
$$;

create or replace function public.mensajes_no_leidos()
returns table (solicitud_id uuid, n bigint)
language sql stable security definer set search_path = public as $$
  select m.solicitud_id, count(*)
  from mensajes m join solicitudes s on s.id = m.solicitud_id
  where m.leido_en is null and m.emisor_id <> auth.uid()
    and auth.uid() in (s.cliente_id, s.prestador_id)
  group by m.solicitud_id
$$;
revoke all on function public.marcar_leidos(uuid) from public, anon;
revoke all on function public.mensajes_no_leidos() from public, anon;
grant execute on function public.marcar_leidos(uuid) to authenticated;
grant execute on function public.mensajes_no_leidos() to authenticated;

alter table solicitudes add column if not exists motivo_cancelacion text;
alter table solicitudes add column if not exists cancelada_por uuid references perfiles(id);
alter table solicitudes add column if not exists con_inconvenientes boolean not null default false;

update solicitudes s set con_inconvenientes = true
where not s.con_inconvenientes
  and (s.rechazos_llegada > 0 or s.rechazos_fin > 0 or s.en_revision
       or exists (select 1 from eventos_servicio e where e.solicitud_id = s.id and e.tipo = 'codigo_bloqueado'));

create or replace function public.proteger_asignado_en() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or es_admin() or pg_trigger_depth() > 1 then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.asignado_en := null;
    new.con_inconvenientes := false;
    new.motivo_cancelacion := null;
    new.cancelada_por := null;
  elsif new.asignado_en is distinct from old.asignado_en
     or new.con_inconvenientes is distinct from old.con_inconvenientes
     or new.motivo_cancelacion is distinct from old.motivo_cancelacion
     or new.cancelada_por is distinct from old.cancelada_por then
    raise exception 'No puedes cambiar estos datos de la solicitud' using errcode = '42501';
  end if;
  return new;
end $$;

drop policy if exists "admin gestiona solicitudes" on solicitudes;
create policy "admin gestiona solicitudes" on solicitudes for update using (es_admin());

create or replace function public.registrar_token(p_token text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  update perfiles set fcm_token = null where fcm_token = p_token and id <> auth.uid();
  update perfiles set fcm_token = p_token where id = auth.uid();
end $$;
revoke all on function public.registrar_token(text) from public, anon;
grant execute on function public.registrar_token(text) to authenticated;
