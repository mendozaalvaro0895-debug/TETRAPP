-- ════════════════════════════════════════════════════════════
-- Realtime · Serigrafía Productividad
-- Habilita el refresco EN VIVO de la pestaña Productividad:
-- agrega las tablas a la publicación supabase_realtime para que
-- serigrafia.html reciba los cambios (INSERT/UPDATE/DELETE) sin recargar.
-- Correr en Supabase Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════

do $$
begin
  begin
    alter publication supabase_realtime add table public.registro_tiros_serig;
  exception when duplicate_object then null; -- ya estaba agregada
  end;
  begin
    alter publication supabase_realtime add table public.comentarios_productividad_serig;
  exception when duplicate_object then null;
  end;
end $$;

-- Verificar qué tablas están publicadas para realtime:
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by tablename;
