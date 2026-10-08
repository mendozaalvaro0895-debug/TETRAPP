-- ════════════════════════════════════════════════════════════════
-- TETRAPP — personal.plaza_vacante (plazas vacantes visibles en Gestión)
--
-- Al dar de baja a alguien, gestion.html → Personal → Datos generales
-- ofrece "Dejar la plaza vacante": la ficha de baja queda con
-- plaza_vacante = true y, en el listado "Solo activos", se muestra
-- como una fila anónima "VACANTE" (rol/proceso, turno y área de la
-- persona que se fue, sin nombre ni datos personales) para ver de un
-- vistazo qué espacios hay que cubrir. Clic en la fila = cubrirla con
-- una persona nueva (la vacante se cierra sola al guardar); "✕ cerrar"
-- = la plaza ya no se necesita.
--
-- Es una marca EXPLÍCITA a propósito: `personal` ya tiene decenas de
-- fichas de baja históricas (Alida, Anderson, Fredy…) que NO deben
-- aparecer como vacantes.
--
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

alter table public.personal add column if not exists plaza_vacante boolean not null default false;

-- Lesly Yomara Rojas (Serigrafía, código t-18) — dada de baja en oct/2026,
-- su plaza se queda vacante. `activo = false` protege de marcar a alguien activo.
update public.personal set plaza_vacante = true
where codigo = 't-18' and activo = false;

-- Verificación
select nombre, codigo, area, proceso_hab, activo, plaza_vacante
from public.personal
where plaza_vacante = true;
