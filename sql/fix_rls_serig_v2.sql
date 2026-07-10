-- ════════════════════════════════════════════════════════════
-- Fix RLS Serigrafía v2 — restaurar política INSERT operativo_serig
-- Problema: seguridad_v1.sql borró TODAS las políticas (sección C)
-- y recreó solo insert_master. La política insert_operativo_serig
-- que existía en operativo_serigrafia_v1.sql quedó eliminada.
-- Resultado: serigrafia@tetrapp.app puede SELECT pero no INSERT.
-- Correr en Supabase Dashboard → SQL Editor
-- ════════════════════════════════════════════════════════════

-- 1. Asegurar que el CHECK de perfiles acepta operativo_serig
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check
  check (rol in ('master','visor','operativo','operativo_serig'));

-- 2. Re-crear política INSERT para operativo_serig
drop policy if exists insert_operativo_serig on public.registro_tiros_serig;
create policy insert_operativo_serig on public.registro_tiros_serig
  for insert to authenticated
  with check (public.rol_actual() = 'operativo_serig');

-- 3. Confirmar que insert_master también existe (seguridad_v1 la crea;
--    si se corrió después de operativo_serigrafia_v1 puede haberla sobrescrito)
drop policy if exists insert_master on public.registro_tiros_serig;
create policy insert_master on public.registro_tiros_serig
  for insert to authenticated with check (public.es_master());

-- 4. GRANT base (sin esto RLS no llega a evaluarse)
grant select, insert, update, delete on public.registro_tiros_serig to authenticated;

-- ── Diagnóstico: ver qué hay en la tabla ─────────────────────
-- (Ejecutar por separado si quieres ver los datos actuales)
select id, fecha, linea_id, operador_nombre, momento, contador, area, created_at
from public.registro_tiros_serig
order by created_at desc
limit 20;

-- ── Verificar políticas vigentes ─────────────────────────────
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'registro_tiros_serig'
order by cmd, policyname;
