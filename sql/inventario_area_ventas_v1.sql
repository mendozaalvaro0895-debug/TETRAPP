-- ─────────────────────────────────────────────────────────────────────────────
-- inventario_area_ventas_v1.sql
-- Agrega columna area_ventas a inventario para reclasificar SKUs cuya área
-- comercial difiere de lo que indica su descripcion_familia.
-- Caso típico: tapas vendidas sin maquila → aportan a Producción, no a Tapas.
--
-- NULL  = sin override, ventas.html usa la familia como siempre
-- 'produccion' / 'tapas' / 'serig' = override explícito
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE inventario
  ADD COLUMN IF NOT EXISTS area_ventas text
  CHECK (area_ventas IN ('produccion', 'tapas', 'serig'));

-- Índice parcial para que la query de overrides en ventas.html sea instantánea
-- (solo lee las filas con valor, que serán pocas)
CREATE INDEX IF NOT EXISTS idx_inventario_area_ventas
  ON inventario (sku)
  WHERE area_ventas IS NOT NULL;
