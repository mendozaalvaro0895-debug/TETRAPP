-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Fix fichas completadas en septiembre que quedaron
--           con periodo_efectivo apuntando a agosto.
--
-- Causa: al correr el cierre de agosto, estas fichas estaban en
-- líneas de producción (no en Sin Asignar), por eso no se migró
-- su periodo_efectivo a septiembre.
--
-- Qué hace: actualiza periodo_efectivo al mes de la ÚLTIMA entrega
-- (que es septiembre) para las fichas lista de serigrafía cuya
-- última entrega fue en septiembre pero su período era agosto.
--
-- Idempotente — seguro de re-correr.
-- ════════════════════════════════════════════════════════════════

-- ── 1. Vista previa (no modifica nada) ───────────────────────────
SELECT s.codigo, s.estado, s.periodo_efectivo,
       s.created_at::date AS creada,
       max(e.fecha)       AS ultima_entrega
FROM solicitudes s
JOIN entregas_serig e ON e.sol_id = s.id::text
WHERE s.area   = 'serig'
  AND s.estado = 'lista'
  AND (
    s.periodo_efectivo = '2026-08'
    OR (s.periodo_efectivo IS NULL
        AND date_trunc('month', s.created_at AT TIME ZONE 'America/Guatemala') = '2026-08-01')
  )
GROUP BY s.id, s.codigo, s.estado, s.periodo_efectivo, s.created_at
HAVING max(e.fecha) >= '2026-09-01'
ORDER BY s.codigo;

-- ── 2. Corrección ────────────────────────────────────────────────
-- Descomenta y corre después de verificar la vista previa de arriba.

/*
UPDATE solicitudes s
SET periodo_efectivo = to_char(
  (SELECT max(e.fecha) FROM entregas_serig e WHERE e.sol_id = s.id::text),
  'YYYY-MM'
)
WHERE s.area   = 'serig'
  AND s.estado = 'lista'
  AND (
    s.periodo_efectivo = '2026-08'
    OR (s.periodo_efectivo IS NULL
        AND date_trunc('month', s.created_at AT TIME ZONE 'America/Guatemala') = '2026-08-01')
  )
  AND (
    SELECT max(e.fecha) FROM entregas_serig e WHERE e.sol_id = s.id::text
  ) >= '2026-09-01';

-- Verificación post-update:
SELECT codigo, periodo_efectivo
FROM solicitudes
WHERE area = 'serig'
  AND estado = 'lista'
  AND periodo_efectivo = '2026-09'
ORDER BY codigo;
*/
