-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Reconciliación de `personal` contra "ASISTENCIA DE PLANTA"
-- (Google Sheets, compartida por Álvaro — oct/2026)
--
-- Correr DESPUÉS de sql/personal_area_mantenimiento_torno_v1.sql
-- (este archivo usa area='mantenimiento' y area='torno').
--
-- Resuelve, en orden:
--   1. Código casi-duplicado p-57 / P-57 (Wendy Estrada → P-58)
--   2. Bajas confirmadas por Álvaro (Holger Baleu, Miriam Cano)
--   3. Reactivación de Karen Hernández en Tapas (S-17) — había quedado
--      mal desactivada después del fix anterior (Karen/Blandina)
--   4. Área/rol corregidos según la hoja (Gerardo González y Josué
--      Gamaliel Choc → Mantenimiento; Ludwin Alvarez Pérez → Torno)
--   5. fecha_inicio de TODOS los que se pudo emparejar con nombre+
--      ingreso de la hoja (confirmado por Álvaro: la hoja manda)
--
-- Lo que NO se toca acá, pendiente de confirmar con Álvaro:
--   - GLENDA MARIELA SEQUEN RODRIGUEZ (T-3, Tapas) — activa en
--     TETRAPP, no aparece en la hoja compartida.
--   - VIVIAN ESTEFANY JIMENEZ GABRIEL duplicada en Tapas (T-21
--     inactiva / T-50 activa) — se asume T-50 como la correcta
--     (coincide con la hoja) y se le pone fecha, pero T-21 no se
--     borra por si acaso.
--   - HENRY EDUARDO MEJIA HERNANDEZ, supervisor de Moldes según la
--     hoja — no existe todavía en `personal` (falta un INSERT, se
--     deja para cuando Álvaro confirme código/datos).
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

-- 1. Código casi-duplicado: Wendy pasa de p-57 a P-58 (Roxana se queda con P-57)
update public.personal set codigo = 'P-58' where codigo = 'p-57';

-- 2. Bajas confirmadas
update public.personal set activo = false where codigo = 'P-33'; -- Holger Baleu
update public.personal set activo = false where codigo = 'P-10'; -- Miriam Cano

-- 3. Karen Hernández, Tapas — revertir desactivación por error
update public.personal set activo = true
where id = '813aeb90-2c9b-4190-abf8-7b7776a39baa'; -- S-17, Tapas (la correcta)

-- 4. Área/rol corregidos según la hoja
update public.personal set area = 'mantenimiento', rol = 'operador', fecha_inicio = '2022-03-01'
where codigo = 'M-02'; -- Gerardo González (antes: produccion/supervisor)

update public.personal set area = 'mantenimiento'
where codigo = 'M-09'; -- Josué Gamaliel Choc (antes: moldes)

update public.personal set area = 'torno'
where codigo = 'M-08'; -- Ludwin Alvarez Pérez (antes: moldes)

-- 5. fecha_inicio según el ingreso real de la hoja (emparejado por nombre)
update public.personal as p set fecha_inicio = v.fecha::date
from (values
  -- Producción
  ('P-30','2026-06-16'), ('P-40','2026-03-03'), ('P-42','2026-09-11'),
  ('P-32','2026-07-15'), ('P-20','2026-01-05'), ('P-25','2024-07-28'),
  ('P-29','2025-08-04'), ('P-54','2022-08-10'), ('P-49','2025-06-15'),
  ('P-41','2026-09-09'), ('P-34','2021-04-08'), ('P-27','2020-06-21'),
  ('P-48','2026-01-19'), ('P-55','2019-01-10'), ('P-37','2025-01-15'),
  ('P-11','2026-05-26'), ('P-50','2026-09-17'), ('P-14','2025-01-16'),
  ('P-31','2026-04-18'), ('P-16','2026-05-07'), ('P-53','2026-09-17'),
  ('P-17','2026-05-05'), ('P-18','2022-02-02'), ('P-39','2025-11-03'),
  ('P-52','2026-08-01'), ('P-57','2026-09-29'), ('P-23','2026-06-03'),
  ('P-24','2025-03-13'), ('P-19','2025-09-03'), ('P-58','2026-09-28'),
  ('P-28','2026-03-03'), ('P-12','2025-02-02'), ('P-35','2025-10-22'),
  -- Serigrafía
  ('0307','2026-07-03'), ('S1','2024-10-18'), ('S8','2025-03-10'),
  ('S4','2025-01-11'), ('S6','2026-03-01'), ('1908','2026-08-19'),
  ('290726','2026-07-26'), ('S10','2021-04-05'), ('S3','2025-01-14'),
  ('t-18','2026-09-01'), ('S0','2024-06-17'), ('S-19','2026-09-30'),
  ('S2','2024-11-10'), ('S17','2026-09-28'), ('19082','2026-08-18'),
  ('S18','2026-09-28'),
  -- Tapas
  ('T4','2026-01-26'), ('T-5','2026-08-03'), ('P-38','2023-05-24'),
  ('T7','2024-07-01'), ('T2','2025-01-06'), ('T9','2026-01-08'),
  ('T8','2025-09-18'), ('T-50','2026-09-30'), ('T1','2023-08-03'),
  ('S-17','2026-09-16'),
  -- Moldes / Molino
  ('M-06','2026-07-08'), ('M-07','2019-08-01')
) as v(codigo, fecha)
where p.codigo = v.codigo;

-- Verificación — revisar que no queden dos filas con el mismo código
select codigo, count(*) from public.personal group by codigo having count(*) > 1;

-- Verificación — estado final de los casos tocados a mano
select nombre, codigo, area, activo, rol, fecha_inicio from public.personal
where codigo in ('P-58','P-33','P-10','S-17','M-02','M-09','M-08')
order by codigo;
