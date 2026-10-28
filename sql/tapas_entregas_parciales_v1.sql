-- ════════════════════════════════════════════════════════════════
-- tapas_entregas_parciales — cantidad que la supervisora REPORTA como entrega parcial de una ficha
-- Pestaña "Pedidos" de registro-tapas.html (rol supervisor_tapas): botón "🟡 Registrar entrega parcial" → cantidad,
-- fecha y nota. Una ficha puede tener VARIAS entregas parciales (una fila cada una).
-- Es un dato INFORMATIVO: NO descuenta del saldo ni toca el inventario. El saldo solo baja cuando oficina registra
-- la requi (ingreso PT vinculado a la ficha en tapas.html → Entregados); hasta entonces cada entrega aparece
-- "⏳ sin requi" y después "✓ con requi" (se calcula en pantalla con el mismo reparto por fecha que los lotes).
-- Por qué una función: el rol de Tapas no puede escribir en `solicitudes`; registrar la entrega también deja la ficha
-- en estado 'parcial' (en `solicitudes` y `solicitud_lineas`). Correr DESPUÉS de sql/tapas_marcar_ficha_v1.sql
-- (usa las columnas marcado_tapas_por / marcado_tapas_en que crea ese archivo).
-- Lectura: cualquiera con perfil · Registrar: master y supervisor_tapas (vía función) · Borrar: master y supervisor_tapas.
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.tapas_entregas_parciales (
  id             uuid primary key default gen_random_uuid(),
  solicitud_id   uuid not null references public.solicitudes(id) on delete cascade,
  cantidad       integer not null check (cantidad > 0),
  fecha          date not null default current_date,
  nota           text,
  registrado_por text,
  created_at     timestamptz not null default now()
);

create index if not exists idx_tapas_entregas_parc_solicitud on public.tapas_entregas_parciales(solicitud_id);

alter table public.tapas_entregas_parciales enable row level security;

drop policy if exists lectura_con_perfil on public.tapas_entregas_parciales;
drop policy if exists delete_tapas       on public.tapas_entregas_parciales;

create policy lectura_con_perfil on public.tapas_entregas_parciales
  for select to authenticated using (public.rol_actual() is not null);
create policy delete_tapas on public.tapas_entregas_parciales
  for delete to authenticated
  using (public.rol_actual() in ('master', 'supervisor_tapas'));

revoke all on public.tapas_entregas_parciales from anon;
grant select, delete on public.tapas_entregas_parciales to authenticated;

create or replace function public.tapas_registrar_parcial(
  p_id uuid, p_cantidad integer, p_fecha date default null, p_nota text default null, p_por text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_estado text;
  v_pedido integer;
  v_nuevo  uuid;
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas') then
    raise exception 'Sin permiso para registrar entregas parciales';
  end if;
  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'La cantidad debe ser mayor a 0';
  end if;
  select estado into v_estado from public.solicitudes where id = p_id and area = 'tapas';
  if not found then
    raise exception 'Ficha de Tapas no encontrada';
  end if;
  if v_estado = 'lista' then
    raise exception 'La ficha ya está COMPLETADA; reábrela desde el administrador';
  end if;
  select coalesce(sum(cantidad), 0) into v_pedido from public.solicitud_lineas where solicitud_id = p_id;
  if v_pedido > 0 and p_cantidad > v_pedido then
    raise exception 'La cantidad (%) supera lo pedido en la ficha (%)', p_cantidad, v_pedido;
  end if;

  insert into public.tapas_entregas_parciales (solicitud_id, cantidad, fecha, nota, registrado_por)
  values (p_id, p_cantidad, coalesce(p_fecha, current_date), nullif(btrim(coalesce(p_nota, '')), ''), p_por)
  returning id into v_nuevo;

  update public.solicitudes
     set estado = 'parcial', marcado_tapas_por = p_por, marcado_tapas_en = now()
   where id = p_id;
  update public.solicitud_lineas set estado = 'parcial' where solicitud_id = p_id;
  return v_nuevo;
end;
$$;

revoke all on function public.tapas_registrar_parcial(uuid, integer, date, text, text) from public, anon;
grant execute on function public.tapas_registrar_parcial(uuid, integer, date, text, text) to authenticated;

notify pgrst, 'reload schema';

-- Verificación: select * from public.tapas_entregas_parciales order by created_at desc;
