-- Sirve para crear el perfil automáticamente cuando alguien se registra

create or replace function public.crear_perfil_al_registrarse() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_rol rol := case when meta->>'rol' = 'prestador' then 'prestador'::rol else 'cliente'::rol end;
  v_nombre text := coalesce(nullif(trim(meta->>'nombre'), ''), split_part(new.email, '@', 1));
  v_oficios text[] := case when jsonb_typeof(meta->'oficios') = 'array'
                           then array(select jsonb_array_elements_text(meta->'oficios'))
                           else '{}' end;
begin
  insert into perfiles (id, rol, nombre, telefono)
  values (new.id, v_rol, v_nombre, nullif(trim(meta->>'telefono'), ''))
  on conflict (id) do nothing;

  if v_rol = 'prestador' then
    insert into prestadores (id, oficios) values (new.id, v_oficios)
    on conflict (id) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists trg_crear_perfil_al_registrarse on auth.users;
create trigger trg_crear_perfil_al_registrarse
  after insert on auth.users
  for each row execute function public.crear_perfil_al_registrarse();

drop policy if exists "crear perfil propio" on perfiles;
create policy "crear perfil propio" on perfiles for insert
  with check (id = auth.uid() and rol in ('cliente', 'prestador'));
