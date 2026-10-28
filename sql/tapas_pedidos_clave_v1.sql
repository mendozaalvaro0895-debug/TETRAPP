-- ════════════════════════════════════════════════════════════════
-- Contraseña de la pestaña "📋 Pedidos" del perfil de Tapas (registro-tapas.html)
-- Para que solo la supervisora (y master) vean las fichas: al tocar la pestaña se pide la clave.
--   · tapas_acceso                  → guarda SOLO el hash (con sal) de la clave. RLS activo y SIN políticas ni grants:
--                                     ningún rol puede leerla ni escribirla directo, solo las funciones de abajo.
--   · tapas_pedidos_verificar       → devuelve true/false (master / supervisor_tapas / operativo)
--   · tapas_pedidos_cambiar_clave   → solo master (botón "🔑 Clave de Pedidos" en tapas.html)
-- Clave inicial: 1234 (cambiarla desde tapas.html apenas se estrene).
-- ⚠️ Es una barrera para que los operarios no abran la pestaña desde la app; los datos de las fichas siguen siendo
--    legibles por el login del perfil de Tapas (RLS de solicitudes). Idempotente.
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.tapas_acceso (
  clave          text primary key,
  sal            text not null,
  hash           text not null,
  actualizado_en timestamptz not null default now(),
  actualizado_por text
);

alter table public.tapas_acceso enable row level security;
revoke all on public.tapas_acceso from anon, authenticated;

-- Clave inicial 1234 (solo si aún no existe)
insert into public.tapas_acceso (clave, sal, hash, actualizado_por)
values ('pedidos', 'tetra-ped-1', encode(sha256(convert_to('tetra-ped-1' || '1234', 'UTF8')), 'hex'), 'inicial')
on conflict (clave) do nothing;

create or replace function public.tapas_pedidos_verificar(p_clave text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sal  text;
  v_hash text;
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas', 'operativo') then
    raise exception 'Sin permiso';
  end if;
  select sal, hash into v_sal, v_hash from public.tapas_acceso where clave = 'pedidos';
  if not found then
    return false;
  end if;
  return encode(sha256(convert_to(v_sal || coalesce(p_clave, ''), 'UTF8')), 'hex') = v_hash;
end;
$$;

create or replace function public.tapas_pedidos_cambiar_clave(p_nueva text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sal text;
begin
  if coalesce(public.rol_actual(), '') <> 'master' then
    raise exception 'Solo master puede cambiar la clave';
  end if;
  if p_nueva is null or length(btrim(p_nueva)) < 4 then
    raise exception 'La clave debe tener al menos 4 caracteres';
  end if;
  v_sal := md5(random()::text || clock_timestamp()::text);
  insert into public.tapas_acceso (clave, sal, hash, actualizado_en, actualizado_por)
  values ('pedidos', v_sal, encode(sha256(convert_to(v_sal || btrim(p_nueva), 'UTF8')), 'hex'), now(), 'master')
  on conflict (clave) do update
     set sal = excluded.sal, hash = excluded.hash, actualizado_en = now(), actualizado_por = 'master';
end;
$$;

revoke all on function public.tapas_pedidos_verificar(text) from public, anon;
revoke all on function public.tapas_pedidos_cambiar_clave(text) from public, anon;
grant execute on function public.tapas_pedidos_verificar(text) to authenticated;
grant execute on function public.tapas_pedidos_cambiar_clave(text) to authenticated;

notify pgrst, 'reload schema';
