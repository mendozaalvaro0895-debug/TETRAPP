-- ═══════════════════════════════════════════════════════════════
-- TETRAPP — RPCs del bot WhatsApp (SECURITY DEFINER)
-- Correr en Supabase Dashboard → SQL Editor
--
-- Qué hace:
--   Crea 3 funciones que el bot llama con la clave publishable.
--   SECURITY DEFINER → corren con privilegios del dueño (postgres),
--   saltando RLS sin necesitar la service_role key en Vercel.
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Insertar tiro de impresión ─────────────────────────────
-- Llena TODAS las columnas del formulario real (registro-serigrafia.html
-- línea 1512). Por WhatsApp no hay operador: código vacío ('' — el lector
-- de Productividad lo ignora) y nombre marcado como 'WhatsApp' para trazabilidad.
-- Drop previo por si existe una versión con firma distinta (evita "not unique").
drop function if exists public.bot_insertar_tiro(date, text, text, int, text, int);
drop function if exists public.bot_insertar_tiro(date, text, text, int, text, int, text, text);
create or replace function public.bot_insertar_tiro(
  p_fecha     date,
  p_area      text,
  p_hora      text,
  p_linea_id  int,
  p_momento   text,
  p_contador  int,
  p_diseno    text default '',
  p_sku       text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into registro_tiros_serig(
    fecha, area, hora, linea_id, momento, contador,
    diseno, sku, operador_codigo, operador_nombre
  )
  values (
    p_fecha, p_area, nullif(p_hora, '')::time, p_linea_id, p_momento, p_contador,
    coalesce(p_diseno, ''), coalesce(p_sku, ''), '', 'WhatsApp'
  );
end $$;

-- ── 2. Insertar flameado ──────────────────────────────────────
create or replace function public.bot_insertar_flameado(
  p_fecha       date,
  p_hora        text,
  p_flameador   text,
  p_descripcion text,
  p_sku         text,
  p_cantidad    int,
  p_para_linea  int
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into registro_flameado_serig(fecha, hora, flameador, descripcion, sku, cantidad, para_linea)
  values (p_fecha, p_hora, p_flameador, p_descripcion, p_sku, p_cantidad, p_para_linea);
end $$;

-- ── 3. Insertar empaque ───────────────────────────────────────
create or replace function public.bot_insertar_empaque(
  p_fecha           date,
  p_hora            text,
  p_descripcion     text,
  p_sku             text,
  p_cantidad        int,
  p_operador_codigo text,
  p_area_origen     text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into registro_empaque_serig(fecha, hora, descripcion, sku, cantidad, operador_codigo, area_origen)
  values (p_fecha, p_hora, p_descripcion, p_sku, p_cantidad, p_operador_codigo, p_area_origen);
end $$;

-- ── Dar permiso al rol anon (clave publishable del bot) ───────
-- Firma explícita en tiro por si coexiste otra versión (evita "not unique").
grant execute on function public.bot_insertar_tiro(date, text, text, int, text, int, text, text) to anon;
grant execute on function public.bot_insertar_flameado to anon;
grant execute on function public.bot_insertar_empaque  to anon;

-- Recargar el cache de esquema de PostgREST (para que reconozca los args nuevos)
notify pgrst, 'reload schema';

-- Verificación
select proname, prosecdef
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'bot_insertar%';
