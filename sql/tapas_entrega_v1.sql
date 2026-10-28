-- ════════════════════════════════════════════════════════════════
-- Botón único "ENTREGA" de la supervisora de Tapas (registro-tapas.html → Pedidos → ficha)
-- La supervisora escribe cuántas unidades entregó; la pantalla decide sola si es ENTREGA PARCIAL o COMPLETA
-- (completa = lo que entrega alcanza lo que falta del pedido). Se puede entregar DE MÁS (1,500 sobre 1,000 pedidos):
-- queda registrado el total real y la ficha completada muestra "1,500/1,000".
--   · tapas_registrar_entrega  → inserta la entrega en tapas_entregas_parciales (marcada `cierra` si completó la ficha)
--                                y deja la ficha en 'lista' (completa) o 'parcial'. Sin tope de cantidad.
--   · tapas_deshacer_entrega   → corrige un cierre equivocado: borra la entrega que cerró la ficha y la devuelve a
--                                'parcial' (si quedan otras entregas) o 'nueva'. La supervisora tiene 24 horas desde que
--                                se marcó; master sin límite.
-- Reemplaza en el uso a tapas_marcar_ficha / tapas_registrar_parcial (esas funciones quedan en la base, ya sin uso).
-- Correr DESPUÉS de sql/tapas_marcar_ficha_v2.sql y sql/tapas_entregas_parciales_v1.sql. Idempotente.
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

alter table public.tapas_entregas_parciales add column if not exists cierra boolean not null default false;

create or replace function public.tapas_registrar_entrega(
  p_id uuid, p_cantidad integer, p_completa boolean default false,
  p_fecha date default null, p_nota text default null, p_por text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado text;
  v_nuevo  uuid;
  v_dest   text;
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas', 'operativo') then
    raise exception 'Sin permiso para registrar entregas';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0';
  end if;
  select estado into v_estado from public.solicitudes where id = p_id and area = 'tapas';
  if not found then
    raise exception 'Ficha de Tapas no encontrada';
  end if;
  if v_estado = 'lista' then
    raise exception 'La ficha ya está COMPLETADA; usa Deshacer si fue un error';
  end if;

  v_dest := case when coalesce(p_completa, false) then 'lista' else 'parcial' end;

  insert into public.tapas_entregas_parciales (solicitud_id, cantidad, fecha, nota, registrado_por, cierra)
  values (p_id, p_cantidad, coalesce(p_fecha, current_date), nullif(btrim(coalesce(p_nota, '')), ''), p_por, coalesce(p_completa, false))
  returning id into v_nuevo;

  update public.solicitudes
     set estado = v_dest, marcado_tapas_por = p_por, marcado_tapas_en = now()
   where id = p_id;
  update public.solicitud_lineas set estado = v_dest where solicitud_id = p_id;
  return v_nuevo;
end;
$$;

create or replace function public.tapas_deshacer_entrega(p_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado text;
  v_en     timestamptz;
  v_dest   text;
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas', 'operativo') then
    raise exception 'Sin permiso para deshacer';
  end if;
  select estado, marcado_tapas_en into v_estado, v_en from public.solicitudes where id = p_id and area = 'tapas';
  if not found then
    raise exception 'Ficha de Tapas no encontrada';
  end if;
  if v_estado <> 'lista' then
    raise exception 'La ficha no está COMPLETADA';
  end if;
  if public.rol_actual() <> 'master' and (v_en is null or v_en < now() - interval '24 hours') then
    raise exception 'Pasaron más de 24 horas desde que se marcó; pídele al administrador que la reabra';
  end if;

  delete from public.tapas_entregas_parciales where solicitud_id = p_id and cierra;
  v_dest := case when exists (select 1 from public.tapas_entregas_parciales where solicitud_id = p_id) then 'parcial' else 'nueva' end;

  update public.solicitudes
     set estado = v_dest,
         marcado_tapas_por = case when v_dest = 'nueva' then null else marcado_tapas_por end,
         marcado_tapas_en  = case when v_dest = 'nueva' then null else marcado_tapas_en end
   where id = p_id;
  update public.solicitud_lineas set estado = v_dest where solicitud_id = p_id;
  return v_dest;
end;
$$;

revoke all on function public.tapas_registrar_entrega(uuid, integer, boolean, date, text, text) from public, anon;
grant execute on function public.tapas_registrar_entrega(uuid, integer, boolean, date, text, text) to authenticated;
revoke all on function public.tapas_deshacer_entrega(uuid) from public, anon;
grant execute on function public.tapas_deshacer_entrega(uuid) to authenticated;

notify pgrst, 'reload schema';

-- Verificación: select proname from pg_proc where proname in ('tapas_registrar_entrega','tapas_deshacer_entrega');
