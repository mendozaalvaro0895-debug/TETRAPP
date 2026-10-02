-- Tiempo de selección de rechazos de Serigrafía, en DÍAS (admite medio día: 0.5).
-- La columna vieja tiempo_min (minutos) se queda intacta: la sigue usando Tapas
-- y conserva los registros anteriores de Serigrafía.
-- ⚠️ Correr ANTES de desplegar el cambio de serigrafia.html: al guardar un rechazo
-- el código envía tiempo_dias y fallaría si la columna todavía no existe.
alter table public.rechazos add column if not exists tiempo_dias numeric(5,1);
