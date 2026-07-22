-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Meta de tiros/hora por envase (Serigrafía) v1.0
-- Agrega la columna tiros_hora a inventario para guardar la
-- capacidad de impresión de cada SKU.
--
--   tiros_hora = unidades imprimibles por hora según tipo de envase
--                (ej. Roll-on: 1000/h · Litro: 500/h)
--
-- Al seleccionar un SKU en una nueva solicitud, serigrafia.html
-- auto-rellena el campo "Cap u/h" con este valor. Si el usuario
-- introduce un valor diferente, aparece un popup de confirmación
-- para decidir cuál es el correcto y actualizar la BD si corresponde.
--
-- Es idempotente (ADD COLUMN IF NOT EXISTS).
-- ════════════════════════════════════════════════════════════════

ALTER TABLE public.inventario
  ADD COLUMN IF NOT EXISTS tiros_hora integer;

-- Refrescar el caché de esquema de PostgREST
NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — debe aparecer la columna:
-- ════════════════════════════════════════════════════════════════
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'inventario'
  AND column_name  = 'tiros_hora';
