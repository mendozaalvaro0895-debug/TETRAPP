-- ════════════════════════════════════════════════════════════════
-- TETRAPP — personal: fecha_nacimiento (reemplaza a edad) + talla_botas
--
-- fecha_nacimiento: gestion.html → Personal → Datos generales ahora pide
-- fecha de nacimiento en vez de un número de edad fijo — la edad se
-- calcula en vivo desde esta fecha (calcularEdad() en gestion.html) y
-- se actualiza sola con el tiempo. La columna vieja `edad` NO se borra
-- ni se vuelve a escribir — queda como respaldo de solo lectura para
-- personas que todavía no tengan fecha_nacimiento cargada
-- (edadDePersona() en gestion.html cae a `edad` si fecha_nacimiento
-- está vacía).
--
-- talla_botas: gestion.html → Personal → RRHH, junto a Talla de uniforme.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal add column if not exists fecha_nacimiento date;
alter table public.personal add column if not exists talla_botas text;

-- Verificación
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'personal'
  and column_name in ('fecha_nacimiento', 'talla_botas', 'edad');
