# Plano de planta · Nivel 2 — formato de datos y exportaciones

Archivo: `plano-nivel2.html` (visor/editor 3D aislado, Three.js). Construcción aislada a propósito:
la integración con TETRAPP (inventario por tarima, entradas/salidas/rechazos) es una fase posterior.
Este documento fija el **contrato de datos** para que esa integración no requiera rehacer el plano.

## Sistema de coordenadas
- Unidades: **metros**. Planta de 35 m (x, frente) × 45 m (d, fondo).
- Origen: esquina frontal izquierda. `x` crece hacia la derecha, `d` hacia el fondo.
- En 3D/GLB: `z = -d`, `y` = altura sobre el piso del nivel 2 (el Nivel 1 está en `y = -altoNivel`, 8 m por defecto).
- El plano **no está georreferenciado** (no es WGS84): es un sistema local.

## Exportaciones (panel "Exportar / guardar")
| Botón | Archivo | Uso |
|---|---|---|
| 3D · GLB | `tetrapp-planta-nivel2.glb` | glTF 2.0 binario. Nombres estables y `extras` (código, uso, área, ocupada) en cada tarima/tonel. Solo exporta capas visibles |
| Plano · PNG | `…png` | Vista cenital a 50 px/m, para imprimir |
| Plano · SVG | `…svg` | Vector 2D (frente abajo). Grupos `zonas`, `pasillos`, `paredes`, `tarimas`; atributos `data-codigo`, `data-uso`, `data-area`… |
| GeoJSON · 2D | `…geojson` | FeatureCollection con geometría y propiedades por elemento. Coordenadas locales `[x, d]` |
| Datos · JSON | `…json` | Diseño completo y versionado (`formato: "tetrapp-plano"`, `version: 2`). **Es el que se importa de vuelta** |

La copia de trabajo vive en `localStorage` (clave `tetrapp_plano_n2_v1`) del navegador: **respaldar con JSON**.

**Base de datos (oct/2026):** botón "Guardar versión" del plano inserta una fila en `planos` (`nivel`, `version`, `datos` = JSON v2 + `n1mod` con escala/posición del modelo del Nivel 1, `modelo_path` = GLB en el bucket privado `planos`). Cada guardado es una versión nueva; "Ver versiones" las lista y "Cargar" reemplaza el diseño en pantalla. Solo master escribe. Ver `sql/planos_v1.sql`.

## Identificadores estables (llave para integrar)
Cada elemento tiene `id` numérico único dentro del plano y un `codigo` derivado:
`N2-T<id>` tarima · `N2-O<id>` tonel · `N2-Z<id>` zona · `N2-L<id>` línea/pasillo/puerta/gradas ·
`N2-P<id>` pared · `N2-R<id>` referencia · `N2-C<id>-<n>` zona de cubo · `N2-ZF-<NOMBRE>` zonas fijas del cajón/Bodega.
Para ligar inventario: **la llave es `codigo` (o `id`)**; las coordenadas pueden cambiar si se mueve la tarima.

## Tarimas (`k: "tarima"`)
`{ id, x, d, w, l, rot, carga, uso? }`. Sin `uso` = **Bodega**.
`uso = { tipo, linea?, area? }`. Color por **área**: `serig` verde `#22C55E`, `tapas` amarillo `#FACC15`,
`general` azul `#38BDF8`, `bodega` café `#C9A66B`.

Tipos de uso (`catalogoUsos` en el JSON): `flameo` (rotación alta, líneas 1–4) · `flameado` (entrega Flameo, recoge
Impresión, líneas 1–4) · `merma` (rechazo de Empaque, líneas 1–4) · `entregaspt` · `pendempaque` · `entbodega` ·
`rechazoint` · `tapas` (para flameo) · `mpmolida` · `bolsasrec` · `corrmalo` · `corrbueno`.
Las notas operativas de cada uso están en `notasUso`.

**Producto de la tarima (oct/2026):** herramienta "Asignar producto a una tarima" → `producto: { sku }` en la tarima (solo el SKU; la descripción y la existencia se leen EN VIVO de `inventario` Bodega B2 al abrir el detalle, no se guardan en el plano). En pantalla la tarima muestra solo el SKU; un clic con Mover abre el detalle (SKU, descripción, cantidad en inventario). En GeoJSON la propiedad `sku` sale llena; `cantidad` sigue `null` (la existencia del inventario es global del SKU, no por tarima).

**Campos reservados para la integración** (`cantidad` aún `null`; `sku` ya se llena con el producto asignado):
Pendiente de diseñar (fase 2): tabla `tarimas_mapa` (tarima, sku, cantidad, requi, línea, estado) y capa "Inventario".

## Otros elementos
- Pasillos: `linea` con `tipo` `peatonal` (1.5 m, bordes de 10 cm; color según norma elegida: verde ISO 3864-1 o amarillo ANSI/OSHA)
  o `montacargas` (amarillo, eje discontinuo). Ancho = `w`.
- `gradas` (caída = `altoNivel`), `porton` (puerta, altura `altoPuerta`), `limite` (rojo).
- Zonas: `area` (`espacio`/`producto`/`techo`); nombre `ELEVADOR*` = elevador de carga (hueco + foso + plataforma + pared);
  nombre `PASILLO*` se convierte en pasillo peatonal.
- `recinto` = zona doble (cubo) con línea móvil. `pared` (`estructural`/`media`, altura `h`). `ref` = referencia de diseño.
- `tonel` = tonel de 55 galones (Ø 0.58 m, 0.88 m); sobre una tarima queda apoyado a 0.14 m.
- `mulita` (`N2-M<id>`) = mulita de carga (transpaleta manual): `{ x, d, rot }`, huella 1.55 × 0.60 m (horquillas hacia +x con `rot` 0), alto ~1.3 m con la barra. En GeoJSON/SVG sale como polígono rotado (`tipo: mulita_carga`).
- `rack` (`N2-K<id>`) = estructura metálica de 2 niveles, **un rack = 1 módulo**: **2 tarimas abajo + 2 arriba** (por defecto)
  o **1 abajo + 1 arriba** (rack de 1 tarima): `{ x0, x1, d0, d1, orient, n: 1, bahia, prof }`; `bahia` = 1 o 2 × ancho de tarima
  de largo y 1 de fondo (`tarimas_por_nivel` en GeoJSON); postes en cada módulo;
  primera viga a `cfg.altoRack1` (1.70 m), alto total `cfg.altoRack` (3.4 m). Una hilera = varios racks pegados.
  Las 4 tarimas del rack llevan `rack: <id>`; las de arriba `z` > 0 (elevación = 1ª viga + 0.12 m): en GeoJSON `elevacion`
  y `nivel_rack: true`. Mover o borrar el rack mueve/borra sus tarimas. Una tarima de piso tiene `z` 0 o ausente.
- `cfg`: medidas del nivel (bodega, cajón, zonas del cajón, alturas, norma de pasillos…).

## Señalización (referencia, no norma local confirmada)
Verde = condición segura (ISO 3864-1) · amarillo = precaución (ANSI Z535 / OSHA) · rojo = límite/prohibido.
Bordes de 10 cm (mínimo OSHA y NOM-001-STPS: 5 cm). Tonos aproximados: confirmar con el proveedor de pintura.
Pendiente confirmar con seguridad industrial/Mintrab lo que exige el Acuerdo Gubernativo 229-2014 en Guatemala.

## Compatibilidad
Importar JSON acepta versión 1 y 2 (`cfg` + `items`). Al agregar tipos nuevos se **suman** valores; no se renombran los existentes.
