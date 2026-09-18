-- NOOK — Generador de Ficheros: blindaje contra sobrescritura accidental con proyecto vacío.
--
-- Incidente real, 18-sep-2026: minutos después de sembrar la nube con el guardado en tiempo
-- real, la fila quedó en 0 fichas -- muy probablemente otra pestaña/dispositivo con datos
-- locales vacíos (abierta desde antes de que José subiera lo suyo) disparó un guardado y
-- "ganó" la carrera contra el guardado real de José. El cliente ya no debería mandar 0 fichas
-- por el camino automático, pero esto es defensa en profundidad a nivel de base de datos:
-- ningún cliente (viejo, con caché del navegador, o con un bug futuro) puede borrar un
-- proyecto real con una sola llamada automática -- si de verdad se quiere vaciar el menú,
-- que sea explícito (borrar la fila a mano, no vía este RPC).

create or replace function public.generador_save(p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n_nuevo int;
  n_actual int;
begin
  perform public.require_chef_o_gerencia();

  n_nuevo := jsonb_array_length(coalesce(p_data->'cards', '[]'::jsonb));

  select jsonb_array_length(coalesce(data->'cards', '[]'::jsonb))
    into n_actual
    from public.generador_proyecto
    where id = 'main';

  if n_nuevo = 0 and coalesce(n_actual, 0) > 0 then
    raise exception 'rechazado: se intentó guardar un proyecto vacío (0 fichas) sobre uno real con % fichas -- probable pestaña/dispositivo desactualizado', n_actual;
  end if;

  insert into public.generador_proyecto (id, data, updated_at, updated_by)
  values ('main', p_data, now(), auth.uid())
  on conflict (id) do update set
    data = excluded.data,
    updated_at = now(),
    updated_by = auth.uid();
  return true;
end;
$$;
