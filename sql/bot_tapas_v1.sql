-- ═══════════════════════════════════════════════════════════════
-- TETRAPP — Bot WhatsApp: ampliación a Tapas
-- Correr en Supabase Dashboard → SQL Editor. Requiere que ya exista
-- bot_buscar_sku (sql/bot_buscar_sku_v2.sql o bot_sku_palabras_clave_v1.sql)
-- y las tablas comandas/comanda_tareas (registro-tapas.html ya las usa).
--
-- Qué hace:
--   1. bot_buscar_operario — busca en `personal` (area='tapas') por
--      nombre o código, mismo criterio de tildes/plural que bot_buscar_sku.
--   2. bot_insertar_comanda_tapas — crea una comanda (cabecera) + su
--      única tarea, igual patrón que usa registro-tapas.html al
--      guardar (correlativo CMD-### lo asigna el trigger ya existente
--      trg_correlativo_comanda; supervisor se toma en vivo de
--      `personal`, nunca hardcodeado; capacidad_hora/horas_efectivas
--      se calculan con la misma tabla de metas de CLAUDE.md).
--   Un mensaje de WhatsApp = una comanda nueva con 1 tarea — comandas.html
--   ya trata cada comanda como tarjeta independiente, no asume "una
--   comanda por operario por día", así que esto no rompe el flujo normal.
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Buscar operario por nombre o código ────────────────────
create or replace function public.bot_buscar_operario(p_texto text, p_area text default 'tapas')
returns table(codigo text, nombre text, hits int)
language sql
stable
security definer
set search_path = public
as $$
  with toks as (
    select tok
    from unnest(string_to_array(
      lower(translate(trim(p_texto), 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')),
      ' '
    )) as tok
    where length(tok) >= 2
  ),
  per as (
    select
      p.codigo,
      p.nombre,
      lower(translate(coalesce(p.nombre,'') || ' ' || coalesce(p.codigo,''),
        'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')) as texto_norm
    from personal p
    where p.area = p_area and p.activo = true
  )
  select
    per.codigo,
    per.nombre,
    (select count(*)::int from toks t where per.texto_norm like '%' || t.tok || '%') as hits
  from per
  where trim(coalesce(p_texto, '')) <> ''
  order by hits desc, length(per.nombre) asc
  limit 5;
$$;

grant execute on function public.bot_buscar_operario(text, text) to anon;

-- ── 2. Insertar comanda + tarea de Tapas ──────────────────────
create or replace function public.bot_insertar_comanda_tapas(
  p_fecha            date,
  p_operario_codigo  text,
  p_operario_nombre  text,
  p_proceso          text,
  p_cantidad         int,
  p_tapa_desc        text default '',
  p_tapa_sku         text default '',
  p_metodo           text default 'manual',
  p_hora             text default ''
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sup_codigo   text;
  v_sup_nombre   text;
  v_proc_norm    text;
  v_cap          int;
  v_horas_ef     numeric;
  v_comanda_id   comandas.id%type;
  v_correlativo  comandas.correlativo%type;
begin
  select codigo, nombre into v_sup_codigo, v_sup_nombre
  from personal
  where area = 'tapas' and rol = 'supervisor' and activo = true
  limit 1;

  v_proc_norm := regexp_replace(
    lower(translate(coalesce(p_proceso, ''), 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN')),
    '[^a-z]', '', 'g'
  );

  -- Misma tabla de metas que CLAUDE.md § Metas de productividad
  if p_metodo = 'maquina_liner' or p_metodo = 'maquina_armado' then
    v_cap := 2500;
  elsif v_proc_norm = 'encajado' then
    v_cap := 3000;
  elsif v_proc_norm in ('armado', 'liner', 'banda', 'flameado', 'impresion') then
    v_cap := 1500;
  else
    v_cap := 1200;
  end if;

  v_horas_ef := case when p_cantidad > 0 then round(p_cantidad::numeric / v_cap, 2) else 0 end;

  insert into comandas(
    fecha, operario_id, operario_nombre, supervisor_id, supervisor_nombre,
    hora_inicio, hora_cierre, total_unidades, observaciones
  )
  values (
    p_fecha, coalesce(p_operario_codigo, ''), coalesce(p_operario_nombre, ''),
    v_sup_codigo, v_sup_nombre,
    nullif(p_hora, ''), nullif(p_hora, ''), p_cantidad, 'Registrado vía WhatsApp'
  )
  returning id, correlativo into v_comanda_id, v_correlativo;

  insert into comanda_tareas(
    comanda_id, orden, proceso, tapa_desc, tapa_sku,
    cantidad, metodo, capacidad_hora, horas_efectivas,
    unidades_completadas, estado
  )
  values (
    v_comanda_id, 1, p_proceso, coalesce(p_tapa_desc, ''), coalesce(p_tapa_sku, ''),
    p_cantidad, coalesce(nullif(p_metodo, ''), 'manual'), v_cap, v_horas_ef,
    p_cantidad, 'Terminada'
  );

  return v_correlativo;
end $$;

grant execute on function public.bot_insertar_comanda_tapas(
  date, text, text, text, int, text, text, text, text
) to anon;

notify pgrst, 'reload schema';

-- Verificación:
select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('bot_buscar_operario', 'bot_insertar_comanda_tapas');
