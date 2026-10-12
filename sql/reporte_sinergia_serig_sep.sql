-- ════════════════════════════════════════════════════════════════
-- Reporte: envases serigrafiados ENTREGADOS a SINERGIA en septiembre 2026
-- Fuente: entregas_serig (requis manuales vinculadas a fichas)
-- Solo lectura — no modifica nada.
-- ════════════════════════════════════════════════════════════════

-- ── CONSOLIDADO POR SKU (este es el que necesito) ────────────────
WITH expandido AS (
  -- Entregas con detalle por línea (formato actual)
  SELECT
    e.fecha,
    e.requi,
    coalesce(ln->>'cliente', e.cliente)  AS cliente,
    nullif(trim(ln->>'sku'), '')         AS sku,
    nullif(trim(ln->>'desc'), '')        AS descripcion,
    coalesce((ln->>'cant')::numeric, 0)  AS cant,
    ln->>'solCodigo'                     AS ficha
  FROM entregas_serig e
  CROSS JOIN LATERAL jsonb_array_elements(e.lineas) AS ln
  WHERE e.lineas IS NOT NULL
    AND jsonb_typeof(e.lineas) = 'array'
    AND jsonb_array_length(e.lineas) > 0

  UNION ALL

  -- Entregas viejas sin desglose de líneas
  SELECT
    e.fecha, e.requi, e.cliente,
    NULL::text, NULL::text,
    coalesce(e.cant, 0), e.sol_codigo
  FROM entregas_serig e
  WHERE e.lineas IS NULL
     OR jsonb_typeof(e.lineas) <> 'array'
     OR jsonb_array_length(e.lineas) = 0
)
SELECT
  coalesce(sku, '(sin SKU)')          AS sku,
  coalesce(descripcion, '(sin desc)') AS descripcion,
  sum(cant)::bigint                   AS unidades_entregadas,
  count(*)                            AS n_lineas,
  string_agg(DISTINCT requi, ', ')    AS requis,
  string_agg(DISTINCT ficha, ', ')    AS fichas
FROM expandido
WHERE fecha >= '2026-09-01'
  AND fecha <= '2026-09-30'
  AND upper(cliente) LIKE '%SINERGIA%'
GROUP BY 1, 2
ORDER BY unidades_entregadas DESC;


-- ── DETALLE ENTREGA POR ENTREGA (respaldo / auditoría) ───────────
-- Descomenta si querés ver requi por requi con su fecha.
/*
SELECT e.fecha, e.requi, e.cliente, e.sol_codigo AS ficha,
       ln->>'sku' AS sku, ln->>'desc' AS descripcion,
       (ln->>'cant')::numeric AS cant
FROM entregas_serig e
CROSS JOIN LATERAL jsonb_array_elements(e.lineas) AS ln
WHERE e.fecha BETWEEN '2026-09-01' AND '2026-09-30'
  AND upper(coalesce(ln->>'cliente', e.cliente)) LIKE '%SINERGIA%'
ORDER BY e.fecha, e.requi;
*/
