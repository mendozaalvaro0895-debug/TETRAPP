-- ════════════════════════════════════════════════════════════════
-- Fix puntual: vincular SKU 10209 de Requi 1152 con ficha S-045
-- Correr en Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════════

-- 1. Ver el estado actual de la Requi 1152
SELECT id, solicitud_id, sku_original, num_documento, cantidad, area, created_at
FROM public.movimientos_materiales
WHERE num_documento = '1152' AND area = 'serig'
ORDER BY sku_original;

-- 2. Aplicar el fix: asignar solicitud_id de S-045 al renglón con SKU 10209
UPDATE public.movimientos_materiales
SET solicitud_id = (
  SELECT id FROM public.solicitudes
  WHERE codigo = 'S-045' AND area = 'serig'
  LIMIT 1
)
WHERE num_documento = '1152'
  AND sku_original  = '10209'
  AND area          = 'serig'
  AND solicitud_id IS NULL;

-- 3. Verificar resultado (ambos SKUs deben tener solicitud_id distinto de NULL)
SELECT id, solicitud_id, sku_original, num_documento, cantidad
FROM public.movimientos_materiales
WHERE num_documento = '1152' AND area = 'serig'
ORDER BY sku_original;
