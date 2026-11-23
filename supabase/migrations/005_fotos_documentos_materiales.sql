-- Agrega fotos, documentos del técnico, materiales y la categoría «Otros»

insert into categorias (nombre) values ('otros') on conflict (nombre) do nothing;

alter table solicitudes
  add column if not exists tiene_materiales boolean,
  add column if not exists materiales       text;

alter table prestadores
  add column if not exists documento_reverso_url text,
  add column if not exists certificado_url       text;

update storage.buckets
   set public = true, file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'fotos';

drop policy if exists "fotos: ver las propias" on storage.objects;
create policy "fotos: ver las propias" on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "fotos: subir en su carpeta" on storage.objects;
create policy "fotos: subir en su carpeta" on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "fotos: cambiar las propias" on storage.objects;
create policy "fotos: cambiar las propias" on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "fotos: borrar las propias" on storage.objects;
create policy "fotos: borrar las propias" on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = auth.uid()::text);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documentos', 'documentos', false, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
                               allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "documentos: ver propios o admin" on storage.objects;
create policy "documentos: ver propios o admin" on storage.objects for select to authenticated
  using (bucket_id = 'documentos' and ((storage.foldername(name))[1] = auth.uid()::text or public.es_admin()));
drop policy if exists "documentos: subir en su carpeta" on storage.objects;
create policy "documentos: subir en su carpeta" on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "documentos: cambiar los propios" on storage.objects;
create policy "documentos: cambiar los propios" on storage.objects for update to authenticated
  using (bucket_id = 'documentos' and (storage.foldername(name))[1] = auth.uid()::text);
