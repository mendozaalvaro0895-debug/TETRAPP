-- ════════════════════════════════════════════════════════════════
-- TETRAPP — Estado de conversación del bot de WhatsApp v1.0
-- Guarda la sesión pendiente de Álvaro cuando el bot hace
-- una pregunta de aclaración (ej. "¿Cuál es la línea?").
-- Una fila por número de WhatsApp. Se borra al completar el registro.
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.bot_estado (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  whatsapp_from   text UNIQUE NOT NULL,
  estado          jsonb,
  updated_at      timestamptz DEFAULT now()
);

-- El bot usa service_role key (bypasses RLS) pero igual activamos RLS
ALTER TABLE public.bot_estado ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.bot_estado TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bot_estado TO service_role;

DROP POLICY IF EXISTS bs_master ON public.bot_estado;
CREATE POLICY bs_master ON public.bot_estado
  FOR ALL TO authenticated USING (public.es_master()) WITH CHECK (public.es_master());

NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════
-- VERIFICACIÓN:
-- ════════════════════════════════════════════════════════════════
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'bot_estado';
