-- ════════════════════════════════════════════════════════════════
-- Reporte: TIROS por operario en septiembre 2026 (módulo Impresión)
-- Fuente: registro_tiros_serig · Solo lectura, no modifica nada.
--
-- MODELO DE DATOS (confirmado por Álvaro 11-sep-2026):
--   El contador de la máquina muestra los TIROS REALIZADOS ESE DÍA
--   (se lee al final de cada turno por foto). Es decir, cada lectura
--   YA es la producción del día — NO es un odómetro acumulado.
--   => tiros del día/línea = la lectura (no máx−mín). Día y velada son
--      turnos distintos de la misma fecha y se SUMAN.
--   Se usa max() por si por error hay más de una lectura del mismo turno.
-- ════════════════════════════════════════════════════════════════

-- ── BLOQUE A · RESUMEN POR PERSONA ───────────────────────────────
with dia as (
  select operador_codigo, operador_nombre, fecha, linea_id,
    coalesce(max(contador) filter (where momento <> 'velada'), 0)
    + coalesce(max(contador) filter (where momento = 'velada'), 0) as tiros
  from registro_tiros_serig
  where area = 'serig'
    and fecha >= '2026-09-01' and fecha < '2026-10-01'
  group by operador_codigo, operador_nombre, fecha, linea_id
)
select
  operador_nombre                                              as persona,
  count(distinct fecha)                                        as dias_reportados,
  sum(tiros)                                                   as tiros_septiembre,
  round(sum(tiros)::numeric / nullif(count(distinct fecha),0)) as promedio_por_dia,
  min(fecha)                                                   as primer_dia,
  max(fecha)                                                   as ultimo_dia
from dia
group by operador_nombre
order by tiros_septiembre desc;


-- ── BLOQUE B · DETALLE: qué día, cuál envase, cuántos tiros ──────
select
  operador_nombre                                as persona,
  fecha,
  'Línea ' || linea_id                           as linea,
  coalesce(nullif(diseno,''), sku)               as envase,
  coalesce(max(contador) filter (where momento <> 'velada'), 0)
  + coalesce(max(contador) filter (where momento = 'velada'), 0) as tiros
from registro_tiros_serig
where area = 'serig'
  and fecha >= '2026-09-01' and fecha < '2026-10-01'
group by operador_nombre, fecha, linea_id, coalesce(nullif(diseno,''), sku)
order by operador_nombre, fecha, linea_id;
