# Contexto — Bot Cazador de Info (Central de Ingreso Diario)
> Documento de arranque de sesión. Última actividad: sep/2026. En entrenamiento activo con Álvaro —
> este doc se va llenando línea por línea a medida que él explica cada tipo de documento de SICAF.
> Es la fuente de verdad para el prompt de clasificación que usará el endpoint nuevo (aún no construido).

## Objetivo del proyecto
Álvaro hoy entra manualmente a **SICAF** (ERP de escritorio, conectado a un servidor de oficina por
red local — sin API ni acceso a BD conocido, ver búsqueda web sep/2026 sin resultados técnicos),
saca capturas de pantalla / exporta Excel de los movimientos del día, y digita/reparte cada línea
a mano en el módulo de TETRAPP que corresponda. Eso es lo que consume tiempo — NO la falta de datos.

**Fase 1 (en diseño):** módulo nuevo "Central de Ingreso" en `index.html` — sube capturas/PDFs/Excels
del día → Claude extrae cada línea → Álvaro asigna el área destino (1 clic) → inserta automático en
la tabla de Supabase correspondiente. Elimina la re-digitación manual, NO elimina la captura manual
desde SICAF (sigue sin haber forma automática de sacar los datos de SICAF).

**Fase 2 (futuro):** una vez haya suficientes correcciones de Álvaro acumuladas, sugerir el área
automáticamente en vez de que él la elija siempre desde cero.

**Disparo:** bajo demanda (Álvaro sube cuando quiere, no hay cron — SICAF solo es accesible desde
la red de la oficina). Rutina ideal mencionada: ~7-8am (confirmar requis de ayer + revisar hoy),
~12-2pm (actualizar movimientos), ~5-6pm (cierre del día) — son ventanas manuales, no automáticas.

---

## Tipos de documento de SICAF (uno por sección — se va ampliando)

### 1. REQUI DE INGRESO ("Ingresos")
Ejemplo real: PDF con encabezado "TETRAPLAST, S.A." + dirección, título "Ingresos".

**Layout:**
- Esquina superior derecha: `Fecha:` = fecha en que se generó/descargó ESE documento (NO es la
  fecha de la transacción — es solo metadata de cuándo se sacó el reporte).
- Debajo de esa fecha: `Bodega: NN` — bodega a la que aplica el ingreso.
  - **Bodega 02** = producto terminado
  - **Bodega 07** = materias primas e insumos
- Tabla de encabezado de documento: `Documento | Fecha | Descripción | Sucursal | No. Orden`
  - **Documento**: código tipo `PRI2 498` — el PREFIJO de letras antes del número es el
    identificador de a qué área dirigir la requi (ver tabla de prefijos abajo).
  - **Fecha** (de esta fila): fecha REAL en que la requi se ingresó al sistema — esta sí es la
    fecha de la transacción, distinta de la fecha de descarga de arriba.
  - **Descripción**: texto libre, SIN estándar — varía según quién lo digitó en SICAF. Ejemplos
    vistos: "Sabado 6 dia", "Turno de alex - Sabado 06", "Turno Dia 06 de junio". No confiar en
    esta columna para clasificar automáticamente, es solo referencia humana (día/turno/operador).
  - **Sucursal / No. Orden**: presentes en el encabezado, uso aún no confirmado con Álvaro.
- Tabla de líneas de producto (por documento): `Código | Producto | Fabricante | Cantidad | Costo U. | Valor Total`
- **Confirmado (sep/2026):** un PDF/captura = **un solo Documento**. Los dos totales del pie son
  agregados distintos de ESE mismo documento, no de documentos separados:
  - `Total Documento:` = suma de la columna `Valor Total` (costo)
  - `Total General:` = suma de la columna `Cantidad` (unidades totales) — verificado sumando
    la columna en el ejemplo real (90,935.00 exacto)

**Prefijos de `Documento` conocidos hasta ahora** (confirmados por Álvaro en ⭐; el resto son
hipótesis mías a partir de patrones reales del histórico ene-mar/2026, PENDIENTE que Álvaro confirme):
| Prefijo | Significado | Evidencia |
|---|---|---|
| `PRI` ⭐ | Producción Ingreso | confirmado por Álvaro |
| `PRS` ⭐ | Producción Salida | confirmado por Álvaro. Descripciones reales: "TRASLADO A INCOGUA", "ENTREGADO A INCOGUA", "DESPACHO A INCOGUA", "SALIDA POR MAL[a calidad?]" — INCOGUA aparece como cliente/marca externa recurrente |
| `TMP` ⭐ | Maquila (Tapas o Serigrafía) | confirmado por Álvaro. Campo `Referencia` (última columna) afina el destino: valores vistos `TMP`, `SERI`, `SERIG` |
| `PTI` ⭐ | Producto Terminado Ingreso — PT que entra a bodega, típicamente desde Serigrafía | confirmado por Álvaro — mapea a `serigrafia.html` → "Registrar entrega" (**ya existe en TETRAPP**) |
| `PTS` (hipótesis) | Producto Terminado Salida | ej. "envase bala gris", Referencia="serigrafia" — parece ser el sentido contrario a PTI: envase saliendo de bodega HACIA Serigrafía para imprimir |
| `MPI` (hipótesis) | Materia Prima Ingreso | ej. "CONTRASEÑA 2385", Referencia="ENVIO 1-26" — llegada de un envío/shipment de materia prima de proveedor |
| `MPS` (hipótesis) | Materia Prima Salida | ej. "lunes 5 dia", "turno de dia", "lunes 5 noche" — resina/materia prima saliendo de bodega hacia un turno de producción |
| `DEV` (hipótesis) | Ajuste de inventario / devolución — NO es un movimiento operativo normal | ej. "Ingreso por Ajuste de...", "CAMBIO DIRECTO" — aparece solo en Ingresos, probablemente requiere manejo aparte (¿no se reparte a ningún área, es solo corrección de existencias?) |
| otro  | Álvaro debe confirmar caso por caso — no asumir | — |

**Patrón detectado:** el prefijo parece construirse como `[PR|PT|MP]` + `[I|S]` (Producción/Producto
Terminado/Materia Prima + Ingreso/Salida), con `TMP` y `DEV` como códigos especiales fuera de ese patrón.
PENDIENTE que Álvaro confirme si este patrón es correcto y si hay más raíces (ej. algo con "IN" de insumos).

**Campo `Referencia`** (última columna de la fila de Documento): **CONFIRMADO — es texto libre de
digitación manual**, cada quien lo escribe a su manera al registrar la requi en SICAF, tratando de
anotar el área destino pero SIN estándar. Ej. `TMP` = alguien queriendo decir "Tampografía"; `SERI`
y `Serig` = variantes de alguien escribiendo "Serigrafía"; `PRODUCCION` = tal cual. Es una PISTA útil
pero no una clave fija — no tratarla como enum cerrado, requiere interpretación difusa (fuzzy),
igual que la columna `Descripción`.

**CONFIRMADO — por qué `TMP` = "Tampografía" pero cubre Tapas Y Serigrafía:** cuando se creó SICAF,
la empresa solo trabajaba Tampografía (no existían Armado, Liner ni Serigrafía como procesos
separados) — de ahí el prefijo. Con el tiempo se implementaron esos procesos nuevos y el área de
Serigrafía (con subárea Empaque), pero **en SICAF nunca se crearon prefijos nuevos para ellos** — el
sistema sigue usando `TMP` como cajón único para CUALQUIER movimiento de Tapas o de Serigrafía.
⚠️ Consecuencia práctica: el prefijo `TMP` por sí solo NO alcanza para saber si una línea es de Tapas
(armado/liner) o de Serigrafía (impresión/empaque) — hace falta leer el producto/descripción de esa
línea específica para desambiguar, igual que con el caso mixto Producción/Tapas del documento PRI.

**Clientes/marcas externas detectadas en descripciones de producto:** `INCOGUA`, `SINERGIA` —
**CONFIRMADO — son clientes**, aparecen como parte del nombre de producto ("TAPA 33 SINERGIA",
"POLIETILENO INCOGUA") pero NO afectan a qué área se dirige la línea, es solo descripción. Nota
relacionada: Álvaro confirma que en Facturación existen combinaciones SKU+descripción que NO
existen en `inventario` — variantes por cliente que quedan fuera del catálogo de inventario. Tenerlo
presente cuando se construya el importador de facturación (Fase futura), puede requerir manejo aparte
para SKUs no encontrados en `inventario`.

**⚠️ Inconsistencia que Álvaro notó en el histórico:** el encabezado del reporte dice `Bodega: 02`
pero adentro aparecen movimientos que conceptualmente son de materia prima (típicamente Bodega 07,
`MPI`/`MPS`). Puede ser que el reporte de SICAF no filtre limpiamente por bodega individual, o que
materia prima también se registre contablemente bajo el folio de bodega 02. PENDIENTE — no asumir,
preguntar directo a Álvaro o al soporte de SICAF si hace falta.

**Ejemplo real — PTI (ingreso de producto terminado de Serigrafía):**
```
Documento   Fecha      Descripción     Sucursal
PTI2 909    29/08/26   KONTROL 400

Código   Producto                                          Fabricante   Cantidad  Costo U.  Valor Total
214634   ENVASE OVAL KONTROL 400 ML AZUL SERIGRAFIA         TETRAPLAST   1177.0000  0.7900    929.83
         PIEL SECA
                                                    Total Documento:                           929.83
```
- Un solo producto en el documento (a diferencia del ejemplo PRI, que traía varias líneas mezcladas).
- El nombre del producto incluye "SERIGRAFIA PIEL SECA" como parte de la descripción del acabado/
  color — confirma que Serigrafía en esta empresa también imprime directo sobre envases (no solo tapas).
- Sin campo `Bodega:` visible en esta captura (recortada) — se asume Bodega 02 (producto terminado)
  por tratarse de un ingreso de PT, PENDIENTE confirmar que PTI siempre es Bodega 02.
- PENDIENTE confirmar tabla destino exacta en TETRAPP (hipótesis: `serigrafia.html` → Movimientos →
  Ingresos PT, no confirmado con Álvaro todavía).

⚠️ **Clasificación es POR LÍNEA, no por documento completo.** Ejemplo real: un documento
`PRI2 498` (Bodega 02) trae mezclados productos que son "envases" (fabricados por
Producción/Sopladoras, ej. `ENVA.OVAL...`, `ENVASE LITRO...`) Y productos que son "tapas/bases"
(fabricados por Tapas o Serigrafía vía maquila, ej. `TAPA PRESS TOP...`, `BASE TAPA...`). El
prefijo del documento (PRI/PRS/TMP) NO alcanza por sí solo para saber a qué tabla va cada línea —
hace falta cruzar también con el tipo de producto de esa línea específica.

**Confirmado (sep/2026):**
- `inventario` NO tiene columna de familia/área por SKU — no hay atajo, la clasificación por tipo
  de producto se aprende por nombre/código a base de ejemplos reales, sin apuro ("aunque tome tiempo").
- Los prefijos de `Documento` (más allá de PRI/PRS/TMP) se van descubriendo sobre la marcha, uno
  por uno según aparezcan — no asumir una lista cerrada ni inventar significados.

**Reglas de clasificación por producto (CONFIRMADAS, para desambiguar dentro de un mismo documento):**
- Si el código/descripción del producto contiene **"BASE", "TAPA" o "CONTRATAPA"** → línea es de **Tapas**.
- Si el código/descripción del producto contiene **"Serigrafia" o "Serigrafiado"** → línea es de **Serigrafía**.
  ⚠️ Regla incompleta a propósito: hay envases serigrafiados cuya descripción NO incluye esas
  palabras (solo describen envase+diseño) — esos quedan sin detectar por esta regla y necesitan
  revisión manual. Aceptado así por Álvaro: "con filtrar los que contengan la palabra, ya se hace mucho".
- Orden de aplicación sugerido: evaluar regla de Tapas primero, luego Serigrafía, resto = sin
  clasificar automáticamente (requiere que Álvaro lo asigne a mano en la pantalla de revisión).

**PENDIENTE (se sigue llenando con cada ejemplo nuevo que comparta Álvaro):**
- Prefijos nuevos de `Documento` a medida que aparezcan.
- Mapeo exacto prefijo + bodega + tipo de producto → tabla destino en TETRAPP (se irá llenando
  con ejemplos reales conforme Álvaro los revise en la pantalla de confirmación de Fase 1).

### Histórico masivo — "Salidas de Bodega" / "Ingresos a Bodega" (reporte SICAF por rango de fechas)
SICAF puede exportar un PDF con TODOS los documentos de un rango de fechas seguidos uno tras otro
(Álvaro compartió ene-mar/2026: 13 páginas de salidas + 12 de ingresos). Muy valioso para catálogo
de prefijos con datos reales, pero con limitaciones para extracción automática:

- Extraído con `pdftotext -layout` (Git for Windows trae este binario en
  `mingw64/bin/pdftotext.exe` — no hacía falta instalar poppler aparte).
- **El PDF en sí está bien ordenado** (confirmado por Álvaro viendo una captura real) — el problema
  es que `pdftotext -layout` desalinea código/producto/cantidad al convertir a texto plano (el
  reporte parece generado con cajas de texto posicionadas absolutamente, tipo Crystal Reports, y
  `pdftotext` no reconstruye bien ese orden). La fila de encabezado del Documento
  (Documento/Fecha/Descripción/Referencia) sí sale confiable; el detalle de líneas de producto NO,
  por limitación de la herramienta de extracción, no del documento.
- Conclusión: para el histórico masivo, texto plano solo sirve para catalogar prefijos/referencias
  — para extraer líneas de producto reales hace falta leerlo como imagen con Claude Vision (igual
  que `parse-doc.js` con capturas individuales), no como texto plano.
- **CONFIRMADO (sep/2026):** renderizando la página del PDF como imagen (se instaló PyMuPDF con
  `python -m pip install pymupdf`, ya que `pdftoppm`/poppler no estaba disponible en esta máquina)
  Vision SÍ lee perfecto el detalle línea por línea, incluso con varios documentos en la misma
  página — el problema era 100% la extracción a texto plano, no el documento ni la capacidad de
  Vision. Implicación para Fase 1: el usuario NO necesita mandar screenshot por cada requi
  individual — un PDF completo del día (con varios documentos concatenados, como exporta SICAF)
  también se puede procesar directo.
- **Implicación de arquitectura:** para la Central de Ingreso en producción (Vercel serverless,
  Node.js, no Python), el render de página PDF → imagen debe hacerse **en el navegador con pdf.js**
  antes de enviar al endpoint — mismo patrón ya probado en `produccion.html` ("Ingreso PDF/manual
  (pdf.js)"), evita depender de binarios nativos (poppler/mupdf) en el entorno serverless.
- Archivos originales (equipo de Álvaro, no en el repo):
  `C:\Users\Cuentas\Documents\SALIDAS A BODEGA DEL 01ENE2026 AL 30MAR2026.pdf`
  `C:\Users\Cuentas\Documents\INGRESOS A BODEGA DEL 01ENE2026 AL 30MAR2026.pdf`
- Texto plano extraído (scratchpad de sesión, temporal): `salidas.txt` / `ingresos.txt`

**PENDIENTE decidir con Álvaro:** él pidió "guardarlos en base de datos para futuras consultas".
Aún no se ha creado ninguna tabla nueva ni insertado nada — falta decidir:
  - ¿Tabla nueva de solo-catálogo (prefijo + referencia + fecha + descripción, sin líneas de
    producto todavía), o esperar a tener extracción confiable línea por línea?
  - Como con el resto del proyecto, cualquier tabla nueva se crea con un `sql/*.sql` que Álvaro
    corre manual en el dashboard de Supabase (no hay `exec_sql` con la publishable key).
  - La inserción real necesitaría sesión autenticada de master (browser) o `SUPA_SERVICE_KEY`
    (server-side, como `api/whatsapp.js`) — NO pedirle a Álvaro que pegue esa clave en el chat.

### 2. (pendiente) Excel de inventario Bodega 2 / Bodega 7
Aún no revisado con Álvaro — se documentará cuando comparta un ejemplo.

### 3. (pendiente) Detalle de facturación diaria
Aún no revisado con Álvaro — se documentará cuando comparta un ejemplo.

---

## Mapeo prefijo → destino en TETRAPP (CONFIRMADO por Álvaro, sep/2026)

Tablas existentes relevantes encontradas en el código (para no duplicar lógica de DB):
- `movimientos_materiales` (tapas.html) — genérica: `tipo='salida_bodega'|'entrada_pt'`,
  `num_documento`, `sku_original`, `cantidad`, `observaciones` ("FECHA:YYYY-MM-DD | notas"),
  `solicitud_id` opcional. Insertada vía `abrirModalMov()`/`movRegistrar()`.
- `entregas_serig` (serigrafia.html, "Registrar entregado") — `requi`, `cliente`, `cant`, `fecha`,
  `nota`, `sol_id`, `sol_codigo`, `lineas[]` ({cliente, sku, desc, cant, solId, solCodigo}).
  Insertada vía `guardarEntregadoManual()`.
- `produccion_diaria` (produccion.html) — `fecha`, `turno`, `maquina`, `sku`, `descripcion`,
  `cantidad`, `documento`, `origen`, `operador_codigo`. **Exige turno + máquina + operario por
  fila** (el operario se agregó recientemente para conectar con Capacitaciones en gestion.html) —
  ninguno de estos 3 datos existe en la requi de bodega.

**Mapeo por prefijo:**
- **`PRI`** → **NO se inserta como producción nueva.** Álvaro confirmó: "PRI es lo mismo que lo
  que ingreso como producción diaria" — son las MISMAS unidades que ya se capturan por el flujo
  normal de produccion.html (PDF de turno por máquina). El rol de `PRI` en la Central de Ingreso es
  de **RECONCILIACIÓN**: comparar cantidad por SKU/fecha contra lo que ya existe en
  `produccion_diaria` y marcar diferencias para que Álvaro revise — NO duplicar el insert. Esto
  coincide con la idea original de Álvaro de "confirmar requis registradas" en la rutina de la mañana.
- **`PRS`** → **Ajuste de inventario, no un movimiento de área.** Álvaro: "normalmente son salidas
  de bodega... para ajustar inventarios (por producto identificado como malo ya en bodega, o por
  ajustes varios)". Destino: decrementar `inventario.existencia` del SKU correspondiente (con motivo
  registrado), NO enviar a ningún módulo de área.
- **`DEV`** → mismo tratamiento que `PRS`: ajuste de inventario directo, no reparto por área.
- **`TMP`** (salida) → clasificar la línea primero (Tapas vs Serigrafía, reglas ya definidas) →
  `movimientos_materiales` con `tipo='salida_bodega'`.
- **`PTI`/`PTS`** (ingreso/salida de PT) → clasificar la línea (Tapas vs Serigrafía) →
  si es Tapas: `movimientos_materiales` con `tipo='entrada_pt'` (o `salida_bodega` si es `PTS`);
  si es Serigrafía: `entregas_serig` (ya confirmado con el ejemplo real del prefijo `PTI`).
- **`MPI`/`MPS`** (Materia Prima, Bodega 07) → **requiere módulo nuevo** (ver siguiente sección) —
  Álvaro decidió construir Bodega y Molino como módulos propios ahora, en vez de dejarlos pendientes,
  "ya que al final esta info se va a repartir desde el index diariamente. Aseguremos un destino funcional."

## Módulos nuevos: Bodega y Molino (decisión sep/2026)
Álvaro pidió construirlos YA (Bodega y Molino primero, luego la Central de Ingreso encima), como
destino funcional para MPI/MPS — "al final esta info se va a repartir desde el index diariamente,
aseguremos un destino funcional".

**⚠️ Hallazgo importante — parte de esto YA EXISTE:** `inventario.html` ya tiene columna
`inventario.bodega` (valores `'B2'`/`'B7'`/`'B5'`) + `stock_minimo`, y ya importa Excel de
**Bodega 2** (productos completos), **Bodega 7** (insumos) y **Bodega 5** (rechazos) con alertas de
bajo stock ya construidas (`triggerImport('bodega7', ...)`, `confirmarImportB7()`, ver
`sql/insumos_b7_v1.sql`). **Esto ya cubre la parte de "descargar inventarios de bodega 2 y 7" del
pedido original de Álvaro — NO hay que rehacer existencias, ya están.**

Lo que SÍ falta (el gap real para `bodega.html`):
- Hub propio (Inicio/KPIs) como tienen tapas.html/serigrafia.html — hoy Bodega no tiene página, solo
  vive dentro de inventario.html como un filtro.
- Historial de MOVIMIENTOS (documentos MPI/MPS con fecha/sku/cantidad) — esto es transaccional,
  distinto de la existencia actual que ya trae el import de Excel. Reusar patrón de
  `movimientos_materiales` (tapas.html) en vez de tabla nueva, ya que es la misma forma
  (documento+sku+cantidad+tipo) — evita duplicar lógica de DB.
- Personal + KPIs del área (personal por `area='bodega'` ya existe en tabla `personal`/gestion.html,
  falta la vista embebida en el hub).

**Nota Molino/molido:** todos los códigos ya existen en `inventario`, todo se trabaja por requi.
Lo molido normalmente NO entra a `inventario` (se muele y se mezcla ahí mismo para distribuir a
máquina, sin pasar por stock) — en bodega solo vive el material virgen. **Excepción:** a veces el
molido SÍ se registra como ingreso a inventario porque en ocasiones se vende como subproducto. El
módulo/tabla no debe asumir "el SKU siempre es virgen" — debe aceptar cualquier SKU (incluido un
código de "Molido" cuando aplique), sin lógica especial que lo bloquee.

**Molino — mucho más complejo de lo asumido inicialmente.** Álvaro describió el proceso real:
"muele/recicla; mezcla fórmulas; distribuye material a cada máquina de acuerdo a cada producto que
está sacando; usa material molido y virgen dependiendo del envase que requiera cada máquina; trabaja
molienda, colorantes, materias primas para las mezclas de cada envase." Esto es un dominio propio
(formulación + distribución a máquina), NO solo un almacén con existencias — diseñarlo bien
merecería su propia sesión de detalle más adelante (como se hizo con Producción o Serigrafía).
**Alcance MVP acordado para esta fase** (destino funcional para MPI/MPS, sin modelar fórmulas ni
distribución a máquina todavía): hub propio + historial de movimientos (mismo patrón que Bodega) +
personal + KPIs. La parte de fórmulas/distribución queda para una fase futura, a discutir aparte.

## Decisiones de arquitectura ya tomadas
- Sistema local = SICAF, app de escritorio, sin API/BD conocida (buscado en web sep/2026, sin resultados).
- Automatización de la CAPTURA en SICAF descartada por ahora (frágil, alto mantenimiento) —
  Álvaro sigue sacando capturas/PDF/Excel manualmente, igual que hoy.
- Lo que se automatiza es extracción (Claude) + clasificación asistida + inserción en Supabase,
  reusando el patrón ya existente de `api/parse-doc.js` (Claude Vision sobre foto de requi → JSON).
- Ubicación de la pantalla: bloque nuevo "Tareas del día" / Central de Ingreso en `index.html`.
- Histórico masivo (13+12 páginas ene-mar/2026): Álvaro decidió **no guardar nada en Supabase
  todavía** — primero "ponerla a funcionar" (Fase 1 operando con datos del día a día), la carga del
  histórico queda para después.

## Estado de construcción (sep/2026)
✅ **Hecho:**
- `sql/movimientos_insumos_v1.sql` — creado, PENDIENTE que Álvaro lo corra en el dashboard.
- `bodega.html` y `molino.html` — construidos (Inicio/KPIs, Movimientos con registro manual +
  filtro, Personal de solo lectura con link a gestion.html). Verificado que cargan sin errores JS
  hasta el guardián de sesión (sin login no se pudo probar el flujo completo con datos reales).
- Nav actualizado en TODOS los HTML (antes `nav-locked` en Bodega) + cards de index.html.
- `shared/styles.css`: agregado token `--molino` (Bodega ya existía).
- CLAUDE.md actualizado con los módulos nuevos y la SQL pendiente (ítem 14).

✅ **Hecho (sep/2026, sesión 2):** `inventario.html` se fusionó completo dentro de `bodega.html` como
pestaña "Existencias" (catálogo Bodega 02/05/07, tablas `inventario` + `insumos_b7`, importación
Excel, alertas de bajo stock) — a pedido de Álvaro. `inventario.html` ya no es un módulo aparte,
quedó como redirect a `bodega.html#existencias`. Se eliminó el importador de "Ventas · Facturación
diaria" que vivía duplicado dentro de inventario.html (ventas.html ya lo cubría completo con mejor
parser — confirmado por Álvaro, ver `.claude/docs/contexto-ventas.md`). Nav de todos los módulos
actualizado para quitar el link aparte a Inventario.

✅ **Hecho (sep/2026, sesión 3) — Central de Ingreso v1:**
- `api/parse-requi.js` — endpoint nuevo (Claude Vision, mismo patrón que `parse-doc.js`) que lee
  una imagen (captura o página de PDF renderizada) y devuelve `{ documentos: [...] }` — soporta
  VARIOS documentos por imagen (como el histórico masivo). A diferencia de `parse-doc.js`, este
  SÍ valida que quien llama tenga sesión válida y rol `master` (chequeo contra `perfiles`) antes de
  gastar tokens de Claude — mejora sobre el hueco de seguridad ya documentado en `parse-doc.js`.
- Bloque "Central de Ingreso" en `index.html` (banner + modal): sube imágenes o PDF (renderizados a
  imagen con pdf.js, cliente, igual que produccion.html) → llama al endpoint → aplica
  `ciSugerirAccion()` (las reglas de este doc: BASE/TAPA/CONTRATAPA→Tapas, SERIGRAFIA/SERIGRAFIADO→
  Serigrafía, prefijo define lo demás) → pantalla de revisión con un `<select>` de acción editable
  por línea (Álvaro puede corregir cualquier sugerencia) → "Guardar todo" reparte cada línea:
    - `tapas_salida`/`tapas_ingreso` → `movimientos_materiales`
    - `serig_entrega` → `entregas_serig` (pide Cliente en un campo extra, no hay solicitud vinculada)
    - `insumo_bodega_in/out` / `insumo_molino_in/out` → `movimientos_insumos`
    - `ajuste_resta`/`ajuste_suma` → ajusta `existencia` en `insumos_b7` (si existe ahí) o si no en
      `inventario`; si el SKU no existe en ninguno, lanza error y no guarda esa línea
    - `PRI` → SÍ tiene selector de acción como todo lo demás (cambio sep/2026, ver abajo): se
      precalcula la reconciliación contra `produccion_diaria` y esa comparación decide la
      SUGERENCIA por defecto, pero Álvaro puede completar el turno o reclasificar la línea
  Líneas ya guardadas quedan atenuadas y bloqueadas para evitar doble inserción si se presiona
  "Guardar todo" de nuevo.

**Corrección sep/2026 (sesión 4):** el diseño original dejaba `PRI` como una tabla de solo lectura
(reconciliar sin poder actuar) — Álvaro señaló que ahí necesitaba justo poder decidir: confirmar el
área de la línea (una `PRI` puede traer líneas de Tapas mezcladas, ver ejemplo `PRI 1791` del
histórico) y, si es de Producción y falta en el sistema, completar turno+máquina+operario ahí
mismo. Se unificó todo bajo el mismo `<select>` de acción por línea:
- Sugerencia por defecto para `PRI`: si el producto tiene BASE/TAPA/CONTRATAPA → `tapas_ingreso`;
  si no y ya coincide con `produccion_diaria` → `reconciliar` (no hace nada); si no coincide →
  `prod_completar` (pide Turno + Máquina + Operario, mismas listas que produccion.html: `MAQUINAS`
  1-12, `personal` donde `area='produccion'` activo).
- `prod_completar` inserta en `produccion_diaria` con `origen='central_ingreso'` (valor nuevo,
  distinto de `'pdf'`/`'manual'` que ya usa produccion.html, para poder distinguir el origen luego).
  Es un INSERT simple por línea, NO hace el DELETE-por-turno que sí hace `guardarTurno()` en
  produccion.html — la Central de Ingreso solo debe llenar huecos, no reemplazar un turno entero.
- El turno se adivina de la `descripcion` del documento (si dice "noche" o "dia/día") como default,
  editable.

⚠️ **Simplificaciones conocidas de este v1** (documentarlas para no sorprenderse):
- `PTS` (salida de PT) SIEMPRE sugiere `tapas_salida`, sin importar si la línea es Tapas o
  Serigrafía — no existe todavía una tabla de "salida de insumos hacia Serigrafía" distinta de
  `movimientos_materiales`. Álvaro puede corregir a mano si hace falta.
- `serig_entrega` no vincula a ninguna `solicitud` (`sol_id: null`) — el Cliente se escribe libre,
  a mano, en el campo extra. No reemplaza el flujo de "Registrar entregado" cuando SÍ hay que
  descontar contra una solicitud específica.
- No se probó el round-trip real con Claude Vision todavía (requiere estar desplegado en Vercel
  con sesión de Álvaro — el servidor estático local no sirve funciones `/api/*`). Solo se verificó
  que el HTML/JS carga sin errores hasta el guardián de sesión.
- El extractor no distingue Bodega 2/5/7 más allá de leer el campo "Bodega:" si está visible en la
  captura — si Álvaro recorta la captura sin ese encabezado, `bodega` queda `null` (no bloquea nada,
  es solo un dato informativo en la tarjeta de revisión).

⏳ **Falta / siguiente fase:**
- Probar con Álvaro en producción real (subir una requi de cada prefijo conocido, confirmar que la
  acción sugerida y el resultado del guardado son correctos).
- Seguir llenando el catálogo de prefijos con Álvaro (aún quedan por ver: Excel de inventario,
  detalle de facturación diaria, y prefijos nuevos que vayan apareciendo).
- Decidir si vale la pena vincular `serig_entrega` a una `solicitud` real en vez de dejarlo suelto.
