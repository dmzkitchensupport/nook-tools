-- NOOK Bitácora Diaria — respaldo real en la nube.
-- Acceso protegido con una contraseña compartida (no hay sistema de cuentas en nook-tools).
-- La tabla en sí NO tiene ninguna policy para anon: solo se puede leer/escribir a través
-- de las funciones RPC de abajo, que verifican la contraseña con SECURITY DEFINER.
--
-- IMPORTANTE — este archivo NO trae la contraseña real a propósito (este repo es público).
-- Después de aplicar esta migración hay que sembrarla aparte, fuera de git, por ejemplo:
--   insert into public.bitacora_config (id, password_hash)
--   values (1, extensions.crypt('<password real>', extensions.gen_salt('bf')));
-- Pide la contraseña vigente a Mario/Cla — no vive en ningún archivo de este repo.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.bitacora_config (
  id int primary key default 1,
  password_hash text not null,
  constraint single_row check (id = 1)
);

create table if not exists public.bitacora_entries (
  fecha date primary key,
  turno jsonb not null default '{}',
  elaboro text,
  campos jsonb not null default '{}',
  num jsonb not null default '{}',
  efectivo numeric not null default 0,
  ventas_totales numeric not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.bitacora_config enable row level security;
alter table public.bitacora_entries enable row level security;
-- Sin policies para anon/authenticated => acceso directo a la tabla queda cerrado.
-- Todo pasa por las funciones RPC (SECURITY DEFINER) de abajo.

create or replace function public.bitacora_check_password(p_password text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_hash text;
begin
  select password_hash into v_hash from bitacora_config where id = 1;
  if v_hash is null then
    return false;
  end if;
  return extensions.crypt(p_password, v_hash) = v_hash;
end;
$$;

create or replace function public.bitacora_save(
  p_password text,
  p_fecha date,
  p_turno jsonb,
  p_elaboro text,
  p_campos jsonb,
  p_num jsonb,
  p_efectivo numeric,
  p_ventas_totales numeric
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not bitacora_check_password(p_password) then
    raise exception 'contraseña incorrecta';
  end if;
  insert into bitacora_entries(fecha, turno, elaboro, campos, num, efectivo, ventas_totales, updated_at)
  values (p_fecha, p_turno, p_elaboro, p_campos, p_num, p_efectivo, p_ventas_totales, now())
  on conflict (fecha) do update set
    turno = excluded.turno,
    elaboro = excluded.elaboro,
    campos = excluded.campos,
    num = excluded.num,
    efectivo = excluded.efectivo,
    ventas_totales = excluded.ventas_totales,
    updated_at = now();
  return true;
end;
$$;

create or replace function public.bitacora_list(p_password text)
returns setof bitacora_entries
language plpgsql
security definer
set search_path = public
as $$
begin
  if not bitacora_check_password(p_password) then
    raise exception 'contraseña incorrecta';
  end if;
  return query select * from bitacora_entries order by fecha desc;
end;
$$;

create or replace function public.bitacora_delete(p_password text, p_fecha date)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not bitacora_check_password(p_password) then
    raise exception 'contraseña incorrecta';
  end if;
  delete from bitacora_entries where fecha = p_fecha;
  return true;
end;
$$;

-- Revocar ejecución pública de check_password (solo la usan las otras funciones internamente)
revoke all on function public.bitacora_check_password(text) from public, anon, authenticated;
grant execute on function public.bitacora_save(text,date,jsonb,text,jsonb,jsonb,numeric,numeric) to anon;
grant execute on function public.bitacora_list(text) to anon;
grant execute on function public.bitacora_delete(text,date) to anon;

