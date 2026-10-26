Fotos de máquinas para las fichas de la pestaña 🏠 Inicio de produccion.html.

El nombre del archivo sale de la tabla `maquinas` (columna `foto`; si está vacía, `maq{id}`):
- Sopladoras simples (#1-#5) e INY-sopladoras (#7, #10): maq1.png … maq5.png, maq7.png, maq10.png
- Sopladoras dobles: UNA foto por máquina física, la comparten E1 y E2:
  maq6.png (#6E1 y #6E2), maq8.png (#8E1 y #8E2), maq9.png (#9E1 y #9E2)
- Inyectoras: maq21.png (220), maq22.png (200 Vieja), maq23.png (200 Nueva), maq24.png (150),
  maq25.png (120 Vieja), maq26.png (120 Nueva), maq27.png (90)

Requisitos:
- Formato PNG con fondo transparente (JPEG no soporta transparencia)
- Fondo eliminado, solo la máquina visible

Al soltar el archivo con el nombre correcto en esta carpeta, aparece automáticamente
en la ficha correspondiente — no requiere ningún cambio de código.
