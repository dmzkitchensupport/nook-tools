-- NOOK — Salón y Barra: misma arquitectura que cocina (bloqueador #20, autorizado por Mario el
-- 20-oct-2026 en esa sesión).
--
-- Antes: fotos en base64 dentro de la única fila jsonb de salonbarra_proyecto y reemplazo
-- completo en cada guardado ("gana el último"). Mismo problema que tuvo generador_proyecto
-- (fila de 35 MB, guardados cortados por statement_timeout).
--
-- Estado real al aplicar: 1 fila ('main', 381 bytes, 1 ficha "Margarita 0.0" sin foto, guardada
-- por Mario el 19-oct). Respaldo previo: ~/dmz/respaldos/nook-tools/salonbarra_proyecto_2026-10-20_pre_v2.json
-- (sha256 73d60d14…). No hay fotos que migrar; la fila no se modifica.
--
-- Cambios (aditivos; no tocan datos):
--   1. Bucket público de lectura `salonbarra-fotos` (50 MB, solo image/*). INSERT solo con sesión
--      gerencia aprobada (salon-barra/ solo admite gerencia; misma regla que require_gerencia()).
--      Sin UPDATE/DELETE: una foto subida no se pisa ni se borra. Nombre = sha256 de la foto
--      original; JPEG lado máximo 2400 px, calidad 0.88 (lo hace la página).
--   2. salonbarra_load_v2(): {data, updated_at}.
--   3. salonbarra_save_v2(p_data, p_base): control de versión (conflict si otro equipo guardó
--      antes), rechaza base64, rechaza proyecto sin contenido (0 fichas y 0 grupos del Índice)
--      sobre uno real, y rechaza perder versiones de archivo_conflictos.
--   4. salonbarra_save(jsonb) (página vieja) queda deshabilitada con "recarga la página".

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('salonbarra-fotos', 'salonbarra-fotos', true, 52428800, array['image/*'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.es_gerencia()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and rol = 'gerencia' and aprobado = true
  );
$$;
revoke all on function public.es_gerencia() from public, anon;
grant execute on function public.es_gerencia() to authenticated;

drop policy if exists "salonbarra_fotos_insert_gerencia" on storage.objects;
create policy "salonbarra_fotos_insert_gerencia"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'salonbarra-fotos' and public.es_gerencia());

drop policy if exists "salonbarra_fotos_select" on storage.objects;
create policy "salonbarra_fotos_select"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'salonbarra-fotos');

create or replace function public.salonbarra_load_v2()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object('data', data, 'updated_at', updated_at)
  from public.salonbarra_proyecto where id = 'main';
$$;
revoke all on function public.salonbarra_load_v2() from public;
grant execute on function public.salonbarra_load_v2() to anon, authenticated;

create or replace function public.salonbarra_save_v2(p_data jsonb, p_base timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  n_nuevo int;
  n_actual int;
  a_nuevo int;
  a_actual int;
  v_actual timestamptz;
  v_nuevo timestamptz;
begin
  perform public.require_gerencia();

  if position('data:image' in p_data::text) > 0 then
    raise exception 'rechazado: el proyecto trae fotos en base64; deben subirse primero al bucket salonbarra-fotos';
  end if;

  select public.salonbarra_contenido(data),
         case when jsonb_typeof(data->'archivo_conflictos') = 'array'
              then jsonb_array_length(data->'archivo_conflictos') else 0 end,
         updated_at
    into n_actual, a_actual, v_actual
    from public.salonbarra_proyecto
    where id = 'main'
    for update;

  if v_actual is not null and (p_base is null or v_actual <> p_base) then
    return jsonb_build_object('ok', false, 'conflict', true, 'updated_at', v_actual);
  end if;

  n_nuevo := public.salonbarra_contenido(p_data);
  if n_nuevo = 0 and coalesce(n_actual, 0) > 0 then
    raise exception 'rechazado: se intentó guardar un proyecto vacío (0 fichas y 0 grupos) sobre uno real con % elementos', n_actual;
  end if;

  a_nuevo := case when jsonb_typeof(p_data->'archivo_conflictos') = 'array'
                  then jsonb_array_length(p_data->'archivo_conflictos') else 0 end;
  if a_nuevo < coalesce(a_actual, 0) then
    raise exception 'rechazado: el guardado perdería versiones archivadas (% en la nube, % en el guardado); recarga la página', a_actual, a_nuevo;
  end if;

  v_nuevo := clock_timestamp();
  insert into public.salonbarra_proyecto (id, data, updated_at, updated_by)
  values ('main', p_data, v_nuevo, auth.uid())
  on conflict (id) do update set
    data = excluded.data,
    updated_at = v_nuevo,
    updated_by = auth.uid();
  return jsonb_build_object('ok', true, 'updated_at', v_nuevo);
end;
$$;
revoke all on function public.salonbarra_save_v2(jsonb, timestamptz) from public, anon;
grant execute on function public.salonbarra_save_v2(jsonb, timestamptz) to authenticated;

create or replace function public.salonbarra_save(p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'versión vieja de Salón y Barra: recarga la página (Cmd+Shift+R / Ctrl+Shift+R). Tus cambios siguen guardados en este equipo y se fusionan al recargar.';
end;
$$;
