-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Endurecimiento de funciones y vistas (Security Advisor de Supabase, 31-oct-2026)
--
-- 1) Las RPC bot_* son SECURITY DEFINER y estaban ejecutables por `anon`: cualquiera con la clave pública
--    (la que va en el front) podía llamar a /rest/v1/rpc/bot_insertar_* y escribir tiros, flameado, empaque
--    y comandas de Tapas SIN iniciar sesión. Solo las usa api/whatsapp.js (service_role); comandas.html
--    (master, sesión iniciada) usa únicamente bot_buscar_sku y bot_buscar_operario.
--      · anon y PUBLIC pierden EXECUTE en las 6 bot_* y en get_area_ventas_overrides (ventas.html/index.html
--        la llaman con sesión).
--      · bot_insertar_* también pierden EXECUTE para `authenticated` (nadie con sesión las usa).
--      · service_role y authenticated (en buscar/overrides) conservan su acceso.
-- 2) 8 funciones sin search_path fijo → se fija en public (evita que un esquema ajeno se cuele).
-- 3) Vista v_capacidad_hoy: security_invoker = true (respeta el RLS de quien consulta; no la usa ningún HTML).
--
-- No cambia datos. Reversible con GRANT EXECUTE ... TO anon. Correr en Supabase → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

revoke execute on function public.bot_buscar_operario(text, text) from public, anon;
revoke execute on function public.bot_buscar_sku(text) from public, anon;
revoke execute on function public.get_area_ventas_overrides() from public, anon;

revoke execute on function public.bot_insertar_comanda_tapas(date, text, text, text, integer, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.bot_insertar_empaque(date, text, text, text, integer, text, text) from public, anon, authenticated;
revoke execute on function public.bot_insertar_flameado(date, text, text, text, text, integer, integer) from public, anon, authenticated;
revoke execute on function public.bot_insertar_tiro(date, text, text, integer, text, integer, text, text) from public, anon, authenticated;

-- El bot (api/whatsapp.js) entra como service_role: se asegura su acceso explícitamente
grant execute on function public.bot_buscar_operario(text, text) to service_role;
grant execute on function public.bot_buscar_sku(text) to service_role;
grant execute on function public.bot_insertar_comanda_tapas(date, text, text, text, integer, text, text, text, text) to service_role;
grant execute on function public.bot_insertar_empaque(date, text, text, text, integer, text, text) to service_role;
grant execute on function public.bot_insertar_flameado(date, text, text, text, text, integer, integer) to service_role;
grant execute on function public.bot_insertar_tiro(date, text, text, integer, text, integer, text, text) to service_role;
grant execute on function public.get_area_ventas_overrides() to authenticated, service_role;
-- comandas.html (master, con sesión) usa estas dos: authenticated las tenía solo vía PUBLIC, hay que darlas explícitas
grant execute on function public.bot_buscar_operario(text, text) to authenticated;
grant execute on function public.bot_buscar_sku(text) to authenticated;

alter function public.fn_updated_at() set search_path = public;
alter function public.fn_historial_estado() set search_path = public;
alter function public.fn_codigo_solicitud() set search_path = public;
alter function public.set_actualizado_en() set search_path = public;
alter function public.set_updated_at_mejoras() set search_path = public;
alter function public.descontar_inventario(text, numeric) set search_path = public;
alter function public.aumentar_inventario(text, numeric) set search_path = public;
alter function public.get_area_ventas_overrides() set search_path = public;

alter view public.v_capacidad_hoy set (security_invoker = true);
alter view public.v_solicitudes set (security_invoker = true);
