-- NOOK — Generador: revertir la prueba de Mario en la ficha 185 "Avocado Toast".
--
-- Motivo (22-oct-2026, decisión de Mario): el cambio del 20-oct 22:40 UTC (ficha 185 de
-- breakfast/Breakfast a dinner/Pasta) fue una PRUEBA suya. Se regresa a breakfast/Breakfast.
-- Va en archivo aparte de 20261020170100 porque esa migración ya estaba aplicada y registrada
-- cuando llegó la decisión; corre inmediatamente después, en la misma sesión.
--
-- Qué hace (solo la fila 'main' de generador_proyecto, solo la ficha 185):
--   1. cat y group = los valores exactos de su versión archivada (origen 'nube', motivo
--      'empate_contenido'). Ningún otro campo de la ficha cambia.
--   2. card.ts = momento de esta migración: queda como la versión más nueva y ninguna caché vieja
--      la vuelve a mover (regla "gana la información más nueva", #22.2).
--   3. La versión de prueba (dinner/Pasta) se AGREGA a archivo_conflictos con motivo
--      'revertido_prueba_mario'. La entrada archivada original no se toca.
--   4. updated_at = ahora (es un cambio de contenido real: una pestaña abierta con la versión
--      anterior recibe "conflicto", recarga y fusiona en vez de pisar). updated_by y data.ts igual.
-- Idempotente: solo actúa si la 185 sigue en dinner/Pasta y existe la versión archivada original.

with base as (
  select g.data,
         (extract(epoch from clock_timestamp()) * 1000)::bigint as ahora,
         (select c from jsonb_array_elements(g.data->'cards') c where c->>'id' = '185') as actual,
         (select e->'version' from jsonb_array_elements(g.data->'archivo_conflictos') e
           where e->>'id' = '185' and e->>'origen' = 'nube' and e->>'motivo' = 'empate_contenido'
           limit 1) as original
    from public.generador_proyecto g
   where g.id = 'main'
)
update public.generador_proyecto g
   set data = jsonb_set(
                jsonb_set(b.data, '{cards}',
                  (select jsonb_agg(case when c->>'id' = '185'
                                         then c || jsonb_build_object('cat', b.original->'cat',
                                                                      'group', b.original->'group',
                                                                      'ts', b.ahora)
                                         else c end order by o)
                     from jsonb_array_elements(b.data->'cards') with ordinality t(c, o))),
                '{archivo_conflictos}',
                b.data->'archivo_conflictos' || jsonb_build_array(jsonb_build_object(
                  'id', 185, 'version', b.actual, 'origen', 'nube',
                  'motivo', 'revertido_prueba_mario', 'ts_archivado', b.ahora))),
       updated_at = clock_timestamp()
  from base b
 where g.id = 'main'
   and b.actual is not null and b.original is not null
   and b.actual->>'cat' = 'dinner' and b.actual->>'group' = 'Pasta';
