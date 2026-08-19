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
