-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Excepciones puntuales: pedidos que se quedan congelados
-- en JULIO y NO se trasladan a agosto (se creará un pedido nuevo
-- aparte para agosto). Correr en Supabase Dashboard → SQL Editor.
--
-- Si el cierre automático de julio ya corrió y ya trasladó alguno de
-- estos pedidos a agosto (periodo_efectivo='2026-08'), este UPDATE lo
-- revierte. Si no se había trasladado, es un no-op seguro.
-- No borra ni duplica nada — solo reasigna su período efectivo.
-- ════════════════════════════════════════════════════════════════

update public.solicitudes
set periodo_efectivo = null
where codigo in ('S-015', 'S-105') and area = 'serig';

-- Verificación
select codigo, cliente_nombre, estado, periodo_efectivo, created_at
from public.solicitudes
where codigo in ('S-015', 'S-105') and area = 'serig';
