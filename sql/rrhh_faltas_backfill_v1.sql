-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Backfill histórico: ausencias ya marcadas en la
-- Asistencia Mensual de Serigrafía → rrhh_faltas
--
-- La sincronización automática (toggleAsistCell → rrhh_faltas) solo
-- dispara HACIA ADELANTE, sobre clics nuevos en la grilla. Todo lo que
-- ya estaba marcado 'ausente' en asistencia_diaria ANTES de que esa
-- sincronización existiera se queda afuera — este script lo trae una
-- sola vez. Es idempotente (se puede correr varias veces sin duplicar).
--
-- Requiere que sql/rrhh_faltas_v1.sql (con la columna `origen`) ya
-- haya corrido. Correr en Supabase Dashboard → SQL Editor.
-- ════════════════════════════════════════════════════════════════

insert into public.rrhh_faltas (personal_id, fecha, origen, notas)
select
  p.id,
  a.fecha,
  'asistencia_serig',
  'Falta detectada automáticamente desde Asistencia Mensual (Serigrafía) — backfill histórico'
from public.asistencia_diaria a
join public.personal p
  on p.codigo = a.operador_codigo and p.area = 'serig'
where a.estado = 'ausente'
  and a.area = 'serig'
  and not exists (
    select 1 from public.rrhh_faltas f
    where f.personal_id = p.id
      and f.fecha = a.fecha
      and f.origen = 'asistencia_serig'
  );

-- ─────────────────────────────────────────────────────────────
-- Verificación — cuántas faltas quedaron por persona
-- ─────────────────────────────────────────────────────────────
select p.nombre, p.codigo, count(*) as faltas_sin_justificar
from public.rrhh_faltas f
join public.personal p on p.id = f.personal_id
where f.origen = 'asistencia_serig'
  and f.justificacion_texto is null
  and f.justificacion_foto_url is null
group by p.nombre, p.codigo
order by faltas_sin_justificar desc;
