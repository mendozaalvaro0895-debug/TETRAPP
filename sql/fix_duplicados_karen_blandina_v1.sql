-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Fix puntual: personal duplicado (Karen Hernández / Blandina Solares)
--
-- `personal.codigo` es UNIQUE, así que esto NO era un problema de UI —
-- eran dos filas de verdad por persona (createdas 2026-09-16 vs
-- 2026-09-18). Probablemente se crearon sin querer al asignar un
-- locker vacío desde Gestión → Lockers → "+ Nueva persona" en vez de
-- encontrar a la persona ya existente con el buscador.
--
-- Blandina Solares:
--   MANTENER   e5639f0a-3354-4a7f-a8e2-838947787c38  S-16  area=serig (su área real, proceso_hab=Empaque)
--   DESACTIVAR 185d8827-e5ff-4503-a01d-03c602bd75ac  T-20  area=tapas (duplicado) — tenía Locker L-13,
--              que SÍ es real → se traslada a su ficha correcta (S-16) antes de desactivar la duplicada.
-- Karen Hernández:
--   MANTENER   813aeb90-2c9b-4190-abf8-7b7776a39baa  S-17  area=tapas (su área real, Locker L-17)
--   DESACTIVAR 0da84c1a-8ff6-459a-b938-c22282bccc8b  T-17  area=serig (duplicado, "KAREN MARIA HERNANDEZ",
--              sin locker ni rol asignado — nada que trasladar)
--
-- Se DESACTIVA (activo=false), NO se borra: si quedó algo de asistencia/
-- falta/capacitación/bono ligado por error a la fila duplicada, se
-- conserva para revisar después en vez de perderse. Al desactivarla,
-- gestion.html deja de contarla en "solo activos" y su locker (si
-- tenía) queda libre automáticamente.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

-- Blandina: trasladar L-13 a su ficha real antes de desactivar la duplicada
update public.personal set locker = 'L-13'
where id = 'e5639f0a-3354-4a7f-a8e2-838947787c38'; -- Blandina Solares, S-16, área correcta (serig)

update public.personal set activo = false, locker = null
where id = '185d8827-e5ff-4503-a01d-03c602bd75ac'; -- Blandina Solares, T-20, duplicado en Tapas

-- Karen: la duplicada no tiene locker ni rol, solo desactivar
update public.personal set activo = false
where id = '0da84c1a-8ff6-459a-b938-c22282bccc8b'; -- Karen Hernández, T-17, duplicado en Serigrafía

-- Verificación
select id, nombre, codigo, area, activo, locker, proceso_hab, mtx_rol
from public.personal
where id in (
  'e5639f0a-3354-4a7f-a8e2-838947787c38',
  '185d8827-e5ff-4503-a01d-03c602bd75ac',
  '813aeb90-2c9b-4190-abf8-7b7776a39baa',
  '0da84c1a-8ff6-459a-b938-c22282bccc8b'
)
order by nombre, area;
