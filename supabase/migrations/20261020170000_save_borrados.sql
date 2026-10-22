-- NOOK — Generador de Ficheros y Salón y Barra: guardado con registro de borrados.
--
-- Motivo (20-oct-2026, decisión y autorización de Mario en esa sesión, bloqueador #22):
--   #22.1 Registro de borrados: al borrar una ficha con ✕ la página anota {id, ts_borrado, por}
--         en data.borrados y guarda la última versión en data.archivo_conflictos (motivo 'borrado').
--         Una caché vieja de otro equipo ya no revive esa ficha.
--   #22.2 En toda fusión gana la información más nueva (fecha de última actualización). Eso vive
--         en la página; el servidor solo protege que nada se pierda.
--
-- Cambios (aditivos; NO tocan datos ni la fila guardada):
--   1. generador_save_v4(p_data, p_base) = generador_save_v3 + rechaza un guardado que encoja el
--      registro de borrados (todo id presente en la fila debe seguir en el guardado; una marca
--      "retirada" se conserva como entrada, nunca se quita).
--   2. salonbarra_save_v3(p_data, p_base) = salonbarra_save_v2 + la misma regla de borrados.
--   1 y 2 además rechazan una ficha sin card.ts numérico (> 0): desde el 20-oct-2026 toda ficha que
--      sube lleva su fecha de última actualización; el ts del contenedor ya no cuenta para la nube.
--   3. generador_save_v3 y salonbarra_save_v2 quedan deshabilitadas (misma firma, mensaje de
--      "recarga la página"): una pestaña con la página anterior no conoce el registro de borrados
--      ni la regla de fechas; sus cambios se quedan en la caché de ese equipo y se fusionan al recargar.
--   generador_load_v2() y salonbarra_load_v2() siguen sin cambios.

create or replace function public.nook_borrados_perdidos(p_actual jsonb, p_nuevo jsonb)
returns int
language sql
immutable
set search_path = public
as $$
  select count(*)::int
    from jsonb_array_elements(case when jsonb_typeof(p_actual->'borrados') = 'array'
                                   then p_actual->'borrados' else '[]'::jsonb end) e
   where not exists (
     select 1
       from jsonb_array_elements(case when jsonb_typeof(p_nuevo->'borrados') = 'array'
                                      then p_nuevo->'borrados' else '[]'::jsonb end) n
      where n->>'id' = e->>'id');
$$;
revoke all on function public.nook_borrados_perdidos(jsonb, jsonb) from public, anon;

create or replace function public.generador_save_v4(p_data jsonb, p_base timestamptz)
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
  b_perdidos int;
  d_actual jsonb;
  v_actual timestamptz;
  v_nuevo timestamptz;
begin
  perform public.require_chef_o_gerencia();

  if position('data:image' in p_data::text) > 0 then
    raise exception 'rechazado: el proyecto trae fotos en base64; deben subirse primero al bucket generador-fotos';
  end if;

  select data, updated_at
    into d_actual, v_actual
    from public.generador_proyecto
    where id = 'main'
    for update;

  if v_actual is not null and (p_base is null or v_actual <> p_base) then
    return jsonb_build_object('ok', false, 'conflict', true, 'updated_at', v_actual);
  end if;

  n_actual := jsonb_array_length(coalesce(d_actual->'cards', '[]'::jsonb));
  n_nuevo := jsonb_array_length(coalesce(p_data->'cards', '[]'::jsonb));
  if n_nuevo = 0 and coalesce(n_actual, 0) > 0 then
    raise exception 'rechazado: se intentó guardar un proyecto vacío (0 fichas) sobre uno real con % fichas', n_actual;
  end if;

  a_actual := case when jsonb_typeof(d_actual->'archivo_conflictos') = 'array'
                   then jsonb_array_length(d_actual->'archivo_conflictos') else 0 end;
  a_nuevo := case when jsonb_typeof(p_data->'archivo_conflictos') = 'array'
                  then jsonb_array_length(p_data->'archivo_conflictos') else 0 end;
  if a_nuevo < coalesce(a_actual, 0) then
    raise exception 'rechazado: el guardado perdería versiones archivadas (% en la nube, % en el guardado); recarga la página', a_actual, a_nuevo;
  end if;

  b_perdidos := public.nook_borrados_perdidos(coalesce(d_actual, '{}'::jsonb), p_data);
  if b_perdidos > 0 then
    raise exception 'rechazado: el guardado perdería % marca(s) del registro de borrados; recarga la página', b_perdidos;
  end if;

  if exists (select 1 from jsonb_array_elements(coalesce(p_data->'cards', '[]'::jsonb)) c
              where jsonb_typeof(c->'ts') is distinct from 'number' or (c->>'ts')::numeric <= 0) then
    raise exception 'rechazado: toda ficha debe llevar su fecha de última actualización (ts); recarga la página';
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
revoke all on function public.generador_save_v4(jsonb, timestamptz) from public, anon;
grant execute on function public.generador_save_v4(jsonb, timestamptz) to authenticated;

create or replace function public.salonbarra_save_v3(p_data jsonb, p_base timestamptz)
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
  b_perdidos int;
  d_actual jsonb;
  v_actual timestamptz;
  v_nuevo timestamptz;
begin
  perform public.require_gerencia();

  if position('data:image' in p_data::text) > 0 then
    raise exception 'rechazado: el proyecto trae fotos en base64; deben subirse primero al bucket salonbarra-fotos';
  end if;

  select data, updated_at
    into d_actual, v_actual
    from public.salonbarra_proyecto
    where id = 'main'
    for update;

  if v_actual is not null and (p_base is null or v_actual <> p_base) then
    return jsonb_build_object('ok', false, 'conflict', true, 'updated_at', v_actual);
  end if;

  n_actual := public.salonbarra_contenido(d_actual);
  n_nuevo := public.salonbarra_contenido(p_data);
  if n_nuevo = 0 and coalesce(n_actual, 0) > 0 then
    raise exception 'rechazado: se intentó guardar un proyecto vacío (0 fichas y 0 grupos) sobre uno real con % elementos', n_actual;
  end if;

  a_actual := case when jsonb_typeof(d_actual->'archivo_conflictos') = 'array'
                   then jsonb_array_length(d_actual->'archivo_conflictos') else 0 end;
  a_nuevo := case when jsonb_typeof(p_data->'archivo_conflictos') = 'array'
                  then jsonb_array_length(p_data->'archivo_conflictos') else 0 end;
  if a_nuevo < coalesce(a_actual, 0) then
    raise exception 'rechazado: el guardado perdería versiones archivadas (% en la nube, % en el guardado); recarga la página', a_actual, a_nuevo;
  end if;

  b_perdidos := public.nook_borrados_perdidos(coalesce(d_actual, '{}'::jsonb), p_data);
  if b_perdidos > 0 then
    raise exception 'rechazado: el guardado perdería % marca(s) del registro de borrados; recarga la página', b_perdidos;
  end if;

  if exists (select 1 from jsonb_array_elements(coalesce(p_data->'cards', '[]'::jsonb)) c
              where jsonb_typeof(c->'ts') is distinct from 'number' or (c->>'ts')::numeric <= 0) then
    raise exception 'rechazado: toda ficha debe llevar su fecha de última actualización (ts); recarga la página';
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
revoke all on function public.salonbarra_save_v3(jsonb, timestamptz) from public, anon;
grant execute on function public.salonbarra_save_v3(jsonb, timestamptz) to authenticated;

create or replace function public.generador_save_v3(p_data jsonb, p_base timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'versión vieja del Generador: recarga la página (Cmd+Shift+R / Ctrl+Shift+R). Tus cambios siguen guardados en este equipo y se fusionan al recargar.';
end;
$$;

create or replace function public.salonbarra_save_v2(p_data jsonb, p_base timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'versión vieja de Salón y Barra: recarga la página (Cmd+Shift+R / Ctrl+Shift+R). Tus cambios siguen guardados en este equipo y se fusionan al recargar.';
end;
$$;
