-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Flameado: destino del envase base v1.0
-- Cierra el "hueco de datos" en la trazabilidad Salida→PT:
-- cada fila de flameado ahora guarda a qué PEDIDO y SKU IMPRESO
-- va dirigido el envase base que se flameó, no solo la línea.
--
-- Contexto: entre Flameado e Impresión hay un "cambio de idioma de
-- SKU" (antes = envase base, después = SKU impreso). El puente era
-- inferido (línea + fecha → pedido). Estas columnas lo vuelven
-- EXPLÍCITO por fila, y desambiguan el caso roll-on (un mismo base
-- alimenta varias líneas/diseños).
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor ANTES de
-- desplegar el cambio de registro-serigrafia.html.
-- Es idempotente: se puede correr varias veces sin romper nada.
-- ════════════════════════════════════════════════════════════════

ALTER TABLE public.registro_flameado_serig
  ADD COLUMN IF NOT EXISTS solicitud_id        uuid,   -- ref suave a solicitudes.id (SIN FK dura a propósito)
  ADD COLUMN IF NOT EXISTS destino_sku         text,   -- SKU impreso al que va dirigido este base
  ADD COLUMN IF NOT EXISTS destino_descripcion text;   -- descripción del SKU impreso destino

-- Índice para reportes de conciliación por pedido
CREATE INDEX IF NOT EXISTS idx_flam_solicitud
  ON public.registro_flameado_serig (solicitud_id);

-- Refrescar el caché de esquema de PostgREST
-- (evita PGRST204 "column not found" justo después del ALTER)
NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN — las 3 columnas deben aparecer:
-- ════════════════════════════════════════════════════════════════
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'registro_flameado_serig'
  AND column_name IN ('solicitud_id','destino_sku','destino_descripcion')
ORDER BY column_name;
