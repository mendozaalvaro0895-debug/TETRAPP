-- ══════════════════════════════════════════════════════════════════
-- INSUMOS B7 v2 — tabla separada (corrige colisión de SKUs con B2)
-- Corre en Supabase → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── PASO 1: Revertir v1 ───────────────────────────────────────────
-- Los 51 SKUs que se reetiquetaron como B7 en inventario vuelven a B2.
-- Los que originalmente eran B2 (ej. 7057 = BARRA DE ACERO) recuperan
-- su estado correcto; los que no existían en B2 quedan con bodega='B2'
-- y existencia=0, sin impacto.
UPDATE inventario
SET bodega = 'B2', stock_minimo = NULL
WHERE sku IN (
  '6240','6251','6252','6235','6245','6237','6328','6256',
  '6735','7139','6242','6339','6342','6341','6734','6733',
  '6320','6250','6401','6793','6330','6312','6377','6313',
  '6376','6301','6324','6236','6238','6239','6120','6354',
  '6863','7057','7118','6700','6457','6322','6246','6247',
  '6249','6309','6300','6243','6736','6439','6865','7116',
  '6257','6321','6241'
);

-- ── PASO 2: Tabla dedicada Bodega 7 ──────────────────────────────
CREATE TABLE IF NOT EXISTS insumos_b7 (
  id           BIGSERIAL PRIMARY KEY,
  sku          TEXT        NOT NULL UNIQUE,
  descripcion  TEXT        NOT NULL,
  existencia   NUMERIC     NOT NULL DEFAULT 0,
  stock_minimo NUMERIC     DEFAULT NULL,
  activo       BOOLEAN     NOT NULL DEFAULT true,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── PASO 3: RLS ──────────────────────────────────────────────────
ALTER TABLE insumos_b7 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "b7_select" ON insumos_b7;
DROP POLICY IF EXISTS "b7_insert" ON insumos_b7;
DROP POLICY IF EXISTS "b7_update" ON insumos_b7;
CREATE POLICY "b7_select" ON insumos_b7 FOR SELECT USING (true);
CREATE POLICY "b7_insert" ON insumos_b7 FOR INSERT WITH CHECK (true);
CREATE POLICY "b7_update" ON insumos_b7 FOR UPDATE USING (true);

-- ── PASO 4: 51 insumos con descripciones CORRECTAS ───────────────
-- ON CONFLICT: si ya existía, actualiza descripción y mínimo.
INSERT INTO insumos_b7 (sku, descripcion, stock_minimo)
VALUES
  ('6240', 'AZUL COBALTO POLICAT (R2-2191)',          2),
  ('6251', 'AZUL MEDIO POLICAT R2-2013',               2),
  ('6252', 'AZUL TURQUEZA POLICAT R2-2012',            2),
  ('6235', 'AZUL ULTRA POLICAT (R2-2020)',             2),
  ('6245', 'BICROMATO (U5-2002)',                      2),
  ('6237', 'BLANCO POLICAT (R2-6011)',                 2),
  ('6328', 'BUGAMBILIA POLICAT',                       2),
  ('6256', 'CAFE POLICAT',                             2),
  ('6735', 'CATALIZADOR EPOXICO',                      2),
  ('7139', 'CATALIZADOR EPOXICO ADE677',               2),
  ('6242', 'CATALIZADOR POLICAT (R2-100)',              2),
  ('6339', 'CILINDRO DE GAS DE 100 LIBRAS',            1),
  ('6342', 'CILINDRO DE GAS DE 25 LIBRAS',             1),
  ('6341', 'CILINDRO DE GAS DE 35 LIBRAS',             1),
  ('6734', 'EPOXICA APAQUE WHITE NAZDAR',               2),
  ('6733', 'EPOXICA MAGENTA NAZDAR',                   1),
  ('6320', 'GALON THINNER',                            3),
  ('6250', 'HULE ANCHO (HAN)',                         4),
  ('6401', 'HULE CUADRADO',                            4),
  ('6793', 'HULE DIAMANTE DUREZA 80',                  4),
  ('6330', 'MALLA AMARILLA N.0 380 150/ 380-34',       4),
  ('6312', 'MALLA AMARILLA NO. 330',                   4),
  ('6377', 'MALLA AMARILLA NO. 355',                   4),
  ('6313', 'MALLA AMARILLA NO.305 (ANCHO 65)',         4),
  ('6376', 'MALLA BLANCA 305',                         4),
  ('6301', 'MALLA BLANCA NO. 120 (ANCHO 65)',          4),
  ('6324', 'MANDARINA POLICAT',                        2),
  ('6236', 'NEGRO POLICAT (R2-1011)',                   2),
  ('6238', 'ORO ROJIZO POLICAT (R2-4092)',              2),
  ('6239', 'PLATA POLICAT (R2-6091)',                   2),
  ('6120', 'PLIEGOS DE PAPEL CRAFT',                   500),
  ('6354', 'POLIYALL BLACK PA70',                      2),
  ('6863', 'POLIYALL BRIGHT RED PA52',                 2),
  ('7057', 'POLIYALL EMERALD GREEN PA30',              2),
  ('7118', 'POLIYALL REFLEX BLUE PA450',               2),
  ('6700', 'POLIYALL YELLOW PA21',                     2),
  ('6457', 'REMOVEDOR DE EMULSION LIQUIDO',            2),
  ('6322', 'ROJO ESCARLATA POLICAT',                   2),
  ('6246', 'SERICLIN (U9-9200)',                       2),
  ('6247', 'SERISOL (U5-4020)',                        2),
  ('6249', 'SOLVENTE (P1-300)',                        2),
  ('6309', 'SOLVENTE ACONDICIONADOR P1-600',           2),
  ('6300', 'SOLVENTE LIMPIA PANTALLAS P103',           3),
  ('6243', 'SOLVENTE RETARDANTE (P1-901)',              2),
  ('6736', 'SOLVENTE RETARDER EPOXICO',                2),
  ('6439', 'SOLVENTE RETARDER EPOXICO ER-189',         2),
  ('6865', 'SOLVENTE RETARDER PARA POLIYALL PAQ8',    2),
  ('7116', 'TINTA EPOXICA SILVER ER-187',              2),
  ('6257', 'VERDE BANDERA POLICAT',                    2),
  ('6321', 'VERDE BRILLANTE POLICAT',                  2),
  ('6241', 'VIOLETA POLICAT (R2-8164)',                2)
ON CONFLICT (sku) DO UPDATE SET
  descripcion  = EXCLUDED.descripcion,
  stock_minimo = EXCLUDED.stock_minimo,
  updated_at   = NOW();
