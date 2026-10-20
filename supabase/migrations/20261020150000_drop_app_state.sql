-- NOOK — retiro de la tabla vieja app_state (de antes del login real, 17-sep-2026).
--
-- EJECUTADA MANUALMENTE POR MARIO el 20-oct-2026, desde su terminal. Este archivo solo deja
-- registro en el repo; en la base se marcó como aplicada con
-- `supabase migration repair --status applied 20261020150000` (no se volvió a correr).
--
-- Respaldo previo (fuera del repo):
--   ~/dmz/respaldos/nook-tools/app_state_2026-10-20.json
--     sha256 fae652be2a190e643e46d156c216476407c46565699b6886878f27182c93f35d
--   ~/dmz/respaldos/nook-tools/app_state_funciones_2026-10-20.json (definición de las funciones)
--     sha256 fa3e1beb9730e826b5c98ec665c79be969d568f3481c7542ee747e62a6945c1f
--
-- Ningún archivo del repo usaba app_state_save/app_state_load (dependían de
-- bitacora_check_password, que ya no existe). Verificado después del borrado:
-- to_regclass('public.app_state') = null y 0 funciones app_state_*.

drop function if exists public.app_state_save(text,text,jsonb);
drop function if exists public.app_state_load(text,text);
drop table if exists public.app_state;
