-- ════════════════════════════════════════════════════════════
-- Paros de máquina · Serigrafía
-- Registra paros y reinicios durante el día por línea, para poder
-- calcular las horas efectivas (turno − tiempo detenido).
-- Motivo EMPAQUE guarda además el envase empacado y la cantidad.
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════

create table if not exists public.paros_serig (
  id               uuid primary key default gen_random_uuid(),
  fecha            date not null default current_date,
  linea_id         integer not null,
  area             text not null default 'serig',
  motivo           text not null,
  hora_inicio      time not null,
  hora_fin         time,                 -- null mientras el paro está en curso
  minutos          integer,              -- se calcula al terminar
  operador_codigo  text,
  operador_nombre  text,
  empaque_sku      text,                 -- solo motivo EMPAQUE
  empaque_desc     text,
  empaque_cantidad integer,
  nota             text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ── RLS ───────────────────────────────────────────────────────
alter table public.paros_serig enable row level security;

-- Lectura: cualquiera con perfil (master/visor/operativo_serig)
drop policy if exists paros_lectura on public.paros_serig;
create policy paros_lectura on public.paros_serig
  for select to authenticated using (public.rol_actual() is not null);

-- Insert: operarios de serigrafía y master
drop policy if exists paros_insert on public.paros_serig;
create policy paros_insert on public.paros_serig
  for insert to authenticated
  with check (public.rol_actual() = 'operativo_serig' or public.es_master());

-- Update: operarios de serigrafía (cerrar/editar su paro) y master
drop policy if exists paros_update on public.paros_serig;
create policy paros_update on public.paros_serig
  for update to authenticated
  using (public.rol_actual() = 'operativo_serig' or public.es_master())
  with check (public.rol_actual() = 'operativo_serig' or public.es_master());

-- Delete: operarios de serigrafía (corregir un paro mal iniciado) y master
drop policy if exists paros_delete on public.paros_serig;
create policy paros_delete on public.paros_serig
  for delete to authenticated
  using (public.rol_actual() = 'operativo_serig' or public.es_master());

-- ── GRANT base ────────────────────────────────────────────────
revoke all on public.paros_serig from anon;
grant select, insert, update, delete on public.paros_serig to authenticated;

-- ── Realtime (para que Productividad lo vea en vivo) ──────────
do $$
begin
  begin
    alter publication supabase_realtime add table public.paros_serig;
  exception when duplicate_object then null;
  end;
end $$;

-- ── Verificar ─────────────────────────────────────────────────
select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'paros_serig'
order by cmd, policyname;
