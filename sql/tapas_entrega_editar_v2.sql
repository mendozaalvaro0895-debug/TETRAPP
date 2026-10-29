-- ════════════════════════════════════════════════════════════════
-- Corregir la CANTIDAD de una entrega ya reportada, TAMBIÉN la que completó la ficha (reemplaza a sql/tapas_entrega_editar_v1.sql)
--   · tapas_editar_entrega(p_id, p_cantidad, p_completa, p_por)
--       - p_completa (opcional): la pantalla calcula si con la nueva cantidad la ficha sigue COMPLETADA o vuelve a ENTREGA PARCIAL
--         (o pasa a COMPLETADA si era parcial) y lo manda aquí; null = no cambia el estado de la ficha.
--         · true  → la entrega queda como la que cerró la ficha y la ficha pasa a 'lista' (si no lo estaba).
--         · false → si la entrega había cerrado la ficha, deja de cerrarla y la ficha vuelve a 'parcial'.
--       - La supervisora puede corregir hasta 24 h después de registrarla (igual que Deshacer); master sin límite.
--       - Deja rastro en la nota de la entrega: "cant. corregida de X a Y".
-- Correr DESPUÉS de sql/tapas_entrega_v1.sql. Idempotente. Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

drop function if exists public.tapas_editar_entrega(uuid, integer);

create or replace function public.tapas_editar_entrega(
  p_id uuid, p_cantidad integer, p_completa boolean default null, p_por text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cierra  boolean;
  v_creado  timestamptz;
  v_antes   integer;
  v_nota    text;
  v_sol     uuid;
  v_estado  text;
  v_nueva   boolean;
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas', 'operativo') then
    raise exception 'Sin permiso para corregir entregas';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0';
  end if;
  select cierra, created_at, cantidad, nota, solicitud_id into v_cierra, v_creado, v_antes, v_nota, v_sol
    from public.tapas_entregas_parciales where id = p_id;
  if not found then
    raise exception 'Entrega no encontrada';
  end if;
  if coalesce(public.rol_actual(), '') <> 'master' and now() - v_creado > interval '24 hours' then
    raise exception 'Pasaron más de 24 horas: pídele al administrador que la corrija';
  end if;
  select estado into v_estado from public.solicitudes where id = v_sol;
  v_nueva := coalesce(p_completa, v_cierra);
  if p_cantidad = v_antes and v_nueva = v_cierra then
    return;
  end if;

  update public.tapas_entregas_parciales
     set cantidad = p_cantidad,
         cierra = v_nueva,
         nota = case when p_cantidad <> v_antes
                     then nullif(btrim(coalesce(v_nota, '') || case when coalesce(v_nota, '') <> '' then ' · ' else '' end
                            || 'cant. corregida de ' || v_antes || ' a ' || p_cantidad), '')
                     else v_nota end
   where id = p_id;

  if v_nueva and v_estado <> 'lista' then
    update public.solicitudes
       set estado = 'lista',
           marcado_tapas_por = coalesce(nullif(btrim(coalesce(p_por, '')), ''), marcado_tapas_por),
           marcado_tapas_en = now()
     where id = v_sol;
    update public.solicitud_lineas set estado = 'lista' where solicitud_id = v_sol;
  elsif (not v_nueva) and v_cierra and v_estado = 'lista' then
    update public.solicitudes set estado = 'parcial' where id = v_sol;
    update public.solicitud_lineas set estado = 'parcial' where solicitud_id = v_sol;
  end if;
end;
$$;

revoke all on function public.tapas_editar_entrega(uuid, integer, boolean, text) from public, anon;
grant execute on function public.tapas_editar_entrega(uuid, integer, boolean, text) to authenticated;

notify pgrst, 'reload schema';
