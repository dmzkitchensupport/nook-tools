-- NOOK — historial de trabajo centralizado del panel de Configuración, pedido por
-- Mario el 24-sep-2026 ("botón de historial de trabajo para cada área" → aclarado
-- con él: un registro central en Configuración, no un botón por herramienta).
--
-- Alcance decidido explícitamente con Mario: cubre las acciones que pasan POR el
-- panel de administración (Usuarios y Herramientas) — no instrumenta fichas/,
-- recetario/, bitácora/, etc. (esas ya tienen su propio historial local donde
-- aplica, ej. "Registro de cambios" de recetario/). Si más adelante se quiere
-- historial cross-herramienta, es una ampliación aparte, no se infiere aquí.
--
-- El registro se escribe DENTRO de las mismas funciones admin_* (misma
-- transacción, no depende de una llamada extra del navegador) — se redefinen
-- admin_set_profile / admin_upsert_herramienta / admin_delete_herramienta con la
-- misma firma y el mismo cuerpo de siempre, solo agregando el insert de bitácora.

-- =========================================================================
-- 1. historial_acciones
-- =========================================================================
create table if not exists public.historial_acciones (
  id uuid primary key default gen_random_uuid(),
  actor_email text not null,
  area text not null check (area in ('usuarios','herramientas')),
  accion text not null,
  detalle jsonb not null default '{}',
  creado_en timestamptz not null default now()
);

alter table public.historial_acciones enable row level security;
revoke all on public.historial_acciones from anon, authenticated;

create or replace function public.admin_list_historial(p_limit int default 200)
returns setof public.historial_acciones
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede ver el historial.';
  end if;
  return query select * from public.historial_acciones order by creado_en desc limit greatest(coalesce(p_limit,200), 1);
end;
$$;
revoke all on function public.admin_list_historial(int) from public, anon;
grant execute on function public.admin_list_historial(int) to authenticated;

-- =========================================================================
-- 2. admin_set_profile — mismo cuerpo de 20260918000000, + registro de historial
-- =========================================================================
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
  anterior public.profiles;
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede aprobar/asignar rol.';
  end if;
  if nuevo_rol not in ('pendiente','chef','gerencia') then
    raise exception 'Rol inválido: %', nuevo_rol;
  end if;

  select * into anterior from public.profiles where id = target_id;

  update public.profiles
    set rol = nuevo_rol,
        puesto = coalesce(nuevo_puesto, puesto),
        aprobado = nuevo_aprobado
    where id = target_id
    returning * into result;
  if result.id is null then
    raise exception 'Perfil no encontrado: %', target_id;
  end if;

  insert into public.historial_acciones (actor_email, area, accion, detalle)
  values (
    lower(auth.email()), 'usuarios', 'usuario.actualizado',
    jsonb_build_object(
      'email', result.email,
      'rol_anterior', anterior.rol, 'rol_nuevo', result.rol,
      'aprobado_anterior', anterior.aprobado, 'aprobado_nuevo', result.aprobado,
      'puesto_anterior', anterior.puesto, 'puesto_nuevo', result.puesto
    )
  );

  return result;
end;
$$;

-- =========================================================================
-- 3. admin_upsert_herramienta — mismo cuerpo de 20260920000000, + historial
-- =========================================================================
create or replace function public.admin_upsert_herramienta(
  p_id uuid,
  p_slug text,
  p_nombre text,
  p_descripcion text,
  p_color text,
  p_estado text,
  p_roles text[],
  p_orden int,
  p_origen text,
  p_storage_path text,
  p_ruta_nativa text
)
returns public.herramientas
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.herramientas;
  anterior public.herramientas;
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede administrar herramientas.';
  end if;
  if p_estado not in ('activa','proximamente') then
    raise exception 'Estado inválido: %', p_estado;
  end if;
  if p_color not in ('tan','deep','brown') then
    raise exception 'Color inválido: %', p_color;
  end if;
  if p_origen not in ('nativa','subida') then
    raise exception 'Origen inválido: %', p_origen;
  end if;

  if p_id is null then
    insert into public.herramientas
      (slug, nombre, descripcion, color, estado, roles, orden, origen, storage_path, ruta_nativa)
    values
      (p_slug, p_nombre, p_descripcion, p_color, p_estado, p_roles, p_orden, p_origen, p_storage_path, p_ruta_nativa)
    returning * into result;

    insert into public.historial_acciones (actor_email, area, accion, detalle)
    values (lower(auth.email()), 'herramientas', 'herramienta.creada',
      jsonb_build_object('slug', result.slug, 'nombre', result.nombre, 'origen', result.origen, 'roles', result.roles));
  else
    select * into anterior from public.herramientas where id = p_id;

    update public.herramientas set
      slug = p_slug,
      nombre = p_nombre,
      descripcion = p_descripcion,
      color = p_color,
      estado = p_estado,
      roles = p_roles,
      orden = p_orden,
      origen = p_origen,
      storage_path = p_storage_path,
      ruta_nativa = p_ruta_nativa
    where id = p_id
    returning * into result;
    if result.id is null then
      raise exception 'Herramienta no encontrada: %', p_id;
    end if;

    insert into public.historial_acciones (actor_email, area, accion, detalle)
    values (lower(auth.email()), 'herramientas', 'herramienta.editada',
      jsonb_build_object(
        'slug', result.slug,
        'nombre_anterior', anterior.nombre, 'nombre_nuevo', result.nombre,
        'estado_anterior', anterior.estado, 'estado_nuevo', result.estado,
        'roles_anterior', anterior.roles, 'roles_nuevo', result.roles,
        'color_anterior', anterior.color, 'color_nuevo', result.color,
        'orden_anterior', anterior.orden, 'orden_nuevo', result.orden
      ));
  end if;
  return result;
end;
$$;

-- =========================================================================
-- 4. admin_delete_herramienta — mismo cuerpo de 20260920000000, + historial
-- =========================================================================
create or replace function public.admin_delete_herramienta(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  anterior public.herramientas;
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado: solo mario@delamorazumaran.com puede administrar herramientas.';
  end if;

  select * into anterior from public.herramientas where id = p_id;
  delete from public.herramientas where id = p_id;

  if anterior.id is not null then
    insert into public.historial_acciones (actor_email, area, accion, detalle)
    values (lower(auth.email()), 'herramientas', 'herramienta.borrada',
      jsonb_build_object('slug', anterior.slug, 'nombre', anterior.nombre, 'origen', anterior.origen));
  end if;

  return true;
end;
$$;
