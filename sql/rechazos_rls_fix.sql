-- ════════════════════════════════════════════════════════════
-- Cierre de hueco de seguridad: activar RLS en la tabla rechazos
-- (creada sin RLS por sql/movimientos_serigrafia_v1.sql)
-- Mismo patron que el resto de tablas del blindaje v1.0
-- (sql/seguridad_v1.sql, seccion D)
-- Ejecutar manualmente en el dashboard de Supabase (SQL Editor)
-- ════════════════════════════════════════════════════════════

alter table public.rechazos enable row level security;

drop policy if exists lectura_con_perfil on public.rechazos;
drop policy if exists insert_master      on public.rechazos;
drop policy if exists update_master      on public.rechazos;
drop policy if exists delete_master      on public.rechazos;

create policy lectura_con_perfil on public.rechazos
  for select to authenticated using (public.rol_actual() is not null);

create policy insert_master on public.rechazos
  for insert to authenticated with check (public.es_master());

create policy update_master on public.rechazos
  for update to authenticated using (public.es_master()) with check (public.es_master());

create policy delete_master on public.rechazos
  for delete to authenticated using (public.es_master());

revoke all on public.rechazos from anon;

-- Verificación: debe mostrar 4 políticas, todas con roles={authenticated}
select tablename, policyname, roles, cmd
from pg_policies where schemaname = 'public' and tablename = 'rechazos';
