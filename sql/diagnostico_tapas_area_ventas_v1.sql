-- ─────────────────────────────────────────────────────────────────────────────
-- diagnostico_tapas_area_ventas_v1.sql
-- ─────────────────────────────────────────────────────────────────────────────

-- PASO 1: Ver descripciones de los SKUs con null en ventas
-- Corre esto primero para identificar los de descripción desconocida
-- descripcion_familia vive en `ventas` (no en `inventario`); se parte de la lista de SKUs
-- con LEFT JOIN para que aparezcan también los que no existen en inventario.
SELECT
  s.sku,
  i.descripcion                                        AS desc_inventario,
  i.area_ventas,
  string_agg(DISTINCT v.descripcion,         ' | ')    AS desc_ventas,
  string_agg(DISTINCT v.descripcion_familia, ' | ')    AS familia_ventas
FROM (VALUES
  ('106511'),('107036'),('104952'),('107464'),
  ('101243'),('101868'),('107776'),('104141'),
  ('104581'),('105781'),('109091'),('101621')
) AS s(sku)
LEFT JOIN inventario i ON i.sku = s.sku
LEFT JOIN ventas     v ON v.sku = s.sku
GROUP BY s.sku, i.descripcion, i.area_ventas
ORDER BY s.sku;


-- PASO 2 — YA CORRIDO 2026-10-09 (confirmado por Alvaro).
-- SICAF factura con un dígito extra al final del SKU de inventario (ventas 101621 = inventario
-- 10162). ventas.html → clasificarArea() ahora prueba el SKU exacto y, si no hay área fijada,
-- el SKU sin el último dígito; por eso el área se fija en el SKU de 5 dígitos de inventario.
UPDATE inventario SET area_ventas = 'produccion' WHERE sku = '10162' AND area_ventas IS NULL;
UPDATE inventario SET area_ventas = 'tapas'
WHERE sku IN ('10124','10186','10414','10458','10495','10651','10909') AND area_ventas IS NULL;
-- Efecto colateral aceptado: ventas 106825 (tapa roll on negra) pasa a Producción porque su par
-- de inventario 10682 ya estaba marcado 'produccion'.
