-- ════════════════════════════════════════════════════════════
-- Movimientos · Serigrafía — area en movimientos_materiales
-- + tabla rechazos (crear si no existe) con origen interno/cliente
-- Ejecutar manualmente en el dashboard de Supabase (SQL Editor)
-- ════════════════════════════════════════════════════════════

-- 1) Separar movimientos por área (tapas vs serig)
ALTER TABLE movimientos_materiales ADD COLUMN IF NOT EXISTS area TEXT;
UPDATE movimientos_materiales SET area = 'tapas' WHERE area IS NULL;

-- 2) Tabla rechazos — crear si no existe (esquema ya usado por tapas.html)
CREATE TABLE IF NOT EXISTS rechazos (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku                 TEXT,
  descripcion         TEXT,
  motivo              TEXT,
  cantidad_rechazada  INTEGER DEFAULT 0,
  cantidad_recuperada INTEGER DEFAULT 0,
  tiempo_min          INTEGER,
  operador_id         TEXT,
  observaciones       TEXT,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- 3) Columnas nuevas para separar área e Interno/Cliente
ALTER TABLE rechazos ADD COLUMN IF NOT EXISTS area TEXT;
ALTER TABLE rechazos ADD COLUMN IF NOT EXISTS origen TEXT DEFAULT 'interno';
ALTER TABLE rechazos ADD COLUMN IF NOT EXISTS cliente TEXT;

UPDATE rechazos SET area   = 'tapas'   WHERE area   IS NULL;
UPDATE rechazos SET origen = 'interno' WHERE origen IS NULL;
