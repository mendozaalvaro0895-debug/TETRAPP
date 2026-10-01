-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Reconciliación contra "ASISTENCIA DE PLANTA" — parte 2
--
-- Correr DESPUÉS de sql/personal_area_oficina_v1.sql (este archivo
-- usa area='oficina') y de sql/reconciliacion_hoja_asistencia_v1.sql.
--
-- 1. Código T3: se lo queda Glenda (ya activa, Álvaro la agregó a la
--    hoja compartida), se borra la ficha vieja de Elsa Tul (de baja,
--    a pedido explícito de Álvaro — SÍ es DELETE, no desactivación).
-- 2. Personas que estaban en la hoja compartida pero no existían en
--    `personal` todavía — se agregan con los datos de la hoja.
--    fecha_inicio queda NULL donde la hoja no tenía fecha — Álvaro
--    dijo que esas las corrige él mismo desde TETRAPP.
--
-- Correr en Supabase Dashboard → SQL Editor.
-- ⚠️ NO es 100% idempotente: la sección 1 falla si ya se corrió antes
-- (Elsa ya no existiría) — no pasa nada, son pasos ya hechos.
-- ════════════════════════════════════════════════════════════════

-- 1. Código T3 → Glenda; se borra la ficha de Elsa
delete from public.personal where codigo = 'T3'; -- Elsa Tul (de baja, código liberado)
update public.personal set codigo = 'T3' where codigo = 'T-3'; -- Glenda Mariela Sequen Rodriguez

-- 2. Personas de la hoja que no existían en personal
insert into public.personal (nombre, iniciales, codigo, area, rol, proceso_hab, activo, fecha_inicio) values
  ('HENRY EDUARDO MEJIA HERNANDEZ', 'HE', 'M-01',  'moldes',        'supervisor', null,               true, '2025-11-27'),
  ('LUIS GONZALEZ',                 'LG', 'MT-01', 'mantenimiento', 'supervisor', null,               true, null),
  ('FOX',                           'F',  'TO-01', 'torno',         'operador',   'Diseño Industrial', true, null),
  ('LEIDY ELIZABETH LORENZANA ICUTÉ','LE','OF-01', 'oficina',       'operador',   'Administración',    true, null),
  ('ALVARO MENDOZA ALVAREZ',        'AM', 'OF-02', 'oficina',       'operador',   'Administración',    true, '2025-08-07'),
  ('JOSE DOMINGO SICAJAU MATEO',    'JD', 'OF-03', 'oficina',       'operador',   'Administración',    true, null),
  ('JOSE IGNACIO GARCIA SANTIZO',   'JI', 'OF-04', 'oficina',       'operador',   'Administración',    true, '2026-08-16'),
  ('JOSUE DIONICIO',                'JD', 'OF-05', 'oficina',       'operador',   'Administración',    true, null);

-- Verificación
select nombre, codigo, area, rol, activo, fecha_inicio from public.personal
where area in ('moldes', 'mantenimiento', 'torno', 'oficina') or codigo = 'T3'
order by area, codigo;
