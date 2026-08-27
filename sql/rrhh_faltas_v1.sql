-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Faltas de Personal (alerta hasta justificar)
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. TABLA rrhh_faltas
-- ─────────────────────────────────────────────────────────────
create table if not exists public.rrhh_faltas (
  id                     serial primary key,
  personal_id            uuid references public.personal(id) on delete set null,
  fecha                  date not null default current_date,
  notas                  text,
  justificacion_texto    text,
  justificacion_foto_url text,
  created_at             timestamptz not null default now()
);

create index if not exists idx_faltas_personal on public.rrhh_faltas(personal_id);
create index if not exists idx_faltas_fecha    on public.rrhh_faltas(fecha desc);

-- ─────────────────────────────────────────────────────────────
-- 2. RLS — master-only (dato sensible de RRHH, mismo patrón que
--    rrhh_permisos / rrhh_incidentes)
-- ─────────────────────────────────────────────────────────────
alter table public.rrhh_faltas enable row level security;

drop policy if exists "faltas_master_todo" on public.rrhh_faltas;
create policy "faltas_master_todo" on public.rrhh_faltas
  for all to authenticated
  using (public.es_master())
  with check (public.es_master());

revoke all on public.rrhh_faltas from anon;
grant select, insert, update, delete on public.rrhh_faltas to authenticated;
grant usage, select on sequence public.rrhh_faltas_id_seq to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Bucket de Storage 'justificaciones' (para foto de justificación)
--    Crear MANUALMENTE en Dashboard → Storage → New bucket
--    Nombre: justificaciones · Public bucket: SÍ
--    (no se puede crear por SQL/API con la key publishable — igual
--    que el bucket 'envases' del recetario)
-- ─────────────────────────────────────────────────────────────

drop policy if exists "justificaciones: autenticados pueden subir" on storage.objects;
create policy "justificaciones: autenticados pueden subir"
on storage.objects for insert to authenticated
with check (bucket_id = 'justificaciones');

drop policy if exists "justificaciones: autenticados pueden actualizar" on storage.objects;
create policy "justificaciones: autenticados pueden actualizar"
on storage.objects for update to authenticated
using (bucket_id = 'justificaciones');

drop policy if exists "justificaciones: autenticados pueden borrar" on storage.objects;
create policy "justificaciones: autenticados pueden borrar"
on storage.objects for delete to authenticated
using (bucket_id = 'justificaciones');

-- ─────────────────────────────────────────────────────────────
-- 4. Refrescar caché PostgREST
-- ─────────────────────────────────────────────────────────────
notify pgrst, 'reload schema';

-- ─────────────────────────────────────────────────────────────
-- 5. Verificación
-- ─────────────────────────────────────────────────────────────
select tablename, rowsecurity from pg_tables
where schemaname = 'public' and tablename = 'rrhh_faltas';

select count(*) as filas_iniciales from public.rrhh_faltas;
