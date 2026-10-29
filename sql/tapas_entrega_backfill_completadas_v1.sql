-- ════════════════════════════════════════════════════════════════
-- Fichas que la supervisora marcó COMPLETADAS con el botón anterior ("Marcar COMPLETADA", antes del botón único ENTREGA):
-- quedaron en estado 'lista' pero SIN ninguna entrega en tapas_entregas_parciales, así que no aparecían como "pendientes de requi"
-- ni mostraban lo entregado. Este script les crea UNA entrega que completó la ficha por lo que aún no tiene ingreso PT
-- (pedido − ingresos PT ya registrados). Idempotente: solo toca fichas 'lista' marcadas por Tapas que no tengan ninguna entrega.
-- Caso que lo motivó: T-123 (INCOGUA, 2,000 und, marcada el 28-oct-2026).
-- Correr DESPUÉS de sql/tapas_entrega_v1.sql. Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

insert into public.tapas_entregas_parciales (solicitud_id, cantidad, fecha, nota, registrado_por, cierra, created_at)
select s.id,
       q.cant - q.ing,
       (s.marcado_tapas_en at time zone 'America/Guatemala')::date,
       'Completada con el botón anterior; se asume la cantidad pendiente del pedido',
       s.marcado_tapas_por,
       true,
       s.marcado_tapas_en
  from public.solicitudes s
  cross join lateral (
    select coalesce((select sum(l.cantidad) from public.solicitud_lineas l where l.solicitud_id = s.id), 0) as cant,
           coalesce((select sum(m.cantidad) from public.movimientos_materiales m
                      where m.solicitud_id = s.id and m.tipo = 'entrada_pt' and coalesce(m.area, '') <> 'serig'), 0) as ing
  ) q
 where s.area = 'tapas'
   and s.estado = 'lista'
   and s.marcado_tapas_en is not null
   and q.cant - q.ing > 0
   and not exists (select 1 from public.tapas_entregas_parciales e where e.solicitud_id = s.id);
