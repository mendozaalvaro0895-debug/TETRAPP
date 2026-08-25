-- ============================================================
-- SOFT DELETE solicitudes + solicitud_lineas
-- Correr en Supabase SQL Editor antes de desplegar el cambio
-- ============================================================

ALTER TABLE solicitudes     ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE solicitud_lineas ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Índice para que el filtro IS NULL sea rápido
CREATE INDEX IF NOT EXISTS idx_solicitudes_deleted
  ON solicitudes(deleted_at) WHERE deleted_at IS NULL;

-- Verificar
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('solicitudes','solicitud_lineas')
  AND column_name = 'deleted_at'
ORDER BY table_name;
