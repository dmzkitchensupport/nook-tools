-- NOOK — metadatos de una sola vez: fecha original (card.ts) en las fichas de la nube que no la traían.
--
-- Motivo (20/22-oct-2026, bloqueador #22.2, decisión de Mario "siempre gana la información más nueva"):
-- la regla usa card.ts y, si falta, el ts del contenedor. En la nube ese ts del contenedor NO
-- representa la fecha de cada ficha: en generador_proyecto vale 2026-10-20 solo porque ese día se
-- editó la ficha 185, y le ganaría por error a trabajo local guardado antes (p. ej. el de José del
-- 10-oct). Por eso se escribe en cada ficha sin ts su última escritura real conocida:
--   generador_proyecto  → 1790211454937 (2026-09-24 00:57 UTC, última escritura del proyecto completo,
--                         antes del 20-oct; la 185 ya trae su propio ts y no se toca).
--   salonbarra_proyecto → 1792444360406 (2026-10-19 21:12:40 UTC = data.ts = updated_at: la fila se
--                         escribió una sola vez, por Mario).
-- SOLO agrega la llave ts a esas fichas. No toca ningún otro campo de la ficha, ni data.ts, ni el
-- archivo de conflictos, ni updated_at / updated_by (es un dato de fecha, no una edición de nadie).
-- Idempotente: una ficha que ya trae ts se deja igual.

update public.generador_proyecto g
   set data = jsonb_set(g.data, '{cards}',
         (select coalesce(jsonb_agg(case when c ? 'ts' then c else c || '{"ts":1790211454937}'::jsonb end order by o), '[]'::jsonb)
            from jsonb_array_elements(g.data->'cards') with ordinality t(c, o)))
 where g.id = 'main'
   and jsonb_typeof(g.data->'cards') = 'array'
   and exists (select 1 from jsonb_array_elements(g.data->'cards') c where not (c ? 'ts'));

update public.salonbarra_proyecto s
   set data = jsonb_set(s.data, '{cards}',
         (select coalesce(jsonb_agg(case when c ? 'ts' then c else c || '{"ts":1792444360406}'::jsonb end order by o), '[]'::jsonb)
            from jsonb_array_elements(s.data->'cards') with ordinality t(c, o)))
 where s.id = 'main'
   and jsonb_typeof(s.data->'cards') = 'array'
   and exists (select 1 from jsonb_array_elements(s.data->'cards') c where not (c ? 'ts'));
