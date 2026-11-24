-- Caso especial por ficha (nov/2026): el stock de producto terminado del SKU NO sirve para esta ficha
-- (ej. T-197: 900 und que llevan un liner especial, el stock existente es del producto normal).
-- Con la marca encendida, Tapas deja de decir "el stock cubre el saldo", quita la transparencia y trata la ficha
-- como "producir todo". Master la enciende/apaga desde la ventana de la ficha (tapas.html).
alter table public.solicitudes add column if not exists stock_no_aplica boolean not null default false;
comment on column public.solicitudes.stock_no_aplica is 'Caso especial: el stock de producto terminado del SKU no sirve para esta ficha (ej. lleva un liner especial).';
update public.solicitudes set stock_no_aplica = true where codigo = 'T-197' and area = 'tapas';
