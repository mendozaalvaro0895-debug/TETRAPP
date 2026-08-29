-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Corrige aviso "Security Definer View" del Security Advisor
-- de Supabase sobre public.v_solicitudes (y v_capacidad_hoy si aplica).
--
-- Una vista SECURITY DEFINER corre con los permisos de quien la CREÓ,
-- ignorando el RLS de quien la consulta — riesgo de fuga de datos.
-- security_invoker = true hace que respete el RLS del usuario que
-- consulta, sin tener que tocar/recrear la definición de la vista.
-- No aparece usada en ningún HTML del repo — si de verdad no se usa,
-- también es válido simplemente hacer DROP VIEW en vez de esto.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter view public.v_solicitudes set (security_invoker = true);

-- Si el Security Advisor también marca esta, correr también:
-- alter view public.v_capacidad_hoy set (security_invoker = true);

-- Verificación — reviewoptions debe incluir security_invoker=true
select relname, reloptions
from pg_class
where relname in ('v_solicitudes', 'v_capacidad_hoy') and relkind = 'v';
