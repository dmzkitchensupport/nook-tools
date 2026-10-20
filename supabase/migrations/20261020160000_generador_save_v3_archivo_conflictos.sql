-- NOOK — Generador de Ficheros: guardado v3 con archivo de conflictos (sin copias visibles).
--
-- Motivo (20-oct-2026, autorizado por Mario en esa sesión, bloqueador #21: "quítalas"):
-- la fusión de la página ya no crea fichas "(copia de este equipo)" / "(copia importada)".
-- Cuando dos versiones de una misma ficha chocan, queda visible una sola y la otra se guarda
-- en data.archivo_conflictos ([{id, version, origen, motivo, ts_archivado}]), sin mostrarse.
--
-- Cambios (aditivos; no tocan datos):
--   1. generador_save_v3(p_data, p_base): igual que v2 (control de versión, rechaza base64,
--      rechaza proyecto vacío sobre uno real) y además RECHAZA un guardado que tenga menos
--      versiones archivadas que la fila actual: el archivo de conflictos nunca se encoge.
--   2. generador_save_v2 queda deshabilitada (misma firma, error claro de "recarga la página"):
--      una pestaña abierta con la página del 20-oct temprano (6055042) no conoce el archivo y
--      lo borraría al guardar, además de crear copias. Sus cambios se quedan en la caché local
--      de ese equipo y se fusionan al recargar con la página nueva.
--   generador_load_v2() se sigue usando sin cambios (devuelve data completa, archivo incluido).

create or replace function public.generador_save_v3(p_data jsonb, p_base timestamptz)
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
  perform public.require_chef_o_gerencia();

  if position('data:image' in p_data::text) > 0 then
    raise exception 'rechazado: el proyecto trae fotos en base64; deben subirse primero al bucket generador-fotos';
  end if;

  select jsonb_array_length(coalesce(data->'cards', '[]'::jsonb)),
         case when jsonb_typeof(data->'archivo_conflictos') = 'array'
              then jsonb_array_length(data->'archivo_conflictos') else 0 end,
         updated_at
    into n_actual, a_actual, v_actual
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

  a_nuevo := case when jsonb_typeof(p_data->'archivo_conflictos') = 'array'
                  then jsonb_array_length(p_data->'archivo_conflictos') else 0 end;
  if a_nuevo < coalesce(a_actual, 0) then
    raise exception 'rechazado: el guardado perdería versiones archivadas (% en la nube, % en el guardado); recarga la página', a_actual, a_nuevo;
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
revoke all on function public.generador_save_v3(jsonb, timestamptz) from public, anon;
grant execute on function public.generador_save_v3(jsonb, timestamptz) to authenticated;

create or replace function public.generador_save_v2(p_data jsonb, p_base timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'versión vieja del Generador: recarga la página (Cmd+Shift+R / Ctrl+Shift+R). Tus cambios siguen guardados en este equipo y se fusionan al recargar.';
end;
$$;
