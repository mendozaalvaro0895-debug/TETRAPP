-- ════════════════════════════════════════════════════════════
-- TETRAPP — Número de OC en las solicitudes de Serigrafía v1.0
--
-- serigrafia.html → "Nueva solicitud": para pedidos de DAROSA el
-- Número de OC es obligatorio. Se guarda en solicitudes.numero_oc.
--
-- ⚠️ Correr ANTES de usar el campo: sin esta columna, guardar un
-- pedido de DAROSA falla con el aviso "Falta correr
-- sql/solicitudes_numero_oc_v1.sql". Los demás clientes no se afectan.
-- Idempotente: se puede correr varias veces.
-- ════════════════════════════════════════════════════════════
alter table public.solicitudes
  add column if not exists numero_oc text;
