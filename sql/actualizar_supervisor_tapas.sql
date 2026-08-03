-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Actualizar supervisora de Tapas: Heidy → Yenifer
-- Correr SOLO UNA de las dos opciones en Supabase Dashboard → SQL Editor
-- (no correr ambas — son alternativas, no pasos secuenciales)
-- ════════════════════════════════════════════════════════════════

-- ── OPCIÓN A — Renombrar el mismo puesto (mismo código T0) ────────
-- Usar si Heidy ya no está en el puesto y Yenifer toma exactamente
-- su mismo lugar (más simple, no rompe historial de comandas viejas
-- que reference supervisor_id='T0').

update public.personal
set nombre = 'Yenifer'          -- ← edita aquí el nombre completo si quieres
where area = 'tapas' and codigo = 'T0';


-- ── OPCIÓN B — Nueva fila para Yenifer, desactivar a Heidy ────────
-- Usar si prefieres conservar el historial de Heidy tal cual estaba
-- y dar de alta a Yenifer como un registro nuevo e independiente.

-- 1) Desactivar a Heidy (deja de aparecer como supervisora activa)
update public.personal
set activo = false
where area = 'tapas' and codigo = 'T0';

-- 2) Alta de Yenifer como supervisora activa
insert into public.personal (codigo, nombre, iniciales, area, rol, activo, color_hex)
values (
  'T0B',            -- ← código único, edítalo si ya existe
  'Yenifer',        -- ← nombre completo
  'YE',             -- ← iniciales para el avatar
  'tapas',
  'supervisor',
  true,
  '#1A6B5B'         -- ← color del avatar (hex), opcional
);


-- ── Verificación (correr después de cualquiera de las 2 opciones) ─
select codigo, nombre, rol, area, activo
from public.personal
where area = 'tapas' and rol = 'supervisor'
order by activo desc, codigo;
