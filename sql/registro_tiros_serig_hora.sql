-- Agregar campo hora a registro_tiros_serig
-- Correr en Supabase Dashboard → SQL Editor

ALTER TABLE public.registro_tiros_serig
  ADD COLUMN IF NOT EXISTS hora TIME;

-- Verificar resultado
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'registro_tiros_serig'
ORDER BY ordinal_position;
