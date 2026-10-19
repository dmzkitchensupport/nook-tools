-- NOOK — Salón y Barra (Generador de Ficheros de bebidas): guardado real en la nube.
--
-- Motivo (autorizado por Mario el 19-oct-2026): salon-barra/ solo guardaba en el
-- navegador local (IndexedDB 'nook_ficheros_salonbarra'), mismo problema que tuvo
-- generador/ antes del 18-sep: lo que captura barra en un equipo no se veía en otro.
--
-- Diseño: mismo patrón que generador_proyecto (20260918120000 + blindaje
-- 20260918123000), pero en una tabla PROPIA. No se toca ni se mezcla con
-- generador_proyecto (cocina). Una sola fila id='main' con el proyecto completo:
-- {v, build, cards, customMenu, ts}. customMenu = grupos y bebidas dados de alta
-- desde el Índice, con forma {categoria: {grupo: [[nombre, descripcion], ...]}}.
--
-- Lectura pública (contenido de carta, no confidencial — ver CLAUDE.md "Contenido
-- público — sin datos sensibles"). Escritura solo con sesión real de rol
-- 'gerencia' aprobado: salon-barra/ usa NookAuth.guard({allow:['gerencia']}),
-- así que se reutiliza require_gerencia() (ya existe, 20260918000000), no
-- require_chef_o_gerencia().
--
-- Migración ADITIVA: solo crea objetos nuevos (tabla + 2 funciones). No modifica
-- ni borra nada existente.

create table if not exists public.salonbarra_proyecto (
  id text primary key default 'main',
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

alter table public.salonbarra_proyecto enable row level security;

-- Sin grants de tabla ni policies abiertas: todo pasa por las 2 funciones de abajo.
revoke all on public.salonbarra_proyecto from anon, authenticated;

-- Cuenta el "contenido real" de un proyecto: fichas + grupos dados de alta en el
-- Índice. A diferencia de cocina, barra arranca sin menú precargado, así que un
-- proyecto puede tener grupos/bebidas en el Índice y todavía 0 fichas — eso
-- también es trabajo real que no se debe poder pisar con un proyecto vacío.
create or replace function public.salonbarra_contenido(p jsonb)
returns int
language sql
immutable
set search_path = public
as $$
  select
    (case when jsonb_typeof(p->'cards') = 'array' then jsonb_array_length(p->'cards') else 0 end)
    +
    coalesce((
      select sum(case when jsonb_typeof(cat.value) = 'object'
                      then (select count(*) from jsonb_object_keys(cat.value))
                      else 0 end)::int
      from jsonb_each(case when jsonb_typeof(p->'customMenu') = 'object'
                           then p->'customMenu' else '{}'::jsonb end) as cat
    ), 0);
$$;
revoke all on function public.salonbarra_contenido(jsonb) from public, anon, authenticated;

-- Lectura pública a propósito (sin login).
create or replace function public.salonbarra_load()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select data from public.salonbarra_proyecto where id = 'main';
$$;

-- Escritura: gerencia aprobada + blindaje contra sobrescritura con proyecto vacío
-- (lección del incidente real de generador/ del 18-sep-2026, bloqueadores #9/#13).
create or replace function public.salonbarra_save(p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  n_nuevo int;
  n_actual int;
begin
  perform public.require_gerencia();

  n_nuevo := public.salonbarra_contenido(p_data);

  select public.salonbarra_contenido(data)
    into n_actual
    from public.salonbarra_proyecto
    where id = 'main';

  if n_nuevo = 0 and coalesce(n_actual, 0) > 0 then
    raise exception 'rechazado: se intentó guardar un proyecto vacío (0 fichas y 0 grupos) sobre uno real con % elementos -- probable pestaña/dispositivo desactualizado', n_actual;
  end if;

  insert into public.salonbarra_proyecto (id, data, updated_at, updated_by)
  values ('main', p_data, now(), auth.uid())
  on conflict (id) do update set
    data = excluded.data,
    updated_at = now(),
    updated_by = auth.uid();
  return true;
end;
$$;

revoke all on function public.salonbarra_load() from public;
revoke all on function public.salonbarra_save(jsonb) from public, anon;
grant execute on function public.salonbarra_load() to anon, authenticated;
grant execute on function public.salonbarra_save(jsonb) to authenticated;
