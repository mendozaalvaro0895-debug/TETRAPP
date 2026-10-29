-- ════════════════════════════════════════════════════════════════
-- Corregir la CANTIDAD de una entrega ya reportada por la supervisora (registro-tapas.html → Pedidos → ficha → ✏️; master en tapas.html)
--   · tapas_editar_entrega(p_id, p_cantidad) — master / supervisor_tapas / operativo.
--       - No toca entregas que COMPLETARON la ficha (cierra = true): para esas se usa "Deshacer" (supervisora) o "Reabrir ficha" (master)
--         y se vuelve a registrar, porque cambiar la cantidad cambiaría también el estado de la ficha.
--       - La supervisora puede corregir hasta 24 h después de registrarla (igual que Deshacer); master sin límite.
--       - Deja rastro en la nota de la entrega: "cant. corregida de X a Y".
-- Correr DESPUÉS de sql/tapas_entrega_v1.sql. Idempotente. Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

create or replace function public.tapas_editar_entrega(p_id uuid, p_cantidad integer)
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
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas', 'operativo') then
    raise exception 'Sin permiso para corregir entregas';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0';
  end if;
  select cierra, created_at, cantidad, nota into v_cierra, v_creado, v_antes, v_nota
    from public.tapas_entregas_parciales where id = p_id;
  if not found then
    raise exception 'Entrega no encontrada';
  end if;
  if v_cierra then
    raise exception 'Esta entrega completó la ficha: usa Deshacer (o Reabrir ficha) y regístrala de nuevo';
  end if;
  if coalesce(public.rol_actual(), '') <> 'master' and now() - v_creado > interval '24 hours' then
    raise exception 'Pasaron más de 24 horas: pídele al administrador que la corrija';
  end if;
  if p_cantidad = v_antes then
    return;
  end if;
  update public.tapas_entregas_parciales
     set cantidad = p_cantidad,
         nota = nullif(btrim(coalesce(v_nota, '') || case when coalesce(v_nota, '') <> '' then ' · ' else '' end
                  || 'cant. corregida de ' || v_antes || ' a ' || p_cantidad), '')
   where id = p_id;
end;
$$;

revoke all on function public.tapas_editar_entrega(uuid, integer) from public, anon;
grant execute on function public.tapas_editar_entrega(uuid, integer) to authenticated;

notify pgrst, 'reload schema';
