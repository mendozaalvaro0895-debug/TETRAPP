-- ════════════════════════════════════════════════════════════════
-- tapas_marcar_ficha — la supervisora de Tapas marca una ficha como COMPLETADA o ENTREGA PARCIAL
-- Pestaña "Pedidos" de registro-tapas.html (rol supervisor_tapas): botones "✅ Marcar COMPLETADA" y "🟡 Entrega parcial".
-- Por qué una función y no un UPDATE directo: el rol de Tapas NO puede escribir en `solicitudes` (la política de
-- update es solo master) y abrirla le daría control sobre TODAS las columnas (cliente, cantidades, fecha límite…).
-- Esta función (SECURITY DEFINER) solo permite pasar una ficha de Tapas a 'lista' o 'parcial', escribe el estado en
-- `solicitudes` Y en todas sus `solicitud_lineas` (la tarjeta lee l.estado || s.estado: la línea manda) y deja
-- registrado quién y cuándo la marcó. Ejecutan: master y supervisor_tapas (NO el rol operativo).
-- Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

alter table public.solicitudes add column if not exists marcado_tapas_por text;
alter table public.solicitudes add column if not exists marcado_tapas_en timestamptz;

create or replace function public.tapas_marcar_ficha(p_id uuid, p_estado text, p_por text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(public.rol_actual(), '') not in ('master', 'supervisor_tapas') then
    raise exception 'Sin permiso para marcar fichas de Tapas';
  end if;
  if p_estado not in ('lista', 'parcial') then
    raise exception 'Estado no permitido: % (solo lista o parcial)', p_estado;
  end if;
  if not exists (select 1 from public.solicitudes where id = p_id and area = 'tapas') then
    raise exception 'Ficha de Tapas no encontrada';
  end if;

  update public.solicitudes
     set estado = p_estado, marcado_tapas_por = p_por, marcado_tapas_en = now()
   where id = p_id;
  update public.solicitud_lineas set estado = p_estado where solicitud_id = p_id;
end;
$$;

revoke all on function public.tapas_marcar_ficha(uuid, text, text) from public, anon;
grant execute on function public.tapas_marcar_ficha(uuid, text, text) to authenticated;

notify pgrst, 'reload schema';

-- Verificación (como master): marca una ficha de prueba y revísala; para deshacer, "↩ Reabrir" en tapas.html
-- select id, codigo, estado, marcado_tapas_por, marcado_tapas_en from public.solicitudes where marcado_tapas_en is not null;
