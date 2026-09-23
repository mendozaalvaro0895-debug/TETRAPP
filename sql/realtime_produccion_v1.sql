-- ════════════════════════════════════════════════════════════
-- Realtime · Producción
-- Habilita el refresco EN VIVO de la pestaña Inicio (fichas por máquina, en
-- las 3 vistas Día/Semana/Mes) y de "Últimos turnos cargados" en Ingreso:
-- agrega produccion_diaria a la publicación supabase_realtime para que
-- produccion.html reciba los cambios (INSERT/UPDATE/DELETE) sin recargar,
-- sin importar desde qué usuario o equipo se hayan hecho.
-- Mismo patrón ya usado en sql/realtime_serig.sql. Correr en Supabase
-- Dashboard → SQL Editor. Idempotente.
-- ════════════════════════════════════════════════════════════

do $$
begin
  begin
    alter publication supabase_realtime add table public.produccion_diaria;
  exception when duplicate_object then null; -- ya estaba agregada
  end;
end $$;

-- Verificar qué tablas están publicadas para realtime:
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by tablename;
