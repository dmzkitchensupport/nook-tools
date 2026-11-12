-- NOOK — Resultados: acceso solo para una lista cerrada de personas.
-- Decisión de Mario (11-nov-2026): "SOLO PUEDE VERLO EDUARDO, MARIO Y ROSY".
-- El rol 'gerencia' ya no basta: además, el correo debe estar en resultados_acceso.
-- Mario administra la lista desde resultados/ (nadie más puede verla ni cambiarla).
-- Eduardo y Rosy se agregan por correo desde la página cuando tengan cuenta;
-- no se siembran aquí porque sus correos no están confirmados en ningún archivo.

create table if not exists public.resultados_acceso (
  email text primary key check (email = lower(email)),
  nombre text not null default '',
  agregado_at timestamptz not null default now()
);
alter table public.resultados_acceso enable row level security;
revoke all on public.resultados_acceso from anon, authenticated;

insert into public.resultados_acceso (email, nombre)
values ('mario@delamorazumaran.com', 'Mario')
on conflict (email) do nothing;

create or replace function public.require_resultados()
returns void
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not exists (
    select 1
    from public.profiles p
    join public.resultados_acceso a on a.email = lower(p.email)
    where p.id = auth.uid() and p.aprobado = true
  ) then
    raise exception 'SIN_ACCESO_RESULTADOS';
  end if;
end;
$$;

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
  perform public.require_resultados();
  select * into r from public.resultados_fb where id = 'actual';
  if not found then
    return null;
  end if;
  return jsonb_build_object('payload', r.payload, 'updated_at', r.updated_at);
end;
$$;

create or replace function public.resultados_acceso_list()
returns setof public.resultados_acceso
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado.';
  end if;
  return query select * from public.resultados_acceso order by agregado_at;
end;
$$;

create or replace function public.resultados_acceso_set(p_email text, p_nombre text, p_permitir boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  e text := lower(trim(coalesce(p_email, '')));
begin
  if lower(coalesce(auth.email(), '')) is distinct from 'mario@delamorazumaran.com' then
    raise exception 'No autorizado.';
  end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Correo inválido.';
  end if;
  if e = 'mario@delamorazumaran.com' and not p_permitir then
    raise exception 'El acceso de Mario no se puede quitar.';
  end if;
  if p_permitir then
    insert into public.resultados_acceso (email, nombre) values (e, coalesce(trim(p_nombre), ''))
    on conflict (email) do update set nombre = excluded.nombre;
  else
    delete from public.resultados_acceso where email = e;
  end if;
end;
$$;

revoke all on function public.require_resultados() from public, anon;
revoke all on function public.resultados_acceso_list() from public, anon;
revoke all on function public.resultados_acceso_set(text, text, boolean) from public, anon;
grant execute on function public.require_resultados() to authenticated;
grant execute on function public.resultados_acceso_list() to authenticated;
grant execute on function public.resultados_acceso_set(text, text, boolean) to authenticated;
