-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Diagnóstico previo al Tablero de Trazabilidad
-- SOLO LECTURA. No modifica nada. Correr en Supabase → SQL Editor
-- y pegar los 6 resultados de vuelta.
--
-- Objetivo: verificar la salud de los datos antes de construir el
-- tablero que cruza Salida→Flameado→Impresión→Empaque→PT.
-- ════════════════════════════════════════════════════════════════


-- ── A. ¿Está poblado el multiplicador de TIROS? ──────────────────
-- Flameado cuenta ENVASES; Impresión cuenta TIROS.
-- tiros_impresos ≈ envases × solicitud_lineas.tiros
-- Si casi todo cae en tiros=1 pero muchos diseños son de 2, el cruce
-- Flameado↔Impresión se verá descuadrado y NO es culpa del tablero.
SELECT
  COALESCE(sl.tiros, 0) AS tiros_por_diseno,
  COUNT(*)              AS cantidad_lineas
FROM solicitud_lineas sl
JOIN solicitudes s ON s.id = sl.solicitud_id
WHERE s.area = 'serig'
GROUP BY 1
ORDER BY 1;


-- ── B. La salida de bodega: ¿guarda SKU BASE o IMPRESO? ──────────
-- El escalón Salida↔Flameado asume que ambos hablan en BASE.
-- Esto revela qué SKU está metiendo bodega de verdad.
SELECT
  CASE
    WHEN m.solicitud_id IS NULL THEN '4 · sin pedido vinculado'
    WHEN EXISTS (SELECT 1 FROM solicitud_lineas sl
                 WHERE sl.solicitud_id = m.solicitud_id AND sl.sku_base = m.sku_original)
      THEN '1 · coincide con BASE (correcto)'
    WHEN EXISTS (SELECT 1 FROM solicitud_lineas sl
                 WHERE sl.solicitud_id = m.solicitud_id AND sl.sku = m.sku_original)
      THEN '2 · coincide con IMPRESO (revisar)'
    ELSE '3 · no coincide con ninguno'
  END           AS tipo_sku,
  COUNT(*)      AS movimientos,
  SUM(m.cantidad) AS unidades
FROM movimientos_materiales m
WHERE m.tipo = 'salida_bodega'
  AND COALESCE(m.area, 'serig') = 'serig'
GROUP BY 1
ORDER BY 1;


-- ── C. ¿Cuánto PT vive en cada tabla? ────────────────────────────
-- Hay dos fuentes posibles: movimientos(entrada_pt) y entregas_serig.
-- El tablero necesita UNA fuente de verdad.
SELECT 'movimientos entrada_pt' AS fuente,
       COUNT(*)                 AS filas,
       SUM(cantidad)            AS unidades
FROM movimientos_materiales
WHERE tipo = 'entrada_pt' AND COALESCE(area, 'serig') = 'serig'
UNION ALL
SELECT 'entregas_serig' AS fuente,
       COUNT(*)         AS filas,
       NULL             AS unidades
FROM entregas_serig;


-- ── D. Columnas reales de entregas_serig ─────────────────────────
-- Para saber qué campos tiene (cantidad, sku, solicitud, requi…).
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'entregas_serig'
ORDER BY ordinal_position;


-- ── E. ¿Están poblados los sku_base en los pedidos? ──────────────
-- Los chips de flameado y la reconciliación base dependen de esto.
SELECT
  COUNT(*)                                                      AS total_lineas,
  COUNT(*) FILTER (WHERE sl.sku_base IS NOT NULL AND sl.sku_base <> '') AS con_sku_base
FROM solicitud_lineas sl
JOIN solicitudes s ON s.id = sl.solicitud_id
WHERE s.area = 'serig';


-- ── F. Sanity del destino recién agregado a Flameado ─────────────
-- Confirma que el formulario ya está escribiendo destino_sku/solicitud_id
-- en los registros nuevos (los viejos irán en NULL, es esperado).
SELECT
  COUNT(*)                  AS total_flameado,
  COUNT(destino_sku)        AS con_destino_sku,
  COUNT(solicitud_id)       AS con_solicitud_id
FROM registro_flameado_serig
WHERE area = 'serig';
