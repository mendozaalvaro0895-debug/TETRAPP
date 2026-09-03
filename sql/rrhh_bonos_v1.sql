-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Sueldos y Bonos del personal
--
-- Registro MANUAL mes a mes (o día a día para Impresión) de si una
-- persona de la línea de Serigrafía cumplió su meta de bono:
--   - Impresión: Q750/día por 10,000 tiros
--   - Flameado:  Q350/mes por 10,000 unidades/día + 4 bolsas de
--                empaque/día (confirmadas por boleta firmada de la
--                supervisora de empaque)
--   - Recepción: Q350/mes, pierde el derecho si empaque reporta
--                +2% de merma por mala impresión/tinta corrida
--
-- Por ahora NO se calcula solo desde registro_tiros_serig ni desde
-- ninguna tabla de merma — es un registro de la DECISIÓN ya tomada,
-- con los números de respaldo como referencia. Automatizarlo contra
-- los datos reales de tiros/merma queda como mejora futura.
--
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.rrhh_bonos (
  id             serial primary key,
  personal_id    uuid references public.personal(id) on delete set null,
  periodo        text not null,  -- 'YYYY-MM' (mensual) o 'YYYY-MM-DD' (diario, ej. Impresión)
  rol_linea      text not null check (rol_linea in ('impresion','flameado','recepcion','otro')),
  meta_cumplida  boolean not null default false,
  monto_bono     numeric,
  tiros_unidades numeric,   -- tiros (Impresión) o unidades (Flameado) del período
  bolsas_empaque smallint,  -- solo Flameado
  merma_pct      numeric,   -- solo Recepción
  supervisor     text,
  comentario     text,
  created_at     timestamptz not null default now()
);

create index if not exists idx_bonos_personal on public.rrhh_bonos(personal_id);
create index if not exists idx_bonos_periodo  on public.rrhh_bonos(periodo desc);

-- RLS — master-only (mismo patrón que el resto de tablas rrhh_*)
alter table public.rrhh_bonos enable row level security;

drop policy if exists "bonos_master_todo" on public.rrhh_bonos;
create policy "bonos_master_todo" on public.rrhh_bonos
  for all to authenticated
  using (public.es_master())
  with check (public.es_master());

revoke all on public.rrhh_bonos from anon;
grant select, insert, update, delete on public.rrhh_bonos to authenticated;
grant usage, select on sequence public.rrhh_bonos_id_seq to authenticated;

notify pgrst, 'reload schema';

-- Verificación
select tablename, rowsecurity from pg_tables
where schemaname = 'public' and tablename = 'rrhh_bonos';

select count(*) as filas_iniciales from public.rrhh_bonos;
