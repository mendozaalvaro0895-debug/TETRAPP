-- Agrega 'parcial' a los valores permitidos en solicitudes.estado
-- Correr en: Supabase Dashboard → SQL Editor

ALTER TABLE solicitudes DROP CONSTRAINT solicitudes_estado_check;
ALTER TABLE solicitudes ADD CONSTRAINT solicitudes_estado_check
  CHECK (estado IN ('nueva', 'programada', 'proceso', 'parcial', 'lista'));
