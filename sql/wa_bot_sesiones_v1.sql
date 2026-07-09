-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Bot de WhatsApp (n8n) · Estado de conversación v1.0
-- Correr en Supabase Dashboard → SQL Editor
--
-- Guarda en qué paso del menú va cada operario mientras chatea con
-- el bot (línea, momento, envase, color, diseño ya elegidos), para
-- que n8n sepa qué preguntar a continuación en cada mensaje entrante.
-- Una fila por número de teléfono; se limpia (borra) al confirmar
-- el registro o si expira por inactividad.
-- ════════════════════════════════════════════════════════════════

create table if not exists public.wa_bot_sesiones (
  telefono        text primary key,          -- número de WhatsApp del operario (con código de país)
  operador_codigo text,                       -- personal.codigo, una vez identificado el número
  operador_nombre text,
  paso            text not null default 'menu', -- menu | linea | momento | envase | color | diseno | cantidad
  linea_id        integer,
  momento         text,
  envase_tipo     text,
  envase_color    text,
  diseno_sku      text,
  diseno_desc     text,
  filtro_texto    text,                       -- última palabra clave usada para buscar diseño
  area            text not null default 'serig',
  updated_at      timestamptz not null default now()
);

alter table public.wa_bot_sesiones enable row level security;

-- Esta tabla solo la usa el backend de n8n (via service_role key, que
-- ignora RLS por diseño) — no necesita política para 'authenticated'
-- ni 'anon'. Se deja RLS activado igual, sin políticas, para que quede
-- completamente cerrada a cualquier acceso desde el navegador.

-- ── Mapeo teléfono → operario ─────────────────────────────────────
-- Necesitas una forma de saber a qué operario corresponde cada número.
-- La opción más simple: agregar una columna de teléfono a personal.
alter table public.personal add column if not exists telefono text;

-- Verificación:
select * from public.wa_bot_sesiones limit 1;
