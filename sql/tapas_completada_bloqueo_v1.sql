-- Fichas COMPLETADAS ya no admiten movimientos de la supervisora (nov/2026).
-- 1) tapas_deshacer_entrega: quien no es master solo puede deshacer un cierre hecho POR TAPAS (hay una entrega con cierra=true);
--    una ficha completada por la oficina (sin entrega que cerró) solo la reabre master. Antes, deshacer la dejaba en 'parcial'
--    y la supervisora podía seguir cargando unidades.
-- 2) tapas_editar_entrega: quien no es master no puede editar una entrega de una ficha COMPLETADA salvo la que la cerró.
-- Correr DESPUÉS del 44 y 49. Idempotente.

create or replace function public.tapas_deshacer_entrega(p_id uuid)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  if public.rol_actual() <> 'master' then
    if v_en is null or v_en < now() - interval '24 hours' then
      raise exception 'Pasaron más de 24 horas desde que se marcó; pídele al administrador que la reabra';
    end if;
    if not exists (select 1 from public.tapas_entregas_parciales where solicitud_id = p_id and cierra) then
      raise exception 'Esta ficha la completó la oficina; pídele al administrador que la reabra';
    end if;
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
$function$;

create or replace function public.tapas_editar_entrega(p_id uuid, p_cantidad integer, p_completa boolean default null, p_por text default null)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  if coalesce(public.rol_actual(), '') <> 'master' and v_estado = 'lista' and not v_cierra then
    raise exception 'La ficha está COMPLETADA: ya no se editan sus entregas; pídele al administrador que la reabra';
  end if;
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
$function$;
