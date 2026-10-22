-- NOOK — Generador de Ficheros y Salón y Barra: fichas bilingües (EN | ES).
--
-- Motivo (22-oct-2026, pedido y autorización de Mario en esa sesión: "DEBE SER BILINGÜE, para que se
-- pueda poner en inglés o español", alcance "Todo: página y contenido"):
--   Cada ficha guarda sus textos traducibles en card.tr = {en:{title,carta,ing,proc,ts}, es:{...}}.
--   Los nombres/descripciones del Índice agregados desde la página van en data.menu_i18n
--   ({"g:<grupo>": {...}, "d:<platillo>": {...}}, cada entrada con su ts).
--
-- Problema que resuelve: una pestaña abierta con la página ANTERIOR (sin bilingüe) no conoce
-- card.tr ni data.menu_i18n. Esa página arma el guardado con sus propios objetos:
--   - data.menu_i18n nunca va en su guardado (lo borraría en cada guardado);
--   - una ficha que esa pestaña tenía en caché sin tr puede ganar una fusión por fecha y subir sin tr.
-- Decisión: CONSERVAR (no rechazar). Rechazar dejaría al chef que está editando ahora con la página
-- vieja sin poder guardar en la nube hasta recargar; conservar no le cambia nada y no pierde nada:
--   1. Si el guardado no trae menu_i18n, se conserva el de la nube. Si lo trae, se une por llave con
--      el de la nube (la página ya fusionó por fecha; el servidor solo evita perder llaves).
--   2. Una ficha del guardado SIN la llave "tr", cuyo id en la nube sí tiene tr, conserva el tr de la
--      nube. (La página nueva nunca quita tr; solo la vieja manda fichas sin esa llave.)
--   Si la pestaña vieja editó el texto viejo (title/carta/ing/proc), la página nueva lo detecta al
--   abrir (el texto viejo ya no coincide con tr) y lo pasa al idioma que ese texto representa.
--
-- Cambios (aditivos; NO tocan datos ni la fila guardada):
--   - nueva función interna nook_conservar_i18n(actual, nuevo) -> nuevo con tr/menu_i18n conservados;
--   - generador_save_v4 y salonbarra_save_v3: mismo cuerpo que 20261020170000 + la llamada a
--     nook_conservar_i18n justo antes de escribir. Misma firma: la página vieja y la nueva usan la
--     misma función, ninguna se deshabilita.
--   generador_load_v2() y salonbarra_load_v2() sin cambios.

create or replace function public.nook_conservar_i18n(p_actual jsonb, p_nuevo jsonb)
returns jsonb
language plpgsql
immutable
set search_path = public
as $$
declare
  v_tr jsonb;
  v_cards jsonb;
  v_out jsonb := p_nuevo;
begin
  if p_actual is null or p_nuevo is null then
    return p_nuevo;
  end if;

  -- 1. menu_i18n: nunca se pierde una llave.
  if jsonb_typeof(p_actual->'menu_i18n') = 'object' then
    if jsonb_typeof(p_nuevo->'menu_i18n') = 'object' then
      v_out := jsonb_set(v_out, '{menu_i18n}', (p_actual->'menu_i18n') || (p_nuevo->'menu_i18n'));
    else
      v_out := jsonb_set(v_out, '{menu_i18n}', p_actual->'menu_i18n');
    end if;
  end if;

  -- 2. card.tr: una ficha que llega sin la llave tr conserva la de la nube (mismo id).
  select jsonb_object_agg(c->>'id', c->'tr')
    into v_tr
    from jsonb_array_elements(case when jsonb_typeof(p_actual->'cards') = 'array'
                                   then p_actual->'cards' else '[]'::jsonb end) c
   where jsonb_typeof(c->'tr') = 'object';

  if v_tr is not null and jsonb_typeof(v_out->'cards') = 'array' then
    select coalesce(jsonb_agg(
             case when not (c ? 'tr') and v_tr ? (c->>'id')
                  then c || jsonb_build_object('tr', v_tr->(c->>'id'))
                  else c end
             order by ord), '[]'::jsonb)
      into v_cards
      from jsonb_array_elements(v_out->'cards') with ordinality as t(c, ord);
    v_out := jsonb_set(v_out, '{cards}', v_cards);
  end if;

  return v_out;
end;
$$;
revoke all on function public.nook_conservar_i18n(jsonb, jsonb) from public, anon;

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

  -- 22-oct-2026 (bilingüe): una pestaña con la página anterior no borra traducciones.
  p_data := public.nook_conservar_i18n(d_actual, p_data);

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

  -- 22-oct-2026 (bilingüe): una pestaña con la página anterior no borra traducciones.
  p_data := public.nook_conservar_i18n(d_actual, p_data);

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
