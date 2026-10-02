-- Nombre que se muestra en los chips del tablero "Personal y Roles" (serigrafia.html).
-- Vacío (NULL) = se sigue mostrando el primer nombre, como hasta ahora.
-- ⚠️ Correr ANTES de desplegar el cambio de serigrafia.html: al guardar un operario
-- el código envía esta columna y fallaría si todavía no existe.
alter table personal add column if not exists nombre_corto text;
