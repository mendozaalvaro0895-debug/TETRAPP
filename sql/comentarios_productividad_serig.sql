-- ════════════════════════════════════════════════════════════
-- Comentarios por ficha diaria de Productividad · Serigrafía
-- Permite a master argumentar motivos de baja producción por
-- (fecha, línea): falta de envase flameado, empaque, etc.
-- Correr COMPLETO en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════

-- ── 1. Tabla (única por fecha + línea + área) ─────────────────
create table if not exists public.comentarios_productividad_serig (
  id          uuid primary key default gen_random_uuid(),
  fecha       date not null,
  linea_id    integer not null,
  area        text not null default 'serig',
  comentario  text not null default '',
  autor       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (fecha, linea_id, area)
);

-- ── 2. RLS ────────────────────────────────────────────────────
alter table public.comentarios_productividad_serig enable row level security;

-- Lectura: cualquier usuario con perfil (master/visor)
drop policy if exists coment_lectura on public.comentarios_productividad_serig;
create policy coment_lectura on public.comentarios_productividad_serig
  for select to authenticated using (public.rol_actual() is not null);

-- Escritura (insert/update/delete): solo master
drop policy if exists coment_insert_master on public.comentarios_productividad_serig;
create policy coment_insert_master on public.comentarios_productividad_serig
  for insert to authenticated with check (public.es_master());

drop policy if exists coment_update_master on public.comentarios_productividad_serig;
create policy coment_update_master on public.comentarios_productividad_serig
  for update to authenticated using (public.es_master()) with check (public.es_master());

drop policy if exists coment_delete_master on public.comentarios_productividad_serig;
create policy coment_delete_master on public.comentarios_productividad_serig
  for delete to authenticated using (public.es_master());

-- ── 3. GRANT base ─────────────────────────────────────────────
revoke all on public.comentarios_productividad_serig from anon;
grant select, insert, update, delete on public.comentarios_productividad_serig to authenticated;

-- ── 4. Verificar ──────────────────────────────────────────────
select policyname, cmd, roles
from pg_policies
where schemaname = 'public' and tablename = 'comentarios_productividad_serig'
order by cmd, policyname;
