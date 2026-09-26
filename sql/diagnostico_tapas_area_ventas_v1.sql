-- ─────────────────────────────────────────────────────────────────────────────
-- diagnostico_tapas_area_ventas_v1.sql
-- Lista todos los SKUs de familia TAPA/BASE/CONTRATAPA/LINER que aparecen en
-- ventas, cruzados contra su presencia en el flujo de Tapas (solicitudes).
-- Propósito: identificar cuáles nunca pasaron por maquila y deben quedar como
-- area_ventas = 'produccion'.
--
-- Cómo usar:
--   1. Correr este SELECT en Supabase → SQL Editor.
--   2. Revisar la columna "en_tapas": si es 0, el SKU nunca tuvo solicitud
--      de trabajo en el área de Tapas → candidato a 'produccion'.
--   3. Confirmar con Álvaro y agregar los SKUs confirmados al UPDATE de abajo.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  v.sku,
  i.descripcion,
  i.area_ventas                                          AS area_actual,
  v.descripcion_familia                                  AS familia,
  COUNT(DISTINCT v.id)                                   AS facturas,
  ROUND(SUM(v.total_quetzales)::numeric, 0)              AS total_q,
  SUM(v.total_unidades)                                  AS total_und,
  COUNT(DISTINCT sl.id)                                  AS en_tapas  -- 0 = nunca pasó por solicitud de Tapas
FROM ventas v
LEFT JOIN inventario i
       ON i.sku = v.sku
LEFT JOIN solicitud_lineas sl
       ON sl.sku = v.sku
WHERE v.descripcion_familia IN ('TAPA', 'BASE', 'CONTRATAPA', 'LINER')
  AND (i.area_ventas IS NULL)          -- solo los que aún no tienen override
GROUP BY v.sku, i.descripcion, i.area_ventas, v.descripcion_familia
ORDER BY total_q DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- Una vez revisada la lista, completar los SKUs confirmados aquí y correr:
-- ─────────────────────────────────────────────────────────────────────────────
/*
UPDATE inventario
SET area_ventas = 'produccion'
WHERE sku IN (
  '106811',   -- TAPA ROLL ON BLANCA 90ML ME04819
  '10690',    -- TAPA PARA ROLL-ON FROSTEADA COD.201776
  -- agrega aquí los demás que identifiques con en_tapas = 0
  ''
);
*/
