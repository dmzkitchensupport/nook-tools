-- NOOK — sistema real de cuentas de usuario con rol, para reemplazar la contraseña
-- compartida (esquema anterior en bitacora_config / bitacora_check_password).
--
-- Diseño:
--   * auth.users (Supabase Auth) es la fuente de identidad real (email + password).
--   * public.profiles guarda rol/aprobado/puesto — se crea automáticamente vía trigger
--     al registrarse alguien, siempre con rol='pendiente', aprobado=false.
--   * Solo mario@delamorazumaran.com puede aprobar/asignar rol, vía la función
--     admin_set_profile (SECURITY DEFINER) — la valida internamente, no depende de
--     ningún rol dentro de la propia tabla profiles (evita el problema de huevo y
--     gallina: Mario puede aprobarse a sí mismo aunque su propio perfil siga
--     'pendiente', porque la función solo compara el email del JWT).
--   * bitacora_save/list/delete dejan de pedir contraseña — ahora exigen que quien
--     llama esté autenticado y tenga profiles.rol='gerencia' AND aprobado=true.
--     La tabla bitacora_entries y sus datos NO se tocan.

-- =========================================================================
-- 1. profiles
-- =========================================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  nombre text not null default '',
  telefono text not null default '',
  puesto text not null default '',
  rol text not null default 'pendiente' check (rol in ('pendiente','chef','gerencia')),
  aprobado boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Sin grants amplios: cada usuario solo puede leer/actualizar su propia fila,
-- y el update de columnas sensibles (rol, aprobado) queda bloqueado a nivel de
-- privilegio de columna (no solo a nivel de policy) — defensa en profundidad.
revoke all on public.profiles from anon, authenticated;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant select (id, email, nombre, telefono, puesto, rol, aprobado, created_at) on public.profiles to authenticated;
grant update (nombre, telefono, puesto) on public.profiles to authenticated;
-- Nota: sin grant de update sobre rol/aprobado a authenticated -> aunque la policy
-- de arriba permitiera la fila, PostgREST rechaza el intento por falta de privilegio
-- de columna. Nadie puede auto-asignarse rol ni aprobarse desde el propio usuario.
-- Sin grant de insert/delete a authenticated -> el alta pasa solo por el trigger
-- (corre como el rol que inserta en auth.users, no sujeto a estos grants).

-- =========================================================================
-- 2. Trigger: alta automática de perfil al registrarse en auth.users
-- =========================================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, nombre, telefono, puesto, rol, aprobado)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'nombre', ''),
    coalesce(new.raw_user_meta_data->>'telefono', ''),
    coalesce(new.raw_user_meta_data->>'puesto', ''),
    'pendiente',
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================================
-- 3. RPCs de administración — SOLO mario@delamorazumaran.com
-- =========================================================================
create or replace function public.admin_list_profiles()
returns setof public.profiles
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede ver el panel de administración.';
  end if;
  return query select * from public.profiles order by created_at desc;
end;
$$;

create or replace function public.admin_set_profile(
  target_id uuid,
  nuevo_rol text,
  nuevo_puesto text,
  nuevo_aprobado boolean
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.profiles;
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede aprobar/asignar rol.';
  end if;
  if nuevo_rol not in ('pendiente','chef','gerencia') then
    raise exception 'Rol inválido: %', nuevo_rol;
  end if;
  update public.profiles
    set rol = nuevo_rol,
        puesto = coalesce(nuevo_puesto, puesto),
        aprobado = nuevo_aprobado
    where id = target_id
    returning * into result;
  if result.id is null then
    raise exception 'Perfil no encontrado: %', target_id;
  end if;
  return result;
end;
$$;

revoke all on function public.admin_list_profiles() from public, anon;
revoke all on function public.admin_set_profile(uuid, text, text, boolean) from public, anon;
grant execute on function public.admin_list_profiles() to authenticated;
grant execute on function public.admin_set_profile(uuid, text, text, boolean) to authenticated;
-- (el grant a "authenticated" solo permite intentar llamarla; la función misma
-- rechaza con excepción real a cualquiera que no sea mario@delamorazumaran.com)

-- =========================================================================
-- 4. bitacora_save/list/delete: retirar la contraseña compartida, exigir
--    sesión real con rol='gerencia' aprobado. La tabla bitacora_entries y
--    sus datos NO se tocan.
-- =========================================================================
create or replace function public.require_gerencia()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and rol = 'gerencia' and aprobado = true
  ) then
    raise exception 'acceso denegado: se requiere sesión con rol gerencia aprobado';
  end if;
end;
$$;
revoke all on function public.require_gerencia() from public, anon, authenticated;

drop function if exists public.bitacora_save(text,date,jsonb,text,jsonb,jsonb,numeric,numeric);
create or replace function public.bitacora_save(
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
  perform public.require_gerencia();
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

drop function if exists public.bitacora_list(text);
create or replace function public.bitacora_list()
returns setof bitacora_entries
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_gerencia();
  return query select * from bitacora_entries order by fecha desc;
end;
$$;

drop function if exists public.bitacora_delete(text,date);
create or replace function public.bitacora_delete(p_fecha date)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_gerencia();
  delete from bitacora_entries where fecha = p_fecha;
  return true;
end;
$$;

revoke all on function public.bitacora_save(date,jsonb,text,jsonb,jsonb,numeric,numeric) from public, anon;
revoke all on function public.bitacora_list() from public, anon;
revoke all on function public.bitacora_delete(date) from public, anon;
grant execute on function public.bitacora_save(date,jsonb,text,jsonb,jsonb,numeric,numeric) to authenticated;
grant execute on function public.bitacora_list() to authenticated;
grant execute on function public.bitacora_delete(date) to authenticated;

-- El mecanismo de contraseña compartida queda retirado: ya no se usa en ningún
-- flujo (bitacora_save/list/delete ahora validan por rol real, no por contraseña).
-- Solo contenía un hash bcrypt, ningún dato de negocio.
drop function if exists public.bitacora_check_password(text);
drop table if exists public.bitacora_config;
