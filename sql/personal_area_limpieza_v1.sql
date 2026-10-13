-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Permitir area='limpieza' en personal y en asistencia_diaria
--
-- La hoja "ASISTENCIA DE PLANTA" sumó el área LIMPIEZA (1 colaboradora). Dos CHECK
-- constraints mantenidos a mano la rechazarían:
--   · personal_area_check            → sin esto no se puede dar de alta a la persona en Gestión
--   · asistencia_diaria_area_check   → sin esto la sincronización con el Drive falla al guardar
--                                      la asistencia de esa área
-- Se reemplazan completos (mismo patrón que personal_area_oficina_v1.sql y asistencia_drive_v1.sql).
-- Limpieza no tiene módulo propio en la app: este registro es solo de personal + asistencia.
--
-- Orden: 1) correr este SQL   2) Gestión → Personal → "+ Nueva persona" → Área Limpieza
--        (código sugerido LI-01)   3) Inicio → "Sincronizar ahora": la cruza por nombre sola.
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal drop constraint if exists personal_area_check;
alter table public.personal
  add constraint personal_area_check
  check (area in ('tapas', 'serig', 'produccion', 'molino', 'bodega', 'moldes', 'mantenimiento', 'torno', 'oficina', 'limpieza'));

alter table public.asistencia_diaria drop constraint if exists asistencia_diaria_area_check;
alter table public.asistencia_diaria
  add constraint asistencia_diaria_area_check
  check (area in ('tapas', 'serig', 'produccion', 'bodega', 'mantenimiento', 'torno', 'moldes', 'molino', 'oficina', 'limpieza'));

notify pgrst, 'reload schema';

-- ── Verificación: las dos filas deben incluir 'limpieza' ─────────
select conrelid::regclass as tabla, conname, pg_get_constraintdef(oid) as definicion
from pg_constraint
where conname in ('personal_area_check', 'asistencia_diaria_area_check')
order by conname;
