-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Días feriados (casilla gris en Asistencia Mensual)
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. TABLA dias_feriados
-- ─────────────────────────────────────────────────────────────
create table if not exists public.dias_feriados (
  fecha        date primary key,
  descripcion  text,
  created_at   timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────
-- 2. RLS — lectura: cualquier usuario autenticado con perfil
--    (igual que mejoras_planta) · escritura: solo master
-- ─────────────────────────────────────────────────────────────
alter table public.dias_feriados enable row level security;

drop policy if exists "feriados_lectura"       on public.dias_feriados;
drop policy if exists "feriados_insert_master" on public.dias_feriados;
drop policy if exists "feriados_update_master" on public.dias_feriados;
drop policy if exists "feriados_delete_master" on public.dias_feriados;

create policy "feriados_lectura" on public.dias_feriados
  for select to authenticated
  using (public.rol_actual() is not null);

create policy "feriados_insert_master" on public.dias_feriados
  for insert to authenticated
  with check (public.es_master());

create policy "feriados_update_master" on public.dias_feriados
  for update to authenticated
  using (public.es_master()) with check (public.es_master());

create policy "feriados_delete_master" on public.dias_feriados
  for delete to authenticated
  using (public.es_master());

revoke all on public.dias_feriados from anon;
grant select, insert, update, delete on public.dias_feriados to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Marcar el 15 de agosto de 2026 como feriado (motivo del ajuste)
-- ─────────────────────────────────────────────────────────────
insert into public.dias_feriados (fecha, descripcion)
values ('2026-08-15', 'Feriado')
on conflict (fecha) do nothing;

-- ─────────────────────────────────────────────────────────────
-- 4. Limpieza puntual del 15-ago-2026 — lo que ya se generó mal
--    antes de que existiera el tipo de día "feriado"
-- ─────────────────────────────────────────────────────────────

-- 4a. Faltas auto-generadas ese día (Serigrafía) — se borran sin importar
--     si ya estaban justificadas, porque nunca debieron existir
delete from public.rrhh_faltas
where fecha = '2026-08-15' and origen = 'asistencia_serig';

-- 4b. Registro de asistencia 'ausente' ese día (Serigrafía) — se limpia
--     para que la celda quede sin registro y la vea gris de ahora en más
delete from public.asistencia_diaria
where fecha = '2026-08-15' and area = 'serig' and estado = 'ausente';

-- ─────────────────────────────────────────────────────────────
-- 5. Refrescar caché PostgREST
-- ─────────────────────────────────────────────────────────────
notify pgrst, 'reload schema';

-- ─────────────────────────────────────────────────────────────
-- 6. Verificación
-- ─────────────────────────────────────────────────────────────
select * from public.dias_feriados order by fecha;
