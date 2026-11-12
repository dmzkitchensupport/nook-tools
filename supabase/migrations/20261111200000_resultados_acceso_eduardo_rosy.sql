-- NOOK — Resultados: acceso para Eduardo y Rosy (decisión de Mario, 11-nov-2026:
-- "SOLO PUEDE VERLO EDUARDO, MARIO Y ROSY"; "dales el acceso").
-- Correos tomados de los hilos de Gmail de Mario: Eduardo Yanes escribe desde
-- eyanes@arubavc.com y eyanes@tottaruba.com (se agregan los dos); Rosy Torbett
-- desde rosymtorbett@gmail.com. Solo da acceso si además tienen cuenta aprobada.
insert into public.resultados_acceso (email, nombre) values
  ('eyanes@arubavc.com', 'Eduardo Yanes'),
  ('eyanes@tottaruba.com', 'Eduardo Yanes'),
  ('rosymtorbett@gmail.com', 'Rosy Torbett')
on conflict (email) do update set nombre = excluded.nombre;
