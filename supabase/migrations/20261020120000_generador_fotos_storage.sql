-- NOOK — Generador de Ficheros: fotos fuera del JSON + guardado con control de versión
--
-- Motivo (20-oct-2026, autorizado por Mario en esa sesión): la fila única de
-- generador_proyecto pesaba 35,302,894 bytes porque cada ficha llevaba su foto en
-- base64 a resolución completa. generador_load tardaba ~21-23 s y cada guardado
-- volvía a subir 35 MB contra un statement_timeout de 8 s (authenticated): los
-- guardados del chef José no llegaban a la nube desde el 24-sep.
--
-- Cambios (todos aditivos, ninguno borra datos):
--   1. Bucket público de lectura `generador-fotos`. Escritura (INSERT) solo con sesión
--      real chef/gerencia aprobada, misma regla que require_chef_o_gerencia(). Sin
--      policies de UPDATE/DELETE: una foto subida no se puede pisar ni borrar desde la
--      página. Las fotos se guardan como JPEG (lado máximo 2400 px, calidad 0.88) y el
--      nombre es el sha256 de la foto original: la misma foto siempre cae en la misma
--      ruta y nunca hace falta sobrescribir.
--   2. generador_load_v2(): devuelve {data, updated_at} para que el cliente sepa sobre
--      qué versión está trabajando.
--   3. generador_save_v2(p_data, p_base): guarda solo si la fila no cambió desde p_base
--      (si otro equipo guardó antes, responde conflict y el cliente vuelve a cargar,
--      fusiona y reintenta -- nunca "gana el último"). Rechaza fotos en base64 dentro
--      del JSON y el proyecto vacío sobre uno real.
--   4. generador_save(jsonb) (versión vieja de la página) queda deshabilitada: una
--      pestaña vieja abierta ya no puede pisar la nube sin fusionar. Sus cambios se
--      quedan en la caché local de ese equipo y se fusionan al recargar la página nueva.

-- 1. Bucket ----------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('generador-fotos', 'generador-fotos', true, 52428800, array['image/*'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Versión booleana de require_chef_o_gerencia() para usar dentro de una policy.
create or replace function public.es_chef_o_gerencia()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and rol in ('chef','gerencia') and aprobado = true
  );
$$;
revoke all on function public.es_chef_o_gerencia() from public, anon;
grant execute on function public.es_chef_o_gerencia() to authenticated;

drop policy if exists "generador_fotos_insert_chef_gerencia" on storage.objects;
create policy "generador_fotos_insert_chef_gerencia"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'generador-fotos' and public.es_chef_o_gerencia());

-- Lectura: el bucket es público (URL /object/public/...). Esta policy de SELECT solo
-- hace falta para que el cliente pueda detectar "ya existe" al subir sin error 403.
drop policy if exists "generador_fotos_select" on storage.objects;
create policy "generador_fotos_select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'generador-fotos');

-- 2. Carga con versión -------------------------------------------------------------
create or replace function public.generador_load_v2()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object('data', data, 'updated_at', updated_at)
  from public.generador_proyecto where id = 'main';
$$;
revoke all on function public.generador_load_v2() from public;
grant execute on function public.generador_load_v2() to anon, authenticated;

-- 3. Guardado con control de versión ---------------------------------------------
create or replace function public.generador_save_v2(p_data jsonb, p_base timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  n_nuevo int;
  n_actual int;
  v_actual timestamptz;
  v_nuevo timestamptz;
begin
  perform public.require_chef_o_gerencia();

  if position('data:image' in p_data::text) > 0 then
    raise exception 'rechazado: el proyecto trae fotos en base64; deben subirse primero al bucket generador-fotos';
  end if;

  select jsonb_array_length(coalesce(data->'cards', '[]'::jsonb)), updated_at
    into n_actual, v_actual
    from public.generador_proyecto
    where id = 'main'
    for update;

  if v_actual is not null and (p_base is null or v_actual <> p_base) then
    return jsonb_build_object('ok', false, 'conflict', true, 'updated_at', v_actual);
  end if;

  n_nuevo := jsonb_array_length(coalesce(p_data->'cards', '[]'::jsonb));
  if n_nuevo = 0 and coalesce(n_actual, 0) > 0 then
    raise exception 'rechazado: se intentó guardar un proyecto vacío (0 fichas) sobre uno real con % fichas', n_actual;
  end if;

  v_nuevo := clock_timestamp();
  insert into public.generador_proyecto (id, data, updated_at, updated_by)
  values ('main', p_data, v_nuevo, auth.uid())
  on conflict (id) do update set
    data = excluded.data,
    updated_at = v_nuevo,
    updated_by = auth.uid();
  return jsonb_build_object('ok', true, 'updated_at', v_nuevo);
end;
$$;
revoke all on function public.generador_save_v2(jsonb, timestamptz) from public, anon;
grant execute on function public.generador_save_v2(jsonb, timestamptz) to authenticated;

-- 4. Versión vieja deshabilitada (misma firma, para que una pestaña vieja reciba un error claro).
create or replace function public.generador_save(p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'versión vieja del Generador: recarga la página (Cmd+Shift+R / Ctrl+Shift+R). Tus cambios siguen guardados en este equipo y se fusionan al recargar.';
end;
$$;
