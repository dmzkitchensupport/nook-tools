-- NOOK — respaldo en la nube genérico para las 5 herramientas restantes
-- (fichas, organizador, generador, salon-barra, recetario). Cada una sincroniza
-- un solo blob JSON con su estado completo, bajo la MISMA contraseña compartida
-- ya usada por bitacora/ (bitacora_check_password / bitacora_config).
--
-- Igual que bitacora_entries: la tabla NO tiene ninguna policy para anon —
-- todo pasa por las 2 funciones RPC de abajo (SECURITY DEFINER).

create table if not exists public.app_state (
  tool text primary key,
  data jsonb not null default '{}',
  updated_at timestamptz not null default now()
)
;
alter table public.app_state enable row level security
;
create or replace function public.app_state_save(p_password text, p_tool text, p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not bitacora_check_password(p_password) then
    raise exception 'contraseña incorrecta';
  end if;
  insert into app_state(tool, data, updated_at)
  values (p_tool, p_data, now())
  on conflict (tool) do update set data = excluded.data, updated_at = now();
  return true;
end;
$$
;
create or replace function public.app_state_load(p_password text, p_tool text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_data jsonb;
begin
  if not bitacora_check_password(p_password) then
    raise exception 'contraseña incorrecta';
  end if;
  select data into v_data from app_state where tool = p_tool;
  return v_data;
end;
$$
;
grant execute on function public.app_state_save(text,text,jsonb) to anon
;
grant execute on function public.app_state_load(text,text) to anon
;