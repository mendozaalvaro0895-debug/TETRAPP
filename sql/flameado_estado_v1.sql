-- Agrega estado de revisión y auditoría a registro_flameado_serig
-- Ejecutar en Supabase → SQL Editor

ALTER TABLE registro_flameado_serig
  ADD COLUMN IF NOT EXISTS estado TEXT NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente','aprobado','rechazado')),
  ADD COLUMN IF NOT EXISTS revisado_por TEXT;
