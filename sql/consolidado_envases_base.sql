-- ══════════════════════════════════════════════════════════════════
-- CONSOLIDADO DE ENVASES BASE vs INVENTARIO B2
-- Serigrafía · SOLO LECTURA (no modifica nada)
--
-- Responde: de los pedidos pendientes/parciales, ¿qué envase base
-- necesito, cuánto tengo en Bodega 2 y cuánto le pido a producción?
--
-- Correr en Supabase → SQL Editor. Devuelve 3 bloques; el SQL Editor
-- solo muestra el resultado de la ÚLTIMA sentencia, así que se corren
-- de uno en uno (o se selecciona el bloque y se ejecuta la selección).
-- ══════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════
-- BLOQUE 1 · EL CONSOLIDADO  ← este es el que te interesa
-- ══════════════════════════════════════════════════════════════════
WITH
-- Pedidos vivos: los que aún consumen envase.
-- 'lista' queda fuera (ya se produjo); ajustar aquí si cambia el criterio.
pedidos_vivos AS (
  SELECT s.id, s.codigo, s.cliente_nombre,
         -- El período usa hora local de Guatemala (UTC-6): un pedido
         -- ingresado el 27/07 a las 19:00 local es 28/07 en UTC.
         CASE WHEN (s.created_at AT TIME ZONE 'America/Guatemala')::date
                   >= DATE '2026-07-28'
              THEN 'AGOSTO' ELSE 'JULIO_backlog' END AS periodo
  FROM solicitudes s
  WHERE s.area = 'serig'
    AND s.estado IN ('nueva','programada','proceso','parcial')
),

-- Demanda por envase base, separada por período
demanda AS (
  SELECT sl.sku_base,
         COUNT(DISTINCT pv.id)                                             AS pedidos,
         SUM(sl.cantidad)                                                  AS und_total,
         SUM(sl.cantidad) FILTER (WHERE pv.periodo = 'AGOSTO')             AS und_agosto,
         SUM(sl.cantidad) FILTER (WHERE pv.periodo = 'JULIO_backlog')      AS und_backlog
  FROM solicitud_lineas sl
  JOIN pedidos_vivos pv ON pv.id = sl.solicitud_id
  WHERE sl.sku_base IS NOT NULL AND sl.sku_base <> ''
  GROUP BY sl.sku_base
),

-- Lo que YA salió de bodega para esos mismos pedidos: no hay que
-- volver a pedirlo. Se cruza por sku_original = sku_base.
ya_salido AS (
  SELECT m.sku_original AS sku_base, SUM(m.cantidad) AS und_salidas
  FROM movimientos_materiales m
  JOIN pedidos_vivos pv ON pv.id = m.solicitud_id
  WHERE m.tipo = 'salida_bodega'
    AND COALESCE(m.area,'serig') = 'serig'
  GROUP BY m.sku_original
),

-- Existencia en Bodega 2
stock_b2 AS (
  SELECT i.sku, i.descripcion, i.existencia
  FROM inventario i
  WHERE COALESCE(i.bodega,'B2') = 'B2'
)

SELECT
  d.sku_base                                              AS "SKU base",
  COALESCE(b.descripcion,'⚠️ no está en B2')              AS "Descripción",
  d.pedidos                                               AS "Pedidos",
  COALESCE(d.und_agosto,0)                                AS "Und AGOSTO",
  COALESCE(d.und_backlog,0)                               AS "Und backlog",
  d.und_total                                             AS "Und total",
  COALESCE(ys.und_salidas,0)                              AS "Ya salió",
  GREATEST(d.und_total - COALESCE(ys.und_salidas,0), 0)   AS "Neto pendiente",
  COALESCE(b.existencia,0)                                AS "Stock B2",
  GREATEST(
    GREATEST(d.und_total - COALESCE(ys.und_salidas,0), 0)
    - COALESCE(b.existencia,0), 0)                        AS "⚠️ PEDIR A PRODUCCIÓN",
  CASE
    WHEN b.sku IS NULL THEN '❌ SKU no existe en B2'
    WHEN COALESCE(b.existencia,0) >=
         GREATEST(d.und_total - COALESCE(ys.und_salidas,0), 0) THEN '✅ alcanza'
    WHEN COALESCE(b.existencia,0) = 0 THEN '🔴 sin stock'
    ELSE '🟡 alcanza parcial'
  END                                                     AS "Estado"
FROM demanda d
LEFT JOIN stock_b2  b  ON b.sku      = d.sku_base
LEFT JOIN ya_salido ys ON ys.sku_base = d.sku_base
ORDER BY 10 DESC, 6 DESC;


-- ══════════════════════════════════════════════════════════════════
-- BLOQUE 2 · HUECOS — líneas sin sku_base
-- Estas NO entran en el consolidado de arriba. Si aquí sale algo,
-- el bloque 1 está subestimando la necesidad real.
-- ══════════════════════════════════════════════════════════════════
SELECT s.codigo         AS "Pedido",
       s.cliente_nombre AS "Cliente",
       s.estado         AS "Estado",
       sl.sku           AS "SKU impreso",
       sl.descripcion   AS "Descripción",
       sl.cantidad      AS "Cantidad"
FROM solicitud_lineas sl
JOIN solicitudes s ON s.id = sl.solicitud_id
WHERE s.area = 'serig'
  AND s.estado IN ('nueva','programada','proceso','parcial')
  AND (sl.sku_base IS NULL OR sl.sku_base = '')
ORDER BY s.cliente_nombre, s.codigo;


-- ══════════════════════════════════════════════════════════════════
-- BLOQUE 3 · RESUMEN EJECUTIVO
-- ══════════════════════════════════════════════════════════════════
WITH pedidos_vivos AS (
  SELECT s.id FROM solicitudes s
  WHERE s.area = 'serig'
    AND s.estado IN ('nueva','programada','proceso','parcial')
),
d AS (
  SELECT sl.sku_base, SUM(sl.cantidad) AS und
  FROM solicitud_lineas sl
  JOIN pedidos_vivos pv ON pv.id = sl.solicitud_id
  WHERE sl.sku_base IS NOT NULL AND sl.sku_base <> ''
  GROUP BY sl.sku_base
),
ys AS (
  SELECT m.sku_original AS sku_base, SUM(m.cantidad) AS und
  FROM movimientos_materiales m
  JOIN pedidos_vivos pv ON pv.id = m.solicitud_id
  WHERE m.tipo = 'salida_bodega' AND COALESCE(m.area,'serig') = 'serig'
  GROUP BY m.sku_original
),
calc AS (
  SELECT d.sku_base,
         GREATEST(d.und - COALESCE(ys.und,0), 0) AS neto,
         COALESCE(i.existencia,0)                AS stock,
         (i.sku IS NULL)                         AS huerfano
  FROM d
  LEFT JOIN ys ON ys.sku_base = d.sku_base
  LEFT JOIN inventario i ON i.sku = d.sku_base AND COALESCE(i.bodega,'B2') = 'B2'
)
SELECT 'Envases base distintos'          AS "Métrica", COUNT(*)::text AS "Valor" FROM calc
UNION ALL SELECT 'Con faltante',          COUNT(*)::text FROM calc WHERE neto > stock
UNION ALL SELECT 'Sin stock (cero)',      COUNT(*)::text FROM calc WHERE stock = 0 AND neto > 0
UNION ALL SELECT 'SKU no existe en B2',   COUNT(*)::text FROM calc WHERE huerfano
UNION ALL SELECT 'Und netas requeridas',  SUM(neto)::text FROM calc
UNION ALL SELECT 'Und a pedir a producción',
                 SUM(GREATEST(neto - stock, 0))::text FROM calc;
