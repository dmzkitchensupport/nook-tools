-- NOOK — Resultados F&B (estado de resultados, ventas Symphony y consumos por mes).
--
-- Por qué en la base y no en el repo: este repo y su GitHub Pages son públicos.
-- La página resultados/index.html no trae ningún dato; lee todo de aquí con sesión.
--
-- Diseño (mismo patrón que bitacora_*):
--   * public.resultados_fb guarda un solo documento jsonb (fila 'actual') con el cierre.
--   * Sin policies ni grants para anon/authenticated: todo pasa por 2 funciones
--     SECURITY DEFINER.
--   * resultados_get(): exige rol gerencia aprobado (require_gerencia()).
--   * resultados_save(jsonb): solo mario@delamorazumaran.com (misma regla que admin_*).
--   * Cada guardado deja la versión anterior en resultados_fb_historial (no destructivo).

create table if not exists public.resultados_fb (
  id text primary key default 'actual' check (id = 'actual'),
  payload jsonb not null,
  actualizado_por text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.resultados_fb enable row level security;
revoke all on public.resultados_fb from anon, authenticated;

create table if not exists public.resultados_fb_historial (
  id bigint generated always as identity primary key,
  payload jsonb not null,
  actualizado_por text not null default '',
  updated_at timestamptz not null,
  archivado_at timestamptz not null default now()
);
alter table public.resultados_fb_historial enable row level security;
revoke all on public.resultados_fb_historial from anon, authenticated;

create or replace function public.resultados_get()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  r public.resultados_fb;
begin
  perform public.require_gerencia();
  select * into r from public.resultados_fb where id = 'actual';
  if not found then
    return null;
  end if;
  return jsonb_build_object('payload', r.payload, 'updated_at', r.updated_at);
end;
$$;

create or replace function public.resultados_save(p_payload jsonb)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  ts timestamptz := now();
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede actualizar los resultados.';
  end if;
  if p_payload is null
     or jsonb_typeof(p_payload->'meses') is distinct from 'array'
     or jsonb_array_length(p_payload->'meses') = 0
     or jsonb_typeof(p_payload->'balance') is distinct from 'object'
     or jsonb_typeof(p_payload->'symphony') is distinct from 'object'
     or jsonb_typeof(p_payload->'consumos') is distinct from 'object' then
    raise exception 'Archivo inválido: faltan meses, balance, symphony o consumos.';
  end if;

  insert into public.resultados_fb_historial (payload, actualizado_por, updated_at)
    select payload, actualizado_por, updated_at from public.resultados_fb where id = 'actual';

  insert into public.resultados_fb (id, payload, actualizado_por, updated_at)
    values ('actual', p_payload, auth.email(), ts)
  on conflict (id) do update
    set payload = excluded.payload, actualizado_por = excluded.actualizado_por, updated_at = excluded.updated_at;
  return ts;
end;
$$;

revoke all on function public.resultados_get() from public, anon;
revoke all on function public.resultados_save(jsonb) from public, anon;
grant execute on function public.resultados_get() to authenticated;
grant execute on function public.resultados_save(jsonb) to authenticated;

-- Tarjeta en el menú principal: solo gerencia.
insert into public.herramientas (slug, nombre, descripcion, color, estado, roles, orden, origen, ruta_nativa)
values ('resultados', 'Resultados', 'Estado de resultados, ventas y consumos de A&B por mes', 'tan', 'activa', array['gerencia'], 40, 'nativa', 'resultados/')
on conflict (slug) do nothing;
