-- NOOK — configuración de herramientas del menú principal (sección "Configuración"
-- del panel de control, pedida por Mario el 20-sep-2026: alta/edición/baja de
-- herramientas sin tocar el repo, con roles y apariencia, más subida de una
-- herramienta nueva (.html autocontenido) sin necesitar ningún token de GitHub.
--
-- Alcance: solo las 3 tarjetas de la fila secundaria del menú (formatos/, bitacora/,
-- salon-barra/) más cualquier herramienta nueva subida. La tarjeta "Cocina" (destacada,
-- ancho completo, con chips 1-2-3) NO se mueve a esta tabla — es el flujo principal ya
-- construido, estructuralmente distinto (un hub, no una tarjeta suelta), se deja tal
-- cual en index.html para no arriesgar su diseño.
--
-- Seguridad: mismo patrón exacto que admin_list_profiles/admin_set_profile
-- (20260918000000_profiles_and_auth_gate.sql) — solo mario@delamorazumaran.com
-- puede escribir, verificado del lado del servidor con auth.email(), no por rol
-- dentro de la propia tabla.

-- =========================================================================
-- 1. herramientas
-- =========================================================================
create table if not exists public.herramientas (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  nombre text not null,
  descripcion text not null default '',
  color text not null default 'tan' check (color in ('tan','deep','brown')),
  estado text not null default 'activa' check (estado in ('activa','proximamente')),
  roles text[] not null default array['chef','gerencia'],
  orden int not null default 100,
  origen text not null check (origen in ('nativa','subida')),
  storage_path text,
  ruta_nativa text,
  created_at timestamptz not null default now(),
  constraint herramientas_origen_coherente check (
    (origen = 'nativa' and ruta_nativa is not null and storage_path is null) or
    (origen = 'subida' and storage_path is not null and ruta_nativa is null)
  )
);

alter table public.herramientas enable row level security;
revoke all on public.herramientas from anon, authenticated;

-- =========================================================================
-- 2. Lectura pública (el listado de herramientas no es dato sensible —
--    mismo criterio de CLAUDE.md que ya aplica a fichas/recetario)
-- =========================================================================
create or replace function public.public_list_herramientas()
returns setof public.herramientas
language sql
security definer
set search_path = public
stable
as $$
  select * from public.herramientas order by orden asc, created_at asc;
$$;

revoke all on function public.public_list_herramientas() from public;
grant execute on function public.public_list_herramientas() to anon, authenticated;

-- =========================================================================
-- 3. Escritura — solo mario@delamorazumaran.com
-- =========================================================================
create or replace function public.admin_list_herramientas()
returns setof public.herramientas
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede administrar herramientas.';
  end if;
  return query select * from public.herramientas order by orden asc, created_at asc;
end;
$$;

create or replace function public.admin_upsert_herramienta(
  p_id uuid,
  p_slug text,
  p_nombre text,
  p_descripcion text,
  p_color text,
  p_estado text,
  p_roles text[],
  p_orden int,
  p_origen text,
  p_storage_path text,
  p_ruta_nativa text
)
returns public.herramientas
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.herramientas;
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede administrar herramientas.';
  end if;
  if p_estado not in ('activa','proximamente') then
    raise exception 'Estado inválido: %', p_estado;
  end if;
  if p_color not in ('tan','deep','brown') then
    raise exception 'Color inválido: %', p_color;
  end if;
  if p_origen not in ('nativa','subida') then
    raise exception 'Origen inválido: %', p_origen;
  end if;

  if p_id is null then
    insert into public.herramientas
      (slug, nombre, descripcion, color, estado, roles, orden, origen, storage_path, ruta_nativa)
    values
      (p_slug, p_nombre, p_descripcion, p_color, p_estado, p_roles, p_orden, p_origen, p_storage_path, p_ruta_nativa)
    returning * into result;
  else
    update public.herramientas set
      slug = p_slug,
      nombre = p_nombre,
      descripcion = p_descripcion,
      color = p_color,
      estado = p_estado,
      roles = p_roles,
      orden = p_orden,
      origen = p_origen,
      storage_path = p_storage_path,
      ruta_nativa = p_ruta_nativa
    where id = p_id
    returning * into result;
    if result.id is null then
      raise exception 'Herramienta no encontrada: %', p_id;
    end if;
  end if;
  return result;
end;
$$;

create or replace function public.admin_delete_herramienta(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede administrar herramientas.';
  end if;
  delete from public.herramientas where id = p_id;
  return true;
end;
$$;

revoke all on function public.admin_list_herramientas() from public, anon;
revoke all on function public.admin_upsert_herramienta(uuid,text,text,text,text,text,text[],int,text,text,text) from public, anon;
revoke all on function public.admin_delete_herramienta(uuid) from public, anon;
grant execute on function public.admin_list_herramientas() to authenticated;
grant execute on function public.admin_upsert_herramienta(uuid,text,text,text,text,text,text[],int,text,text,text) to authenticated;
grant execute on function public.admin_delete_herramienta(uuid) to authenticated;

-- =========================================================================
-- 4. Bucket de Storage para herramientas subidas desde el navegador
--    (sin token de GitHub — Mario sube, aparece al instante, aislado por
--    origen distinto de dmzkitchensupport.github.io)
-- =========================================================================
insert into storage.buckets (id, name, public)
values ('herramientas-subidas', 'herramientas-subidas', true)
on conflict (id) do nothing;

drop policy if exists "herramientas_subidas_lectura_publica" on storage.objects;
create policy "herramientas_subidas_lectura_publica" on storage.objects
  for select to public
  using (bucket_id = 'herramientas-subidas');

drop policy if exists "herramientas_subidas_insert_mario" on storage.objects;
create policy "herramientas_subidas_insert_mario" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'herramientas-subidas'
    and lower(coalesce(auth.email(), '')) = 'mario@delamorazumaran.com'
  );

drop policy if exists "herramientas_subidas_update_mario" on storage.objects;
create policy "herramientas_subidas_update_mario" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'herramientas-subidas'
    and lower(coalesce(auth.email(), '')) = 'mario@delamorazumaran.com'
  );

drop policy if exists "herramientas_subidas_delete_mario" on storage.objects;
create policy "herramientas_subidas_delete_mario" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'herramientas-subidas'
    and lower(coalesce(auth.email(), '')) = 'mario@delamorazumaran.com'
  );

-- =========================================================================
-- 5. Semilla — las 3 herramientas reales de la fila secundaria, tal como
--    viven hoy en index.html (verificado contra el archivo real antes de
--    escribir esto, no inventado)
-- =========================================================================
insert into public.herramientas (slug, nombre, descripcion, color, estado, roles, orden, origen, ruta_nativa)
values
  ('formatos', 'Formatos', 'Formatos operativos de NOOK', 'tan', 'proximamente', array['chef','gerencia'], 10, 'nativa', 'formatos/'),
  ('bitacora', 'Bitácora', 'Bitácora diaria A&B — captura, historial y cortes', 'deep', 'activa', array['gerencia'], 20, 'nativa', 'bitacora/'),
  ('salon-barra', 'Salón y Barra', 'Generador de fichas de bebidas — mismo formato del Generador, en blanco', 'brown', 'activa', array['gerencia'], 30, 'nativa', 'salon-barra/')
on conflict (slug) do nothing;
