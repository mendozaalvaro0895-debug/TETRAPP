-- ════════════════════════════════════════════════════════════
-- Personal — fecha de inicio y fecha de baja por operario
-- Ejecutar manualmente en el dashboard de Supabase (SQL Editor)
-- ════════════════════════════════════════════════════════════

ALTER TABLE personal ADD COLUMN IF NOT EXISTS fecha_inicio DATE;
ALTER TABLE personal ADD COLUMN IF NOT EXISTS fecha_baja   DATE;
