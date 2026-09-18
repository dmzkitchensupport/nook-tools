-- NOOK — Generador de Ficheros: guardado real en la nube (reemplaza IndexedDB-only)
--
-- Motivo: el Generador solo guardaba en el navegador local (IndexedDB, DB_NAME
-- 'nook_ficheros'). Un chef (José) llenó una ficha en su computadora y Mario no la
-- veía en la suya -- no había forma de que se viera, cada dispositivo tenía su
-- propia copia, nunca sincronizaban. Además, hasta el 18-sep-2026 esta misma base
-- de IndexedDB se compartía por error con salon-barra/ (mismo nombre/store/clave),
-- así que abrir las dos herramientas en el mismo dispositivo podía pisar los datos
-- de una con los de la otra -- ya aislado, pero no recuperaba lo ya perdido.
--
-- Diseño: una sola fila con el proyecto completo (mismo shape que ya se guardaba
-- en IndexedDB: {v, build, cards, ts}) -- no se normaliza a una tabla por ficha
-- para minimizar el riesgo de esta migración; cards ya trae fotos en base64
-- embebidas, jsonb las soporta sin problema para el volumen real de este menú
-- (decenas de fichas, no miles).
--
-- Lectura pública (el contenido de las fichas no es confidencial, ver CLAUDE.md
-- "Contenido público — sin datos sensibles" — es lo mismo que ya está impreso en
-- la carta física). Escritura solo para sesión real con rol chef o gerencia
-- aprobado, mismo criterio que ya usa require_gerencia() para bitacora_*, pero
-- aceptando también 'chef' porque NookAuth.guard() de este archivo ya permite
-- ambos roles (`allow: ['gerencia','chef']`).

create table if not exists public.generador_proyecto (
  id text primary key default 'main',
  data jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

alter table public.generador_proyecto enable row level security;

-- Sin grants directos de tabla ni policies de RLS con USING/WITH CHECK abiertas:
-- todo el acceso pasa por las 2 funciones de abajo (mismo patrón que bitacora_*),
-- así el chequeo de rol vive en un solo lugar, no en cada policy.
revoke all on public.generador_proyecto from anon, authenticated;

create or replace function public.require_chef_o_gerencia()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and rol in ('chef','gerencia') and aprobado = true
  ) then
    raise exception 'acceso denegado: se requiere sesión con rol chef o gerencia aprobado';
  end if;
end;
$$;
revoke all on function public.require_chef_o_gerencia() from public, anon, authenticated;

-- Lectura pública a propósito (sin login) -- ver nota de arriba.
create or replace function public.generador_load()
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select data from public.generador_proyecto where id = 'main';
$$;

create or replace function public.generador_save(p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_chef_o_gerencia();
  insert into public.generador_proyecto (id, data, updated_at, updated_by)
  values ('main', p_data, now(), auth.uid())
  on conflict (id) do update set
    data = excluded.data,
    updated_at = now(),
    updated_by = auth.uid();
  return true;
end;
$$;

revoke all on function public.generador_load() from public;
revoke all on function public.generador_save(jsonb) from public, anon;
grant execute on function public.generador_load() to anon, authenticated;
grant execute on function public.generador_save(jsonb) to authenticated;
