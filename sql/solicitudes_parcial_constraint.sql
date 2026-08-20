-- Estados oficiales de Serigrafía: nueva · proceso · parcial · lista
-- 'lista' = ENTREGADO / COMPLETADO (estado final, cierra la ficha)
-- Eliminados: 'programada' y 'entregada'
--
-- ✅ CORRIDO en Supabase el 2026-08-19 (ambos bloques, sin error)

-- 1) Tabla solicitudes
ALTER TABLE solicitudes DROP CONSTRAINT solicitudes_estado_check;
ALTER TABLE solicitudes ADD CONSTRAINT solicitudes_estado_check
  CHECK (estado IN ('nueva', 'proceso', 'parcial', 'lista'));

-- 2) Tabla solicitud_lineas (nivel línea; puede ser NULL = hereda de la solicitud)
ALTER TABLE solicitud_lineas DROP CONSTRAINT IF EXISTS solicitud_lineas_estado_check;
ALTER TABLE solicitud_lineas ADD CONSTRAINT solicitud_lineas_estado_check
  CHECK (estado IS NULL OR estado IN ('nueva', 'proceso', 'parcial', 'lista'));

-- 3) Backfill único: alinear solicitudes.estado con el estado de sus líneas.
-- Antes de syncEstado(), cambiarEstadoLinea() escribía SOLO en solicitud_lineas,
-- así que las fichas viejas quedaron con la línea en 'lista'/'parcial' y la
-- solicitud en 'nueva'. Gana la línea MENOS avanzada (igual que estadoEfectivoSol).
-- ⚠️ NO re-correr: de aquí en adelante syncEstado() mantiene ambos niveles.
UPDATE solicitudes s
SET estado = sub.estado_linea
FROM (
  SELECT solicitud_id,
         (ARRAY_AGG(estado ORDER BY CASE estado
            WHEN 'lista' THEN 3 WHEN 'parcial' THEN 2 ELSE 1 END))[1] AS estado_linea
  FROM solicitud_lineas
  WHERE estado IS NOT NULL
  GROUP BY solicitud_id
) sub
WHERE s.id = sub.solicitud_id AND s.estado <> sub.estado_linea;
