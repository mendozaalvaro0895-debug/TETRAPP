-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Asistencia: posición de matriz por día v1.0
-- Habilita la "Matriz Personal y Roles POR DÍA": cada fila de
-- asistencia_diaria guarda en qué CELDA de la matriz estuvo el
-- operador ese día (rol + línea), para registrar quién cubrió cada
-- puesto en días de cambio de roles / inasistencias.
--
--   mtx_pos  = clave de celda de la matriz:
--              "flameador-2", "imprime-3", "recibe-1",
--              "supervisor", "auxiliar", o "" (sin rol / pool ese día)
--   rol      = proceso legible derivado (Flameador/Impresión/…) —
--              lo usan el widget de asistencia y los PDFs
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor ANTES de
-- desplegar el cambio de serigrafia.html. Es idempotente.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE public.asistencia_diaria
  ADD COLUMN IF NOT EXISTS rol     text,   -- proceso legible del día (ya lo usaba guardarRolDiario)
  ADD COLUMN IF NOT EXISTS mtx_pos text;   -- celda de la matriz (rol-línea) del día

-- Refrescar el caché de esquema de PostgREST (evita PGRST204 tras el ALTER)
NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — ambas columnas deben aparecer:
-- ════════════════════════════════════════════════════════════════
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'asistencia_diaria'
  AND column_name IN ('rol','mtx_pos')
ORDER BY column_name;
