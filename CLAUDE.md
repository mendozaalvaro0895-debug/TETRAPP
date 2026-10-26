# TETRAPP — Sistema Digital de Producción y Procesos
## Tetraplastic · Guatemala · Usuario: Álvaro Mendoza (Administrador)

---

## Stack y Deploy
- Frontend: HTML vanilla autónomo por módulo (sin frameworks). CSS inline en cada archivo.
- Base de datos: Supabase (PostgreSQL) vía API REST
- Deploy: Vercel auto-deploy desde rama `main`
- Repo: github.com/mendozaalvaro0895-debug/TETRAPP
- Git: push siempre a AMBAS ramas → `git push origin master` + `git push origin master:main`

## Supabase
- URL: https://rohdxjuuvpgrhevfsrye.supabase.co
- KEY (publishable): sb_publishable_PayfE36QRzwOnP6zA2TDSQ_oj4vnB5i
- El cliente `db` lo provee `shared/auth.js` a TODAS las páginas (guardián de sesión + roles);
  ningún HTML declara ya SUPA_URL/SUPA_KEY/db propios
- `exec_sql` RPC no disponible con publishable key — DDL debe correrse manual en el dashboard

---

## Arquitectura actual
Cada HTML es AUTÓNOMO: CSS en `<style>`, funciones y datos inline. El cliente `db` y los
helpers de sesión/roles los provee `shared/auth.js`. `shared/styles.css` es el único archivo
de estilos compartido — se carga en todos los HTML como
`<link rel="stylesheet" href="shared/styles.css">` ANTES del `<style>` propio.

### Funciones serverless (Vercel) — carpeta `api/`
Node.js del lado servidor; secretos SOLO por `process.env.*` (nunca hardcodeados).
- `api/whatsapp.js` — bot WhatsApp (Twilio → Claude → INSERT con **service_role**, salta RLS).
  Tipos: tiros/flameado/empaque (Serigrafía) + tapas (comanda+tarea, sep/2026). El matching de
  SKU (`bot_buscar_sku`) y de operario de Tapas (`bot_buscar_operario`) normaliza tildes/plural
  y filtra a `inventario` facturable de Bodega 2 — ver sql/bot_buscar_sku_v2.sql,
  sql/bot_sku_palabras_clave_v1.sql (tabla `sku_palabras_clave` para enseñar apodos que no
  están en la descripción oficial) y sql/bot_tapas_v1.sql. ⚠️ El `bot_buscar_sku` original de
  sql/bot_rpcs_v1.sql nunca llegó a crearse en producción — verificar que el SQL de arriba sí
  se corrió (ver lista de SQL pendiente).
  Flujo de confirmación (sep/2026): ya NO inserta apenas tiene los datos completos — siempre
  pasa por `bot_estado.pendiente_confirmacion` (resumen armado por `resumenTexto()`) y espera
  que el remitente responda SI/NO antes de llamar `insertar()`. Aplica a los 4 tipos por igual.
  Foco actual: Tapas es el que se usa activamente (pensado para que los SUPERVISORES —no cada
  operario— le escriban directo, restringidos vía `TETRA_WA_ALLOW`); Serigrafía sigue en el bot
  pero Álvaro la sigue registrando manual por ahora.
  Comando fijo `"ASISTENCIA DE HOY"` (sep/2026, exacto — no pasa por el prompt de producción):
  lista personal activo de `area='tapas'`, el supervisor responde en texto libre quién faltó/
  llegó tarde (prompt aparte, `buildAsistenciaPrompt`, solo hace matching de nombres contra esa
  lista) → INSERT directo en `rrhh_faltas` (`origen='whatsapp_tapas'`) — sin RPC nueva, ya usa el
  client `service_role` del propio endpoint. Elegido en vez de `asistencia_diaria` porque esa
  tabla no tiene ninguna pantalla en Tapas todavía (el board tipo Asistencia Mensual de
  serigrafia.html queda pendiente de construir); `rrhh_faltas` sí se ve ya en gestion.html →
  Personal → Faltas, sin pantalla nueva.
  ⚠️ Valida firma `X-Twilio-Signature` (HMAC-SHA1, fail-closed) — sin `TWILIO_AUTH_TOKEN` rechaza TODO POST.
  Env: ANTHROPIC_API_KEY, SUPA_URL, SUPA_SERVICE_KEY, TWILIO_AUTH_TOKEN (obligatorio), TWILIO_WEBHOOK_URL, TETRA_WA_ALLOW.
- `api/_auth.js` — helper compartido (NO es endpoint: Vercel no publica archivos con prefijo `_`).
  `rolDeSesion(req)` valida el `Authorization: Bearer <access_token>` y devuelve el rol de
  `perfiles` consultando COMO el propio usuario (`perfiles` no tiene grants para service_role).
  `mimeImagen(m)` limita `mime_type` a png/jpeg/webp/gif. Lo usan los 3 endpoints de parseo.
  El front manda el token con `HEADERS.Authorization` (auth.js lo renueva en cada refresh). Excepción: index.html (sincronización del Drive y Central de Ingreso) usa `tokenVigente()`, que pide la sesión actual con `db.auth.getSession()` justo antes de llamar — la copia de HEADERS puede venir vencida si la pestaña estuvo dormida y el servidor responde "Sesión inválida" (el modal del Drive lo traduce a "tu sesión venció — recarga la página").
- `api/asistencia-drive.js` (oct/2026) — GET `?mes=YYYY-MM`: lee la pestaña del mes (ENE…DIC) de la hoja "ASISTENCIA DE PLANTA" por CSV público (gviz) y devuelve personas por área con estados normalizados (presente/ausente/velada/tarde/permiso/baja). Solo `master`. Env: `ASISTENCIA_SHEET_ID` (NO se guarda en el repo). Lo consume index.html. Los encabezados de sección que reconoce (col A, con B y C vacías) están en `SECCIONES`: GRUPO GABINO/ALEX, SERIGRAFIA, TAPAS, BODEGA, MANTENIMIENTO, TORNO, MOLDES, MOLINO, OFICINA y LIMPIEZA (oct/2026). ⚠️ Un encabezado NUEVO en la hoja que no esté ahí se lee como una PERSONA más de la sección anterior (así salió "LIMPIEZA" en "Nombres de la hoja sin cruzar"): al aparecer un área nueva, agregarla a `SECCIONES`, a los CHECK de `personal.area` y `asistencia_diaria.area`, y a `AREA_GRUPOS`/selectores de gestion.html.
- `api/parse-doc.js` — parsea foto de requi con Claude Vision → JSON {requi, fecha, productos[]}.
  Gateado (oct/2026): rol `master` u `operativo_prod` (401 sin sesión, 403 otro rol). Lo llaman
  produccion.html (screenshot de Ingreso) y serigrafia.html (lector de requis), sin CORS abierto.
- `api/parse-requi.js` — Central de Ingreso de index.html: lee una página/captura de reporte SICAF
  ("Salidas/Ingresos a Bodega", puede traer varios documentos) con Claude Vision (Sonnet, stream,
  max_tokens 32000) → `{documentos:[{bodega, documento, prefijo, numero, fecha, descripcion,
  referencia, lineas:[...]}], warnings}`. Solo `master`. maxDuration 120s en vercel.json.
- `api/parse-reporte-tapas.js` (oct/2026) — parsea el TEXTO de los reportes diarios que los
  supervisores de Tapas mandan por WhatsApp (formato real: un operario por bloque, sub-
  encabezados opcionales de día "Martes"/"Miércoles", líneas "cantidad + texto libre" que
  mezclan proceso+producto, ej. "1,300 liner 28 negra") → JSON `{filas:[{operario_texto,
  fecha, dia_texto, cantidad, proceso, descripcion, metodo, proceso_dudoso}], warnings:[]}`.
  Resuelve nombres de día de la semana a fecha real contra `fecha_referencia` (más cercana
  y anterior o igual, nunca futura). Si no reconoce el proceso de una línea, deja
  `proceso:""` + `proceso_dudoso:true` en vez de adivinar. Solo `master` (vía `api/_auth.js`)
  antes de llamar a Claude (Haiku). Consumido solo por comandas.html → "📥 Importar reporte WhatsApp" (ver
  abajo) — no hay flujo que inserte directo desde WhatsApp para este formato de reporte por
  lotes (es demasiado grande/variado para el flujo de confirmación SI/NO de una sola tarea
  que ya usa `api/whatsapp.js`); Álvaro sigue copiando el texto a mano del chat a la app.

### Módulos activos
| Archivo | Descripción |
|---|---|
| `index.html` | Fachada principal (modo OSCURO, branding futurista/elegante/industrial desde oct/2026) — fichas en orden Serigrafía·Tapas·Producción·Ventas·Bodega·Moldes*·Molino·Torno*·Mantenimiento*·Gestión·Dashboard (*sin módulo = `.area-card.disabled` "Próximamente") + **Guía de alimentación diaria** (`cargarGuia`, oct/2026: inventario AM desde el 1er ingreso / PM desde 3:33 pm GT, requis de Tapas y Serigrafía, ventas y asistencia Tapas/Serig del día HÁBIL ANTERIOR — salta domingos y `dias_feriados`; sin dato verificable NO bloquea; a master le bloquea las fichas hasta cumplir, con "Omitir hoy" + motivo en `tareas_diarias`; el bloqueo es solo en el inicio, los módulos siguen accesibles por enlace/menú; **Asistencia ← Drive** (`drvSincronizar`, oct/2026, solo master): al abrir el inicio y con el botón "Sincronizar ahora" lee la hoja "ASISTENCIA DE PLANTA" vía `api/asistencia-drive.js`, la cruza con `personal` por nombre (`drvCruzar`: tolera nombres cortos/typos; ambiguos y sin cruzar se listan para vincular a mano → `personal.nombre_hoja`, o para DAR DE ALTA con el botón "➕ Dar de alta" (oct/2026, `drvAltaAbrir`/`drvAltaGuardar`: abre un formulario con nombre, fecha de inicio (INGRESO de la hoja) y turno de Producción tomados de la hoja, código sugerido con la misma regla que Gestión (`drvCodigoLibre`, ESPEJO de `siguienteCodigoLibre` — también `DRV_PREFIJO`/`DRV_COLOR_AREA` espejan los de gestion.html), crea la MISMA ficha que "+ Nueva persona" y, si el área tiene bajas marcadas "plaza vacante", deja elegir cuál cubre (hereda su rol/puesto y apaga su marca, como "Cubrir vacante"); avisa si el nombre tiene parecidos en TETRAPP (usar Vincular, no alta) y al terminar re-sincroniza solo, así la asistencia del mes de la persona nueva se guarda en el acto). Las personas SIN parecidos salen marcadas "🆕 Persona nueva — se recomienda darla de alta" (botón de alta destacado; las que tienen parecidos recomiendan Vincular). En TODA la revisión del Drive (bajas, sin cruzar, listas informativas y el formulario de alta) cada nombre lleva una ETIQUETA DE COLOR GRANDE con su área (y turno en Producción) — `drvAreaChip`/`DRV_ACENTO_AREA`, la fila de estado dice "N personas nuevas en la hoja: dar de alta" y el modal se ABRE SOLO al cargar el inicio cuando hay bajas o personas nuevas por resolver (máx. cada 12 h si se cierra con "Ahora no"). ⚠️ La hoja a veces anota dentro del nombre "(INGRESO 12/10)": el cruce de nombres ya ignora los paréntesis y el alta los quita del nombre (`drvNombreLimpio`) y, si la columna INGRESO viene vacía, toma la fecha de esa nota (`drvIngresoDeNombre`, DD/MM). La vacante que sugiere el alta es la que coincide con el puesto de la hoja ("L2 - FLAMEO" ↔ Flameador); si ninguna coincide no hereda el puesto) y escribe `asistencia_diaria` de TODAS las áreas (turno 'dia'). La HOJA MANDA, salvo que un 'tarde' de TETRAPP no se pisa con PRESENTE; PERMISO y "Viaje laboral" → presente; en Tapas/Serig mantiene `rrhh_faltas` igual que las grillas. BAJA/RENUNCIA nunca baja sola: modal de confirmación (fecha_baja = primer día reportado). El roster del indicador Personal sale de la hoja del mes en curso) + **Indicadores en las fichas de Serigrafía, Tapas y Producción** (`cargarIndicadores`, oct/2026; en Producción Unidades mes sale de `produccion_diaria` y si el mes no tiene filas muestra "—" + "sin carga desde dd/mm" en vez de 0 — a oct/2026 esa tabla solo tiene datos hasta 30-may; Q mes = familias clasificadas como Producción en ventas): Rotación mes (oct/2026, reemplazó a "Ausentismo" a pedido de Álvaro) = bajas del mes ÷ plantilla promedio × 100, con plantilla promedio = (activos al inicio + activos hoy) ÷ 2 y activos al inicio = activos hoy + bajas − ingresos del mes; sale de `personal` (`fecha_baja` / `fecha_inicio` dentro del mes, `indRotacion`), que la hoja del Drive mantiene al día; las bajas viejas sin `fecha_baja` no cuentan; ≤3% verde, ≤6% ámbar, >6% rojo — umbrales propios. Se RETIRÓ "Efectividad" (oct/2026, a pedido de Álvaro): dependía de captura diaria de tiros/comandas y mostraba 0% cuando se atrasaba; si se retoma, mostrarla solo con datos recientes. Personal = presentes/activos del último día hábil (presente+tarde+velada), con las VACANTES libres en su línea de texto (Producción = cupo 19 por turno − activos, ⚠️ espejo de `PLANTILLA_PRODUCCION_TURNO` de gestion.html; Serig/Tapas = bajas con `plaza_vacante`), Unidades mes (Serig = `entregas_serig`, Tapas = `entrada_pt`) y Q mes = facturación del área SIN IVA con copia de `clasificarArea` de ventas.html (⚠️ `IND_AREA_FAM`/`indClasificarArea` en index.html son ESPEJO — si cambia la clasificación en ventas.html replicar allá) + **Central de Ingreso** (sube PDF/imagen de reportes SICAF; pdf.js lee por página, 4 en paralelo, conserva lo ya leído si una página falla → `api/parse-requi.js`; clasifica cada documento por prefijo según `.claude/docs/contexto-bot-requis.md` y graba en `entregas_serig`/`movimientos_materiales`/`movimientos_insumos`/`produccion_diaria`, o ajusta existencia en `insumos_b7`/`inventario`). ENTREGAS DE SERIGRAFÍA CON FICHA (oct/2026, `ciExtraSerig`/`ciCargarFichas`): cada línea "Serigrafía — Registrar entrega" tiene un buscador de FICHA DE TRABAJO (`solicitudes` area='serig', activas primero y completadas al escribir) con el avance entregado/pedido; si UNA sola ficha activa lleva el SKU de la línea queda vinculada sola (✓ por SKU, `ciFichasPorSku`, prueba también el SKU sin el último dígito); al elegirla rellena cliente y línea L1-L4. Al guardar escribe `entregas_serig.sol_id/sol_codigo` y `lineas[].solId/solCodigo` (igual que "Registrar entregado" de serigrafia.html) y, si lo entregado alcanza lo pedido, pasa la ficha a COMPLETADA en `solicitudes` Y `solicitud_lineas` (`ciCompletarFichaSiCorresponde`; como en Serigrafía, una entrega parcial NO marca "parcial"). Avisa si la requi ya está registrada. ⚠️ Los ingresos/salidas de TAPAS desde la Central todavía NO guardan `solicitud_id`. Solo funciona para master (el endpoint rechaza a otros roles). ⚠️ El ajuste de existencia es select+update NO atómico y permite quedar en negativo — no se pasó a `descontar_inventario` porque esa RPC recorta en 0 y ocultaría descuadres contra SICAF |
| `tapas.html` | Módulo completo Tapas: hub (Personal y Roles + Asistencia Mensual) + movimientos (salidas/ingresos/rechazos) + productividad + trazabilidad + personal + pedidos |
| `serigrafia.html` | Módulo admin Serigrafía: Inicio (board) + Movimientos + Productividad + Personal |
| `registro-serigrafia.html` | Formulario móvil rol `operativo_serig`: Flameado / Impresión / Empaque |
| `comandas.html` | Registro de producción diaria por operario (vista admin) + "📥 Importar reporte WhatsApp" (oct/2026, lotes multi-operario/multi-día) |
| `registro-tapas.html` | Formulario móvil rol `operativo`/`supervisor_tapas`: comanda concluida, correlativo CMD-### vía trigger DB. Datos del día = solo fecha (hora_inicio/cierre quedan null; supervisor se adjunta solo desde `personal`). Pantalla de selección: lista a TODO el personal activo de Tapas (supervisión primero, ficha destacada) y, debajo, el bloque "Personal y Roles" (copia del de Tapas → Inicio: barra relativa al líder del mes, clic en un nombre despliega el ESPEJO del detalle de Tapas → Inicio — funciones copiadas en este HTML: 📅 producción diaria con línea de meta 10,000 y popup por barra, ⚙️ producción por proceso desplegable con sus ingresos y 📜 historial de ingresos, ver abajo; visible para todos. SOLO CONSULTA: sin botones de aprobar/rechazar ni enlaces a comandas.html porque el rol operativo está enjaulado aquí; todo cambio de diseño de ese desplegable debe replicarse en ambos archivos). Campo "Tapa o envase trabajado *" OBLIGATORIO en cada tarea con cantidad (se elige de la lista; tarjetas con cantidad 0 se ignoran, no se guardan). PESTAÑA "📋 Pedidos" (oct/2026, barra de pestañas Registrar producción · Pedidos; `irTab`/`mostrarPantalla('scrPed')`, el wrap se ensancha a 1600px para PROYECTAR; se refresca sola cada 45 s): `cargarPedidos` lee `solicitudes` area=tapas (+líneas), `movimientos_materiales` entrada_pt vinculados a ficha y `tapas_lotes`. Muestra (1) 🔵 En proceso: un lote por tarjeta con barra de avance y su fecha límite, (los chips de cada cliente se ordenan: en proceso primero y luego la fecha límite más cercana, sin fecha al final) (2) grilla de chips COMPACTOS — IDÉNTICA a las Fichas de Trabajo de tapas.html: botones "Por tipo" / "Por cliente" (en ESTE perfil el default es POR CLIENTE y cada cliente arranca COLAPSADO —solo encabezado con pedidos y saldo—; abrirlo se recuerda con valor 0 en `tapas_fichas_colapsados`, `pedEstaCol`; en tapas.html master el default sigue siendo por tipo y expandido) (resumen de lo que se debe de cada tipo de tapa + una sección por tipo, `detectarTipoTapa`/`tipoDeSkuTapa`, tipo guardado en el Recetario > palabras clave > "Sin clasificar") / "Por cliente" (misma elección en localStorage `tapas_fichas_agrupar`); ⚠️ ESPEJO: cualquier cambio de reglas de tipos, orden o diseño de esa vista se hace en AMBOS archivos. En la vista por cliente: (columnas = clientes; chip = código de ficha + ⏳ FECHA LÍMITE corta "20-oct" (rojo si venció, ámbar si vence en ≤2 días; `pedLimiteHtml`), SKU·descripción en una línea, saldo = pedido − entregado, y "▶ N en proceso" si hay lote) — solo fichas vivas (nueva/proceso/parcial) con saldo, y (3) ✅ Completados: los ingresos PT ya hechos con su NO. DE REQUI, agrupados por requi+ficha y marcados Parcial/Completa según lo acumulado de la ficha. Tocar un chip abre un popup que arranca con "📦 SKUs para pedir a Bodega" (`pedFilasBodega`/`pedBloqueBodegaHtml`: ESPEJO del mismo bloque del detalle de la ficha en tapas.html — la tapa + Base/Contratapa/Liner/Banda con SKU, descripción, Necesita · Ya salió · Por pedir · Stock, "FALTAN N" y el botón "📋 Copiar pedido" para pegarlo en el mensaje a Bodega; la supervisora ve así qué SKUs pedir sin depender del master) y luego pedido/entregado/en proceso/sin iniciar para marcar un LOTE: cuántas unidades se trabajan ahora (parciales: varios lotes por ficha, máx. el saldo sin iniciar) + ¿QUIÉN INICIA? (chips con el personal activo de Tapas, `operarios`) + ¿QUÉ PROCESO? (chips con los procesos de la ficha, `solicitud_lineas.procesos`; si no trae ninguno, todos; se pueden elegir VARIOS a la vez) y también VARIOS operarios a la vez: se guarda una fila por cada operario × proceso elegido — operario y al menos un proceso obligatorios; cada proceso iniciado es una fila en `tapas_lote_tareas` (lote, proceso, operario, hora) y un lote puede tener varios ("＋ Iniciar otro proceso / operario en este lote": armado → liner → impresión…). Las tarjetas "En proceso" muestran las últimas 2 tareas ("Armado · Karen S."). Sin el SQL #36 se sigue pudiendo marcar el lote pero sin operario/proceso (avisa). Un lote NUNCA se cierra a mano: se completa solo cuando oficina registra el ingreso PT vinculado a la ficha (bloque Entregados de tapas.html); reparto FIFO de ingresos a lotes por fecha de marcado (`pedModelo`, solo ingresos posteriores al marcado). Se pueden quitar lotes marcados por error. Escribe en `tapas_lotes` (SQL pendiente #35; sin correrlo se ven los pedidos y avisa). Se probó un termómetro por ficha contra meta fija de 10,000 und/día y se descartó. Autocompletar de tapa: todas las coincidencias, por palabras sin tildes, facturables primero |
| `dashboard.html` | KPIs ejecutivos globales |
| `ventas.html` | Ventas y Financiero: Resumen · Productos · Clientes · Rotación · Importar facturación (Excel/CSV cols A-R) · toggle IVA. Área de cada venta (`clasificarArea`): 1) `inventario.area_ventas` del SKU exacto (RPC `get_area_ventas_overrides`) → 2) el mismo con el SKU SIN su último dígito (SICAF factura con un dígito extra: ventas `101621` = inventario `10162`) → 3) SKU en fichas de Serigrafía (`cargarSerigSkus`, SOLO `solicitudes.area='serig'` — Tapas usa las mismas tablas) → 4) familia (`AREA_FAM_MAP`: TAPA/BASE/CONTRATAPA/LINER→Tapas, SERVICIO→Serigrafía, resto→Producción). Para reclasificar un producto se fija `area_ventas` en su SKU de inventario (ver `sql/diagnostico_tapas_area_ventas_v1.sql`). ⚠️ IVA: acumular SIEMPRE el monto SIN IVA y aplicarlo solo al mostrar (`fmtQ()` ya llama a `qVal()`). Acumular con `qVal()` y luego mostrar con `fmtQ()` cobra el IVA dos veces (×1.2544) — así estaban Aporte por área, su copia del reporte y los desgloses de clientes por producto hasta oct/2026 |
| `produccion.html` | Sopladoras e inyectoras (20 máquinas desde la tabla `maquinas`: helpers `maqNombre`/`maqCorto`/`maqOptions`/`maqIdsFichas`; las fichas muestran también las máquinas inactivas que tengan producción en el período), 3 pestañas: **Inicio** (`renderInicio`: modo Fichas por máquina —con foto en `img/maquinas/maqN.png`, ver README de esa carpeta— o Tabla, `switchInicioModo`; período Día/Semana/Mes con fecha compartida, `switchInicioVista`, Mes por default — reemplaza a los viejos Reporte Semanal y Mensual) · **Ingreso** PDF/manual (pdf.js) o screenshot (`api/parse-doc.js`) · **Recetario** (catálogo `insumos_b7` paginado para no truncar; editable por master y `operativo_prod`); en la ficha de Producción el colorante va en **g por kg** de resina (el % se calcula = g/kg ÷ 10) y el botón "📋 Pegar receta (Excel)" (`parsePegadoColorante`/`rcPegarAplicar`) carga las líneas "SKU  g/kg" de UN color en el envase abierto — solo llena la pantalla, se guarda con "Guardar especificaciones"). Asigna máquina Y operario por fila (`personal` area='produccion') |
| `gestion.html` | Gestión de Personal y Planta: tabla unificada tapas+serig+producción+molino+bodega+moldes sobre la misma tabla `personal` + RRHH (locker/EPP/talla) + permisos/incidentes/faltas/capacitaciones/bonos + Lockers + Planta (mejoras_planta, CRUD simple por tarjetas). Master-only. |
| `bodega.html` | Bodega — Inicio (KPIs) · **Existencias** (ex-`inventario.html`, integrado sep/2026: catálogo Bodega 02/05/07, tablas `inventario`+`insumos_b7`, importación Excel, alertas de bajo stock) · Movimientos (`movimientos_insumos`, área='bodega', destino de los prefijos SICAF `MPI`/`MPS`) · Personal. `DESCRIPCIONES (oct/2026): al importar el inventario de Bodega 2/5, además de la existencia se ACTUALIZA la `descripcion` de los SKU existentes si SICAF la cambió (antes solo se insertaba al crear el SKU y nunca se refrescaba: caso 10373, que en SICAF pasó de "BASE TAPA DOMO LADY CARMINE ROJO INTENSO" a "BASE TAPA DOMO ROJO INTENSO (Varios Diseños)" y TETRAPP seguía mostrando la vieja). La vista previa muestra un recuadro "Descripciones cambian" con "anterior → nueva"; se compara sin distinguir mayúsculas (todo se guarda en MAYÚSCULAS) y una descripción vacía en el Excel no pisa nada. Bodega 7 NO se toca (sus descripciones están corregidas a mano). `inventario.html` ahora es solo un redirect a `bodega.html#existencias` (no borrado, por si hay bookmarks/PWA viejos). |
| `molino.html` | Molienda/mezcla/distribución de materia prima a máquina: mismo patrón que bodega.html (Inicio · Movimientos `área='molino'` · Personal). Alcance MVP — no modela todavía fórmulas ni distribución por máquina, ver `.claude/docs/contexto-bot-requis.md`. |
| `plano-nivel2.html` | Plano 3D de la planta (35×45 m): Nivel 2 editable (zonas, pasillos, tarimas con uso, racks, toneles, gradas, elevadores) + modelo del Nivel 1 de SketchUp (GLB) como referencia. Three.js, ficha en index solo para master (la página se restringe sola con `TETRA_PAGINAS_MASTER.push('plano-nivel2')`, sin tocar auth.js). Guarda VERSIONES en la tabla `planos` (una fila por guardado, `datos` = JSON v2; GLB del Nivel 1 en bucket privado `planos`) — `sql/planos_v1.sql`, YA CORRIDO (13-oct-2026); COPIA DE TRABAJO compartida = fila `version = 0` (se sube sola con cada cambio y cualquier equipo la descarga al abrir; ver `syncSubir`/`syncInicio`; columna `actualizado_en`, también en `sql/planos_v1.sql`), con localStorage solo como copia local. Exporta GLB/SVG/GeoJSON/JSON. Formato y códigos estables: `.claude/docs/plano-nivel2-formato.md`. Fase futura: ligar tarimas a SKU (tabla `tarimas_mapa`) cuando se estabilice el flujo de entradas/salidas/rechazos. |

Ver `.claude/docs/contexto-bot-requis.md` para el contexto completo del "Bot Cazador de Info"
(catálogo de prefijos SICAF, reglas de clasificación, mapeo a tablas) — en construcción por fases,
Bodega/Molino es la Fase de destino funcional; sigue la Central de Ingreso en `index.html`.

---

## Design System v1.0
Ver paleta CSS, componentes y patrones completos: `.claude/docs/design-system.md`
Regla: cargar `shared/styles.css` ANTES del `<style>` propio en todo HTML.

---

## tapas.html — Arquitectura de vistas

```
switchTab(tab) controla qué view se muestra. SIN sidenav (se eliminó sep/2026 para
igualar a serigrafia.html) — la navegación es solo la barra de pestañas.
Orden de pestañas (mismo que serigrafia.html + Pedidos como 7ma):
  Inicio · Movimientos · Productividad · Trazabilidad · Personal · Dashboard(link) · Pedidos
'rechazos' es ALIAS → switchTab('movimientos') + setMovVista('rechazos')

view-inicio      ORDEN ACTUAL (oct/2026, calcado de serigrafia.html): Alertas Base · Alertas Contratapa · Asistencia · Personal y Roles · Producción mensual · Fichas de Trabajo · Entregados.
  Los 3 bloques del detalle de abajo (Asistencia, Personal y Roles, Producción mensual) siguen igual.
  ALERTAS "Bajo Stock — Base/Contratapa" (renderAlertasTapas; copia del bloque "Envases Base" de serigrafia.html, sin PDF ni float de pedidos): por cada SKU de componente suma lo que piden las fichas VIVAS (nueva/proceso/parcial, líneas no "lista"), descuenta lo que ya salió de Bodega para esas fichas (movimientos_materiales salida_bodega por solicitud_id), y compara contra existencia de inventario (Bodega 2 con prioridad) → "Pedir" = faltante. Lee `solicitud_lineas.sku_base` (ya existía como "SKU materia prima") y `solicitud_lineas.sku_contratapa` (se captura en el formulario "Nueva solicitud · Tapas"; ⚠️ la columna se crea con sql/solicitud_lineas_componentes_tapas_v1.sql — SQL pendiente #29; hasta correrlo, guardar una ficha con Contratapa/Liner/Banda falla y el formulario avisa). 1 unidad de componente por unidad de tapa. Bloque Base lista además las líneas sin base ("huecos").
  BARRA SUPERIOR (oct/2026, igual que serigrafia.html): solo "🖨 Imprimir" (imprimirFichasTapas: PDF de TODAS las fichas activas nueva/proceso/parcial, agrupadas por cliente A→Z, con entregado/pedida desde movimientos_materiales entrada_pt) + "+ Nueva Solicitud". Se quitaron el enlace a Comandas y el dropdown "Movimiento": registrar salida/ingreso/rechazo se hace desde la pestaña Movimientos (movRegistrar). comandas.html se abre desde la pestaña "📋 Comandas" de la barra de pestañas (con contador de pendientes por aprobar).
  FORMULARIO "Nueva solicitud · Tapas" (abrirForm/guardar, oct/2026): Cliente + PLAZO DE ENTREGA (obligatorio, se elige al ingresar la solicitud: chips "Fecha límite" | "Entregas parciales" (OC ABIERTA: el cliente deja una OC grande y va pidiendo por partes) | "Pendiente" (sin fecha); `solicitudes.plazo_tipo` = 'fecha'|'parciales'|'pendiente', SQL pendiente #37, `setPlazoForm`; en parciales/pendiente `fecha_limite` queda null; el tipo solo se manda a la base cuando no es 'fecha', así el caso normal no depende del SQL) — con fecha: `solicitudes.fecha_limite`, input `fLimite`; ya no hay "Área solicitante" ni fecha de ingreso visible — el ingreso sigue en `created_at`). Las tarjetas (lista de Pedidos, Fichas de Trabajo y el PDF de Imprimir) muestran "⏳ Límite AAAA-MM-DD" en lugar de la fecha de ingreso (`limiteFichaTapas`: ROJO si ya venció y la ficha sigue viva, ÁMBAR si vence en ≤2 días) y el detalle de la ficha tiene el selector para cambiarla (`cambiarFechaLimiteTapas`, solo master). ⚠️ Las fichas creadas antes de oct/2026 con el formulario anterior guardaron la fecha de INGRESO como fecha_limite: hay que corregirlas desde el detalle + Prioridad + UNA línea de pedido con buscador de SKU como el de Serigrafía (todas las coincidencias por palabras sin tildes, FACTURABLES PRIMERO con encabezados; texto libre = producto nuevo sin SKU) + 4 componentes opcionales con su propio buscador: Base (sku_base), Contratapa (sku_contratapa), Liner (sku_liner), Banda (sku_banda). Liner y Banda se buscan y toman su stock de Bodega 7 (tabla insumos_b7, insumosB7Cache; sin grupos de facturable), el resto de inventario (B2). DESPLEGABLE DE CLIENTES ORDENADO POR FRECUENCIA DE USO (oct/2026, `poblarClientesTapas`): los clientes con más fichas de Tapas primero (conteo real sobre `solicitudes`, a igual uso alfabético; los nunca usados al final; un cliente que está en fichas pero no en la lista fija `CLIENTES` se agrega). Se rearma cada vez que se abre el formulario. AUTORRELLENO (oct/2026, `autorrellenarDesdeFichas`/`fichaPreviaDe`): cada ficha guardada es dato para las siguientes — al elegir el producto (o cambiar el cliente) en una solicitud NUEVA, si ese MISMO cliente ya había pedido ese SKU, se copian los componentes (Base/Contratapa/Liner/Banda) y los procesos de su ficha MÁS RECIENTE (aviso azul "↺ Rellenado con la ficha T-00N"); todo editable, solo llena campos vacíos (no pisa lo que el usuario ya tocó), omite componentes que ya no existen en el catálogo, y al cambiar de cliente o de producto descarta lo autorrellenado y vuelve a buscar. Solo coincide cliente + SKU exactos (los componentes cambian por cliente: logos, tamaños). No corre al editar. RECETA POR CLIENTE (oct/2026, tabla `sku_recetas_cliente`, SQL #38): un mismo SKU puede llevar otro Liner/Base según el cliente (caso 13002: SINERGIA e INCOGUA, solo cambia el Liner) y `sku_recetas` tiene UNIQUE(sku_fact) (una general por SKU), así que cada cliente que difiere guarda SU versión aparte (`partes` jsonb, mismo formato que `sku_receta_partes`); prioridad al autorrellenar: ficha anterior del cliente > variante del cliente > receta general. Al guardar/eliminar una ficha, `ofrecerRecetaDeFicha(sku, desc, partes, cliente)` compara primero contra la variante de ESE cliente (si existe) y si no contra la general; cuando difiere de la general la ventana trae TRES opciones: "Quedarme con la del Recetario", "Guardar solo para <CLIENTE>" (upsert en `sku_recetas_cliente`; la general no cambia) y "Cambiar la general" (reemplaza para TODOS los clientes). Sin correr el SQL la opción de cliente avisa qué archivo falta. El Recetario de produccion.html todavía NO muestra las variantes por cliente. RESPALDO CON LA RECETA (oct/2026, `cargarRecetasTapas`/`recetaComoFuente`): si ese cliente NO había pedido ese SKU (o su ficha se eliminó), se rellena con la receta guardada en el Recetario para el SKU (`sku_recetas` area 'tapas': base → Base, accesorio con nota Contratapa/Liner/Banda, procesos por nombre) y el aviso azul dice "Rellenado con la receta guardada en el Recetario". La ficha del mismo cliente gana sobre la receta (más específica: logos, tamaños). La caché `recetasTapas` se carga al iniciar, al abrir el formulario y tras guardar/reemplazar una receta; el SKU puede elegirse sin haber puesto cliente. SKU EXTRAORDINARIO (oct/2026, `crearSkuExtraB7`): en el buscador de Liner y Banda, si el insumo no existe (ej. "LINER INDUCCION 28 PARA PET" que lleva una tapa vendida terminada) la última opción verde "➕ Crear SKU extraordinario" lo da de alta en `insumos_b7` con código `EXT-###` consecutivo (`siguienteSkuExtra`), descripción en mayúsculas, existencia 0, activo, y lo deja elegido; el stock se carga después desde Bodega → Existencias (y ahí se desactiva si ya no se usa). Solo Bodega 7: el catálogo facturable de `inventario` (SICAF) no se toca. Solo Cliente y Cantidad son obligatorios; un componente escrito debe ser un SKU real de inventario. Si falla el insert de la línea se borra la ficha (no queda una ficha sin línea). Alertas de bajo stock hoy solo para Base y Contratapa (Liner/Banda se guardan pero no tienen alerta todavía). PROCESOS (sincronizarProcs): chips Armado/Banda/Liner/Flameado/Impresión/Encajado + ENSAMBLE (oct/2026), proceso EXCLUSIVO de la familia PUSH PULL: el chip "Ensamble (Push Pull)" solo aparece cuando el Tipo de la tapa es Push Pull (`esFamiliaPushPull`, marca `soloPushPull` en `ALL_PROCS_TAPAS`) y se descarta solo si el producto/tipo cambia a otra familia (`aplicarFamiliaProcs`); no lo sugiere ningún componente (se marca a mano). Existe también en: lotes del perfil de Tapas (`PED_PROC_LBL`; NO se ofrece en fichas sin procesos), Recetario (`PROCESOS_FIJOS` de produccion.html) y las listas de proceso de registro-tapas.html/comandas.html (`PROCS_LIST`, ahí sale para todas las tapas porque la tapa se elige después). Sin meta propia → cae en el default de 1200 und/h (falta definirla en las 4 tablas de METAS). Los componentes elegidos SUGIEREN y marcan solos — Base o Contratapa → Armado · Liner → Liner · Banda → Banda — pero TODO chip se puede quitar o poner a mano (oct/2026: antes quedaban fijos; una tapa domo de 1 pieza lleva Base pero NO se arma). Lo que el usuario toca (`l.tocados`) ya no lo mueve un componente; si se quita el componente que lo sugirió y no se tocó, el chip se apaga. Se guardan en solicitud_lineas.procesos y alimentan el "Cálculo automático" (meta = la menor de los procesos activos; sin procesos, 1,200 und/h).
  FICHA → RECETARIO (oct/2026, ofrecerRecetaDeFicha tras guardar una ficha): cada ficha con un SKU real de producto y algún componente/proceso ofrece (confirm) enviar su combinación al Recetario de produccion.html — Base → `sku_receta_partes` tipo 'base'; Contratapa/Liner/Banda → 'accesorio' con el rol en `nota`; procesos → 'proceso' (nombres de PROCESOS_FIJOS, ahora con Encajado). La receta nace en `sku_recetas` con area='tapas', guardado=false (queda en "Pendientes" para revisión humana). Si la receta NO tiene partes se ofrece enviarla (confirm). Si YA tiene partes NUNCA se sobrescribe sola: cuando la ficha es DISTINTA (se compara Base/accesorios/procesos en ambos sentidos, `clavePartesReceta`) se abre la ventana `abrirConflictoReceta` con las DOS versiones lado a lado ("📚 La del Recetario" vs "📝 La de esta ficha", en amarillo lo que solo está en una) y se elige: "Quedarme con la del Recetario" (no cambia nada) o "Usar la de esta ficha" (`recetaConflictoElegir`: inserta las partes nuevas, luego borra las anteriores base/accesorio/proceso y devuelve la receta a `guardado=false` = "Pendientes"). Si son iguales no pregunta nada. ⚠️ Serigrafía (`ofrecerRecetasDeFicha` en serigrafia.html) todavía solo avisa con un toast, sin esta ventana. LA RECETA SOBREVIVE A LA FICHA (oct/2026): `sku_recetas`/`sku_receta_partes` no cuelgan de `solicitudes` (ni FK ni trigger), así que eliminar una ficha NUNCA borra su receta del Recetario; además `confirmarBorrar` llama a `ofrecerRecetaDeFicha` con `partesRecetaDeFicha(s)` tras borrar, de modo que si ese SKU aún no tenía receta con partes se ofrece guardarla (y si difería de la guardada se abre la comparación). Lo que SÍ se pierde al borrar una ficha: el historial cliente+SKU que usa el autorrelleno del formulario. Meta de fondo (Alvaro, oct/2026): estos datos alimentan los Recetarios de TODAS las áreas y de ahí ML/DL — Serigrafía ya hace lo mismo (ver serigrafia.html abajo). Escribir en el Recetario requiere master u operativo_prod (RLS); sin permiso el aviso falla en silencio con un toast.
  ENTREGADOS (renderEntregadosTapas, oct/2026; calcado del bloque "Entregados" de serigrafia.html): historial de requis de ingreso PT, tabla No. Requi · Cliente · Pedido · Producto · Unidades · Fecha · Origen · Requi Salida Bodega + ✏️/✕. Serigrafía lo guarda en `entregas_serig`; en Tapas la fuente es `movimientos_materiales` tipo='entrada_pt' (UNA fila por producto; las filas con el mismo num_documento son UNA requi — gruposEntregados), la MISMA tabla que ya alimenta Movimientos → Ingresos PT, la ficha y Trazabilidad, así que no hay SQL nuevo ni segundo historial. "+ Registrar entregado" (abrirIngPT, modal `overlayIngPT`): No. de requi*, fecha, N productos (pedido opcional con buscador de fichas vivas + SKU con el buscador facturables-primero + cantidad) y nota; el pedido de una ficha de un solo producto rellena el SKU. Guardar inserta con area='tapas' y SUMA la existencia (aumentar_inventario). Editar inserta lo nuevo, luego borra lo anterior y ajusta solo la diferencia por SKU; eliminar borra y RESTA (descontar_inventario recorta en 0). Cliente y "Requi Salida Bodega" salen del pedido vinculado (no hay columna cliente); buscador por requi/SKU/cliente/pedido y "Mostrar más" de 40 en 40. Borrar/editar solo funciona con rol master (RLS): se avisa si no se borró nada. De paso `parseObs` ahora también quita el "FECHA:…" cuando no hay nota. ⚠️ No cambia el estado de la ficha a "lista" al completar la cantidad (Serigrafía sí lo hace; Tapas no tiene syncEstado). ZONA DE PEGADO DE LA REQUI (oct/2026, calcada de Serigrafía): arriba del formulario "Registrar entregado", un recuadro punteado — Ctrl+V pega el screenshot (funciona con la ventana abierta aunque no se haga clic en la zona; doble clic en la miniatura = ampliar) o "selecciona un archivo o toma una foto" (celular). `ingProcesarImagen` → `ingEnviarParseDoc` (escala a 1568 px, JPEG) → MISMO endpoint que Serigrafía, `api/parse-doc.js` con tipo 'ingreso' (solo master/operativo_prod) → `ingAplicarResultado` rellena requi, fecha, nota (descripción) y las líneas; los códigos que no existen en el inventario B2 se avisan en rojo y la línea queda con el texto para elegir a mano; si la tapa tiene UN solo pedido vivo con ese SKU, se vincula sola (cliente + pedido, con aviso "🔗 vinculado a T-00N (revisa)"; con varios pedidos no vincula). El CLIENTE es UN solo select en el encabezado, junto al No. de requi y la fecha (`ingCli`/`ingCliChange`, a pedido de Alvaro para dejar ancho a Pedido + SKU + cantidad): filtra la búsqueda de pedido de todas las líneas, se fija solo al elegir el primer pedido (o al leer la imagen si todos los pedidos vinculados son del mismo cliente) y al cambiarlo se sueltan los pedidos de otro cliente. Cada línea: Pedido · SKU/descripción · cantidad; no existe "Línea de producción" porque Tapas no la usa.
  CLIC EN EL RECUADRO DE LÍMITE de la tarjeta (`abrirPlazoFicha`, popup `modalPlazoTapas`): muestra pedido/entregado/en proceso/sin iniciar y ofrece "▶ Trabajar parcial" (`trabajarParcialFicha`: cuántas unidades se arrancan ahora, máx. las sin iniciar → inserta un lote en `tapas_lotes`, el mismo de la pestaña Pedidos de registro-tapas.html, donde la supervisora asigna operario y proceso; se completa solo con el ingreso PT) y permite cambiar el plazo entre Fecha / Entregas parciales / Pendiente (`guardarPlazoFicha`). Las fichas con plazo parciales/pendiente muestran "Parciales" / "Pendiente" en azul en lugar de la fecha (en tarjetas, lista, PDF y chips de Pedidos de registro-tapas.html) y van al final al ordenar por fecha límite.
  TIPO / SUBFAMILIA DE TAPA (oct/2026, `detectarTipoTapa`/`tipoDeFicha`/`guardarTipoTapa`): las tapas se agrupan por tipo — Press top 33/415, Press top 28/410, Push Pull, Elípticas, Domo, Flip top 20/415… (+ los que se creen con "＋ Otro tipo…"). El tipo es del SKU, no de la ficha: se guarda en el Recetario (`sku_especificaciones`, area 'tapas', campo 'Familia' — el mismo campo "Familia" que ya trae el Recetario de Tapas) al guardar la ficha (nueva o edición), y el formulario lo AUTORRELLENA la siguiente vez que se pida ese SKU (nota "guardado en el Recetario"). Mientras un SKU no tenga tipo guardado se SUGIERE por palabras clave de la descripción (press top / flip top + medida NN/NNN, push pull, elíptica, domo; si no coincide: "Sin clasificar") y el usuario lo confirma o cambia en el campo "Tipo" bajo el producto. Prioridad: tipo guardado > palabras clave > Sin clasificar. Dato para ML. QUITAR UN TIPO (oct/2026): la última opción del desplegable "Tipo", "－ Quitar un tipo…" (`abrirQuitarTipos`/`quitarTipoTapa`), abre una ventana con cada tipo y su uso (SKU en el Recetario · fichas) y un botón ✕ Quitar: borra de `sku_especificaciones` los 'Familia' que lo tenían (esos SKU quedan sin tipo y se vuelve a sugerir por palabras clave; solo master por RLS) y lo oculta del desplegable con la lista local `tapas_tipos_ocultos` (localStorage del navegador; volver a crearlo con "Otro tipo…" lo reactiva). No borra fichas ni cambia cómo se agrupan las Fichas de Trabajo (ahí sigue saliendo por la descripción).
  FICHAS DE TRABAJO — VISTA COMPACTA (oct/2026, `FICHAS_VISTA_COMPACTA=true`, `renderFichasCompactasTapas`): ES LA MISMA VISTA que la pestaña Pedidos de registro-tapas.html (a pedido de Alvaro: más práctica) — arriba "🔵 En proceso" (un lote por tarjeta con avance, tareas "Armado · Karen S." y fecha), debajo chips chicos con UNA COLUMNA POR CLIENTE (código + ⏳ fecha corta/Parciales/Pendiente + saldo, SKU·descripción, "de N · ent. X" o "▶ N en proceso"), solo fichas vivas con saldo, ordenadas: en proceso primero y luego fecha límite más cercana. VISTA CELULAR (oct/2026, ≤700px, en AMBAS pantallas — `cpChipTap`/`pedChipTap`): los chips muestran solo lo esencial (código + fecha + saldo, SKU principal, descripción en 1 línea y un resumen "✓ componentes ok" / "✗ N sin stock" / "▶ N en proceso"); al TOCAR un chip se abre en el mismo lugar (descripción completa, "de N · ent.", componentes con existencia y un botón grande "Ver detalle de la ficha" / "Abrir pedido · marcar en proceso"); en pantalla grande tocar un chip abre directo el detalle/popup como siempre. En celular también: columnas por cliente apiladas en 1 columna, tipos a 1 columna, ventanas (detalle de ficha, plazo, popup del pedido) como HOJA desde abajo a todo el ancho, botones y chips de selección más grandes para el dedo, números 2×2. El bloque "SKUs para pedir a Bodega" del detalle de la ficha (master) es ahora de TARJETAS por componente (SKU grande + descripción + Necesita/Ya salió/Por pedir/Stock), igual que el popup del perfil de Tapas, y en celular se oculta la tabla "Líneas del pedido" (repite lo mismo). TODA la página registro-tapas.html está pensada para CELULAR (los supervisores/usuarios de Tapas entran desde el teléfono; master suele usar PC), bloque `@media(max-width:700px)` junto a `.ped-cerrar`: selección de operario en LISTA de 1 columna (avatar a la izquierda), Personal y Roles con filas de 46px de alto y gráfico diario más bajo (`ALTO_BARRAS_DIA` = 120 en celular, 180 en PC), formulario con el botón "Guardar mi producción" PEGADO abajo (sticky) y cabecera/tarjetas más compactas, toast que parte línea. En tapas.html (master) los lotes "en proceso" se quitan DESDE LA VENTANA de la ficha (detalle, bloque "Lotes en proceso" justo bajo "SKUs para pedir a Bodega") y desde el popup del límite — NO desde la tarjeta/chip (`lotesAbiertosPlazoHtml` + `quitarLoteTapas`: borra el lote de `tapas_lotes`, sus tareas caen por cascade, las unidades vuelven a "sin iniciar" y no toca ningún ingreso PT). La supervisora ya podía quitar desde registro-tapas.html. VISTA "POR PRIORIDAD" (oct/2026, tercer botón junto a Por tipo / Por cliente, en AMBAS pantallas; `solicitudes.prioridad`, localStorage `tapas_fichas_agrupar`='prioridad'): sin selector de orden — siempre el bloque rojo "🔴 Urgentes" primero y luego "Demás pedidos", cada uno por fecha límite más cercana (parciales/pendiente al final). Los chips urgentes llevan la insignia "🔴 URGENTE" en todas las vistas. registro-tapas.html ahora también lee `prioridad` en su select. STOCK DEL SKU PRINCIPAL (oct/2026, `stkPTHtml`/`stkPTTexto` en tapas.html, `pedStkPTHtml` en registro-tapas.html — ESPEJO): cada chip muestra bajo la descripción una BARRA DE ANCHO COMPLETO bien notoria (`stkPTBarra`/`pedStkPTBarra`: izquierda "📦 STOCK PT <n>", derecha una píldora de color con la acción) con la existencia del PRODUCTO TERMINADO (inventario B2) frente al saldo por entregar — verde "✓ CUBRE EL SALDO", ámbar "PRODUCIR N und" (saldo − stock), rojo "PRODUCIR TODO N und" cuando el stock es 0; en la ventana de la ficha la fila "Tapa" de "SKUs para pedir a Bodega" lo trae contra el pedido. Es informativo: no descuenta lo que otra ficha pueda tener apartado del mismo SKU; sin SKU de inventario (producto nuevo) no se muestra. registro-tapas.html ahora también consulta `inventario` por el SKU principal. NOTAS DE LA FICHA (oct/2026, `solicitudes.notas`; ahí se anota la cantidad de entregas y parciales): se muestran SIEMPRE en una caja amarilla "📝 Notas" dentro de cada chip (COMPLETA, sin recortar —a pedido de Alvaro las notas largas con varias OC debían leerse enteras—, saltos de línea respetados) y en las tarjetas "En proceso" — `notaChipHtml` (tapas.html) / `pedNotaHtml` (registro-tapas.html, que ahora también lee `notas` en su select; ESPEJO). En la ventana de la ficha (master) y en el popup del pedido (Tapas) van COMPLETAS y ARRIBA de todo (antes estaban al final del detalle). Los bloques colapsables se mantienen. JERARQUÍA DEL CHIP (oct/2026, a pedido de Alvaro): el SKU PRINCIPAL de la tapa va GRANDE (15px, mono, negrita) con su descripción legible debajo (11px, hasta 2 líneas), y los componentes quedan en un bloque discreto aparte (9px, grises, borde punteado) — solo los estados "alcanza / insuficiente" conservan color. Idéntico en registro-tapas.html. Cada chip lista sus COMPONENTES con existencia y si alcanzan, como la ficha de Serigrafía (`componentesStockHtml`: "BASE 10258 BASE TAPA PRESS TOP NATURAL · 51,500 und · ✓ alcanza" — con la DESCRIPCIÓN del componente (Base, Contratapa, Liner, Banda), que se parte en varias líneas si no cabe / "✗ insuficiente: faltan N" / "✓ ya retirada"; stock actual B2 para Base/Contratapa y Bodega 7 para Liner/Banda vs. lo que aún falta SACAR de bodega para esa ficha = cantidad − salidas de bodega ya vinculadas, por SKU; NO resta lo que pidan otras fichas con el mismo SKU — eso lo ve Alertas de bajo stock). La pestaña Pedidos de registro-tapas.html lo REFLEJA IDÉNTICO (`pedCompStockHtml`/`pedCargarStock`: lee las existencias actuales de los componentes de B2 y Bodega 7 y las salidas de bodega por ficha en cada actualización; mismo cálculo y mismo texto) — Alvaro pidió que lo que ve el área sea reflejo de lo que ve el master, sin desfases: todo cambio de esta vista se hace en AMBOS archivos. BLOQUES COLAPSABLES en cualquier vista (clic en el encabezado de cada tipo, cada cliente y el bloque "En proceso" —y "Completados" en registro-tapas.html— oculta/muestra sus chips; el encabezado con totales queda visible; se colapsa/expande UNO POR UNO, sin botón de "colapsar todo" (a pedido de Alvaro); estado en localStorage `tapas_fichas_colapsados`, mismo en ambas pantallas: `toggleBloqueFichas`/`toggleBloquePed`). Botón "Por tipo / Por cliente" (se recuerda en localStorage `tapas_fichas_agrupar`; por defecto POR TIPO): por tipo muestra arriba un resumen con lo que se DEBE (saldo por entregar) de cada tipo — el de más pendiente primero, "Sin clasificar" al final — y debajo una sección por tipo con sus chips (cada chip lleva el nombre del cliente); por cliente es la grilla de columnas. Clic en un chip = detalle en ventana flotante (que tiene "▶ Trabajar parcial" para arrancar un parcial / cambiar el plazo). Los Completados no se repiten (están en Entregados). `modeloFichasCompactas` usa el mismo reparto FIFO de ingresos a lotes que `pedModelo` de registro-tapas.html (si cambia la regla, replicarla). Poniendo la bandera en false vuelve la grilla cliente × mes de abajo. GRILLA ANTERIOR (renderFichasTapas): la tarjeta destaca dos recuadros — UNIDADES (grande, teal) y ⏳ LÍMITE (fecha corta "22 oct" + "en 7 días"/"vence hoy"/"venció hace 2 días"; rojo si venció, ámbar si vence en ≤2 días; `limiteFichaTapas` devuelve txt/corta/rel/dias/cls). Los componentes van como chips con su NOMBRE escrito, sin emojis ("BASE 10258", "CONTRATAPA 10291", "LINER 6113", "BANDA …"). Además cada tarjeta muestra "▶ N en proceso" (azul) si la supervisora marcó un lote en la pestaña Pedidos de registro-tapas.html (`cargarLotesTapas` + `enProcesoDeFicha`, mismo reparto FIFO de ingresos que `pedModelo` de registro-tapas.html — si se cambia la regla de un lado, replicarla en el otro). Mismas solicitudes area=tapas de la pestaña Pedidos, en grilla cliente (columna) × mes (fila, más reciente primero) como el "Sin asignar" de serigrafia.html. Mes = periodo_efectivo o mes de creación en hora GT (calendario, SIN el corte del día 28 de Serigrafía); las fichas "lista" solo se muestran en el mes en curso. Borde de color por estado (rojo/amarillo/verde); clic abre el detalle en una VENTANA FLOTANTE como en Serigrafía (`abrirFichaTapas` → `modalFichaTapas`, `fichaModalId`; ya no cambia de pestaña): mismo contenido que el panel derecho de la pestaña Pedidos (`mostrarDetalle` pinta en el modal si la ficha está abierta ahí — ids de slider con prefijo 'm' — o en el panel): PRIMERO el bloque "📦 SKUs para pedir a Bodega" (`filasBodegaFicha`/`buildBloqueBodegaFicha`: la tapa como referencia + Base/Contratapa/Liner/Banda de cada línea con Necesita (1 por tapa) · Ya salió (movimientos salida_bodega de la ficha por SKU) · Por pedir · Stock actual (B2, o B7 para Liner/Banda; "FALTAN N" en rojo) y el botón "📋 Copiar pedido" que copia al portapapeles el texto con lo pendiente para pegarlo en el mensaje a Bodega), luego INGRESOS PT de la ficha con su requi, líneas con componentes, notas y los botones ✏️ Editar/Lista/Entregar/borrar + fecha límite editable. ⚠️ OCULTOS POR AHORA (a pedido, oct/2026): "Tiempo estimado", "Trazabilidad de fugas" (con sus botones registrar pérdida/entrada PT/salida), la barra de "Progreso" y el botón "▶ Iniciar" — el código sigue en `mostrarDetalle`, se vuelven a mostrar con `DETALLE_FICHA_EXTRAS = true`. ✏️ EDITAR (`editarFichaTapas`/`guardarEdicionFicha`): reabre el formulario "Nueva solicitud" precargado (título "Editar · T-00N", botón "Guardar cambios"; `editandoFichaId`) con cliente, fecha límite, prioridad, notas, producto, cantidad, componentes y procesos; actualiza `solicitudes` + la PRIMERA línea (`solicitud_lineas` por id; vaciar un componente lo pone en null) sin tocar código, estado ni ingresos; fichas viejas con varias líneas conservan las demás. Solo master (RLS: avisa si no hay permiso). Al guardar vuelve a ofrecer el envío al Recetario si el SKU aún no tiene receta. No hay drag-drop ni cierre mensual (no aplica a Tapas).
view-inicio      HUB default (vaciado sep/2026, ahora "lo más parecido a serigrafia.html"):
  3 secciones apiladas en .inicio-dos-col (flex-direction:column; ya no lado a lado —
  Asistencia truncaba nombres a mitad de pantalla), SIN tarjetas de navegación — esa
  navegación vive únicamente en las pestañas de arriba. Las 3 envueltas en la misma clase
  .inicio-sec (ya no hay distinción izq/der).
  1) "📋 Asistencia Mensual": grid mensual sobre `asistencia_diaria` (area='tapas',
    turno='dia'), MISMO mecanismo que serigrafia.html salvo: sin roster diario de roles/
    líneas (no aplica a Tapas), sin agrupación "Prestados". Comparte con serigrafia.html:
    navegación de mes (navegarMesAsistTapas),
    ciclo de estados por celda (toggleAsistCellTapas: pendiente→presente→ausente→tarde→
    velada→vacío en días hábiles; finde→presente→vacío en domingo/feriado — CADA CLIC
    GUARDA DE INMEDIATO en asistencia_diaria), candado asistLockedTapas (bloqueada por
    default), botón "💾 Guardar" (guardarAsistenciaTapas: bloquea + confirma — no hay nada
    "pendiente" que commitear, ya se guardó por clic; a diferencia de serigrafia.html, cuyo
    Guardar sí hace algo real: el tablero de roles/líneas que Tapas no tiene), exportación
    a PDF (exportarAsistGridPDFTapas: MISMO formato que exportarAsistGridPDF de
    serigrafia.html — SEPARADO POR QUINCENAS con idénticas fechas de corte, mismo
    calendario de nómina de la empresa: Quincena 1 = últimos 2 días del mes anterior +
    días 01–13 del mes actual; Quincena 2 = días 14–(último día del mes − 2). Los últimos
    2 días del mes quedan para la Quincena 1 del SIGUIENTE PDF, es una ventana rotando
    mes a mes, no se pierden. Cada quincena en su propia página (`.q-sep{page-break-
    before:always}`) con su propio resumen de Inasistencias/Tarde/Veladas/Domingos/
    Inicios/Bajas y su propia racha "fila verde ⭐ = quincena completa" (los 2 días del
    mes anterior NO cuentan para esa racha, tampoco los días antes del ingreso o tras la
    baja). `fecha_inicio`/`fecha_baja` de `personal` SÍ aplican a Tapas (son columnas
    genéricas, no solo de Serigrafía — gestion.html las edita para cualquier área desde
    Datos generales; confirmado sep/2026 tras un caso real: el PDF no marcaba el ingreso
    de una operaria que sí tenía `fecha_inicio` cargada). Celdas antes del ingreso/tras
    la baja se pintan gris `#e2e8f0` sin dato (igual que serigrafia.html), y esos días NO
    rompen la racha verde. Recortado frente a Serigrafía SOLO en: sin matriz de roles por
    celda, sin agrupación "Prestados" (esos dos sí son específicos de cómo trabaja esa
    área) — mismo mecanismo de generación: tabla HTML standalone en pestaña nueva +
    window.print(). ⚠️ Los 2 días "del mes anterior" de la Quincena 1 (`anteriorQ1`) son
    un concepto DISTINTO a la cola de ASIST_MARGEN_TAPAS=5 días de la grilla en vivo (ver
    abajo) — el PDF reutiliza el mismo `asistCacheTapas` (que ya trae ±5 días de margen)
    sin necesidad de una consulta aparte, porque 5 ≥ 2), sincronización con rrhh_faltas
    (sincronizarFaltaDesdeAsistenciaTapas, origen='asistencia_tapas' — distinto de
    'asistencia_serig' para no mezclar proveniencia), racha verde de fila completa,
    feriados vía toggleFeriado (clic derecho en el día — dias_feriados es GLOBAL, Tapas
    y Serigrafía comparten la misma fila sin distinción de área), y justificación de
    ausente/tarde por clic derecho (abrirJustifPopoverTapas/guardarJustificacionTapas,
    con foto opcional al bucket Storage `justificaciones`, prefijo 'faltas/<personal_id>/
    <fecha>.jpg' — mismo bucket que usa gestion.html para Capacitaciones, sin colisión
    porque personal_id es único entre áreas). ⚠️ Sin registro explícito, la celda SIEMPRE
    muestra "pendiente" (gris) — a propósito distinto de serigrafia.html, que asume
    "presente" por default en días pasados sin marcar; aquí no se asume nada, solo cuenta
    lo que se marcó a propósito (afecta también la racha verde: un día sin marcar la
    rompe, salvo hoy que sigue "en curso"). Encabezado de cada día muestra además el
    día de la semana en chico (Lun/Mar/Mié…) bajo el número.
  ⚠️ Días de cola por corte de nómina (ASIST_MARGEN_TAPAS=5): se muestran 5 días ANTES
    del 1ro y 5 días DESPUÉS del último del mes en curso (tinte ámbar .ag-th-margen +
    borde divisor .ag-divider-th/-cell en cada borde) — a diferencia de serigrafia.html,
    que solo agrega cola ANTES (ASIST_DIAS_ANTERIOR, por su propio corte del 25; no se
    tocó ese archivo). La racha verde SOLO mira diasMesActual, la cola no cuenta. La
    consulta a asistencia_diaria se amplía ±5 días fuera del mes para traer esos datos
    (ya no usa el helper compartido `rangoMes()`, calcula el rango manual con
    `fmtISOTapas()` para no afectar Productividad/Trazabilidad que sí lo usan).
  2) "👥 Personal y Roles" (termómetro; incluye a supervisión desde oct/2026 porque también registra producción; NO es el tablero drag-drop de serigrafia.html
    a propósito — Tapas no tiene ese concepto de rol/línea): barra horizontal por operario
    activo (rol≠supervisor) con las unidades Terminada del MES ACTUAL desde comandas+
    comanda_tareas. 100% de la barra = el operario con más unidades ese mes (relativo, no
    meta fija) — agruparComandasPorOperario() es compartida con Productividad (prodPorOperario
    ahora es un wrapper de una línea sobre ella, ver regla #3). Nombre completo, sin truncar
    (columna de 190px). Clic en la fila (toggleTermDetalle) despliega el desglose por
    proceso del MISMO total del mes (agruparPorOperarioYProceso, sobre el mismo
    termComandas — la query de cargarTermometro ahora también trae `proceso`), ordenado
    de mayor a menor unidades para ver de un vistazo en qué proceso tiene más experiencia
    cada operario (quién arma más, quién tiene más horas de flameado/impresión, etc.).
    Desde oct/2026 el desplegable (buildTermDetalle) son DOS columnas a todo el ancho de la fila: izquierda = SOLO 📅 Producción diaria (gráfico de barras por día, 210px de alto, con LÍNEA PUNTEADA DE META de 10,000 und/día — META_DIA_GRAFICO; la escala es absoluta y llega al menos hasta la meta — + resumen + leyenda; CLIC en una barra (días con registro: producción o por aprobar) abre un popup con el detalle de ese día — verDetalleDiaOperario: cada comanda con su estado, motivo si fue rechazada, tareas proceso · tapa · und y enlace ↗ a comandas.html; el total del encabezado suma solo lo aprobado); derecha = ⚙️ Producción por proceso (buildTermProcesos): barras con su % del total, y CLIC en un proceso (toggleTermProceso, varios a la vez, estado en termProcAbiertos) despliega los ingresos de esa persona en ESE proceso en orden cronológico — fecha · tapa (SKU — descripción, o "Sin tapa registrada") · unidades (registrosDeProceso; solo tareas Terminadas de comandas aprobadas; el correlativo CMD-### va en el tooltip). El bloque "Productividad y habilidad" (lista por tapa y proceso) se integró aquí y se eliminó. Cada persona es una FILA ENMARCADA tipo botón (borde, chevron ▸/▾; abierta = borde teal y nombre en teal, unida al panel de detalle) — antes se pintaba celeste y se confundía con el resto. Debajo, 📜 Historial de ingresos DESPLEGABLE (cerrado por defecto; el encabezado enmarcado es el botón; estado por persona en termHistAbierto; mismo comportamiento en registro-tapas.html) (buildTermHistorial): TODAS las comandas de esa persona en el mes sobre termComandasTodas (aprobadas, por aprobar y rechazadas, con insignia y motivo del rechazo), la más reciente primero, cada una con sus tareas (proceso · tapa · und) y un enlace ↗ a comandas.html?id=… para revisarla/editarla/aprobarla. Las comandas POR APROBAR llevan ahí mismo (y en el popup del día) botones ✅ Aprobar / ⛔ Rechazar (cambiarEstadoComandaTapas: mismo efecto que en comandas.html — estado, quién, cuándo, motivo obligatorio al rechazar —; actualiza la memoria y repinta sin volver a consultar, y refresca el contador de la pestaña Comandas).
    DESPLEGABLE EN DOS BLOQUES (oct/2026, `buildTermDetalle`; en pantalla angosta se apilan):
    · 📅 PRODUCCIÓN DIARIA (`buildTermDiario`): una barra por día del mes con el total del día
      (compacto "4.5k") — sirve para ver si algún día alguien NO subió producción. Estado de cada
      día en `estadoDiaTerm()` (el orden importa): fuera del período (antes de `fecha_inicio`/
      después de `fecha_baja`) → produjo (>0 und en comanda APROBADA, aunque sea domingo) →
      domingo/feriado (`feriadosSet`) → futuro → "por aprobar" (solo hay comandas pendientes,
      ámbar) → ausente (`asistencia_diaria` area='tapas', cargada en `cargarTermometro` →
      `termAsistencia`) → hoy (en curso, no se marca) → **sin registro** (rojo, número del día
      en negrita + lista "Sin registro: día 6, 17" + resumen "N días · promedio X und/día").
      ⚠️ Supuesto: solo domingo y feriado son no laborables — el sábado SÍ cuenta como día de
      trabajo (igual que la grilla de Asistencia); si alguien no trabaja sábados saldrá "sin
      registro". Usa `termComandasTodas` (incluye pendientes/rechazadas) además de `termComandas`.
    · 🎯 PRODUCTIVIDAD Y HABILIDAD (`buildTermProductividad`): "Por proceso" (lo de antes) +
      "Por tapa y proceso" (`agruparPorTapaYProceso`: `comanda_tareas.tapa_sku`/`tapa_desc` ×
      proceso, mayor a menor) = en qué tapa y proceso acumula experiencia. DESDE oct/2026 la
      tapa (o envase) es OBLIGATORIA en toda tarea con cantidad: registro-tapas.html la exige
      elegida de la lista (SKU real; si el catálogo no cargó acepta el texto), y comandas.html
      la exige en las tareas "Terminada" del editor manual (en el importador de WhatsApp es solo
      un aviso/confirmación: las líneas sin SKU se guardan igual). Lo registrado ANTES de esa
      regla, o por el bot de WhatsApp (que sigue ofreciendo "0) Sin SKU"), sale agrupado como
      "Sin tapa registrada". registro-tapas.html tiene su PROPIA copia de este mismo desplegable
      (mismas funciones `buildTermDetalle`/`buildTermDiario`/`agruparPorTapaYProceso`, CSS en
      hex porque ese archivo no usa variables) — cualquier cambio acá hay que replicarlo allá.
      ⚠️ En registro-tapas.html lo ve TODO el personal de Tapas (rol operativo/supervisor_tapas),
      así que cada quien ve los días "sin registro" de sus compañeros. La asistencia
      (`asistencia_diaria`) y los feriados se leen en try/catch: si ese rol no tiene permiso de
      lectura, el detalle sigue funcionando pero un día "ausente" saldrá como "sin registro".
  3) "📦 Producción mensual — Ingreso PT": CLON del mismo gráfico de la pestaña
    Productividad (mismo renderProdMensualTapas, mismo mecanismo Acumulado/Comparar/
    navegación ◀▶ — ver detalle completo en view-productividad más abajo), en el
    contenedor `prodMensualTapasInicio`. Cada clon tiene su propio estado (mes navegado,
    Acumulado, Comparar) en `prodMensualInst.inicio` / `prodMensualInst.productividad` —
    cambiar de mes o togglear Acumulado en uno NO afecta al otro. `prodEntradasPTCache`
    (los datos crudos) SÍ es compartido entre ambos para no duplicar la consulta cuando
    los dos miran el mismo rango de fechas.
  dias_feriados es GLOBAL (sin columna area) — Tapas y Serigrafía comparten la misma tabla,
  sin necesidad de migración. asistencia_diaria si necesitó sql/asistencia_area_tapas_v1.sql
  (fix defensivo del CHECK constraint de `area`, mismo patrón que personal_area_check).
view-tapas       Solicitudes — split pane: lista + detalle  (pestaña "Pedidos")
view-movimientos Segmented control de 3:
  [📤 Salidas de Bodega] [📦 Ingresos PT] [⛔ Rechazos]
  Comparten: movDesde/movHasta, movBuscar, kpi-strip (mkpi-v1..v4), movTabla
  setMovVista('salida'|'ingreso'|'rechazos') actualiza todo
  movRegistrar() delega a abrirModalMov() o abrirModalRechazo()
view-productividad  Mensual (prodMes) sobre comandas+comanda_tareas, solo tareas 'Terminada'.
  setProdVista('operario'|'proceso'). Por operario es la ÚNICA vista con eficiencia medida:
  horas turno = hora_cierre − hora_inicio (tiempo real) vs horas meta = Σ horas_efectivas
  (lo que debió tomar según meta); cumplimiento = horas meta ÷ horas turno.
  ⚠️ NO usar horas_efectivas como "tiempo real": se calculó dividiendo entre la meta, así que
  und ÷ horas_efectivas devuelve siempre la meta (100% artificial). Por eso la vista por
  proceso muestra volumen y meta, no und/hora real: la comanda no reparte el turno por proceso.
  metaDeProceso(nombre) normaliza tildes ('Impresión' → clave 'impresion' = 1500, no default).
  Arriba de la tabla, "📦 Producción mensual — Ingreso PT" (renderProdMensualTapas,
  instancia 'productividad', contenedor `prodMensualTapas`): barras diarias sobre
  movimientos_materiales (tipo='entrada_pt') — equivalente de renderProdMensual en
  serigrafia.html, pero esa usa entregas_serig (tabla propia de Serigrafía que Tapas no
  tiene); en Tapas "requi de ingreso PT" ES movimientos_materiales, agrupado por
  parseFechaDoc(observaciones) || created_at igual que Trazabilidad. CLONADO también en
  view-inicio (instancia 'inicio', contenedor `prodMensualTapasInicio`) — mismo gráfico,
  estado independiente por instancia vía `prodMensualInst[inst]` (ver view-inicio arriba).
  Mismos controles que Serigrafía: 📈 Acumulado (toggleProdVistaLineaTapas(inst), línea SVG
  acumulada — _buildLineaAcumSvgTapas), 📊 Comparar (toggleProdCompararTapas(inst), mes
  anterior alineado debajo/detrás), navegación de mes ◀▶ (navegarProdMesTapas(inst),
  independiente del selector `prodMes` de la tabla operario/proceso). Clic en una barra
  abre el detalle del día
  (verDetalleProdDiaTapas: SKU + descripción + documento + cantidad, desde
  movimientos_materiales — más simple que el popup de Serigrafía porque ahí sí existen
  líneas de requi con cliente/SKUs detallados, aquí no). ⚠️ SIN gradiente rojo/ámbar/verde
  por meta diaria (PROD_META_DIA=30000 en serigrafia.html es un número específico de esa
  área, sin equivalente confirmado en Tapas) — barras en un solo color (teal). Caché propio
  (prodEntradasPTCache, ventana dinámica por mes ± comparar) independiente del prodComandas
  de la tabla de abajo.
view-trazabilidad  Mensual (trazaMes): cascada por pedido Salida bodega → Ingreso PT →
  Pérdidas → Fuga neta, agrupando movimientos_materiales por solicitud_id. Los movimientos
  sin solicitud_id caen en un bucket "— Sin vincular —" para que los totales cuadren.
  Filtra por fecha del DOCUMENTO (prefijo FECHA: en observaciones, vía parseFechaDoc) y no
  por created_at: por eso la query pide una ventana de ±60 días y recorta client-side.
view-personal    Grid de operadores
```

## serigrafia.html — Arquitectura de vistas

```
Tabs: Inicio · Movimientos · Productividad · Personal · Dashboard (link)
FICHA → RECETARIO (oct/2026, `ofrecerRecetasDeFicha`, tras guardar o editar una ficha): mismo criterio que Tapas. Por cada línea con SKU real de inventario ofrece (UN confirm para todas las líneas) enviar al Recetario: envase base (`sku_base`) → `sku_receta_partes` tipo 'base'; procesos de la línea → tipo 'proceso' (nombres de ALL_PROCS_SERIG; Tampografía/Horno/Secado ya están en PROCESOS_FIJOS de produccion.html); y, si lleva Impresión/Serigrafía/Tampografía, `sku_especificaciones` campo 'Tiros' (area 'serigrafia', ignoreDuplicates: no pisa uno ya cargado). La receta nace area='serigrafia', guardado=false (Pendientes). Nunca sobrescribe una receta que ya tiene partes (si difiere solo avisa). Cada línea del formulario tiene tres campos OPCIONALES "Para el Recetario": Colores, Fórmula de tinta y Empaque (`l.colores`/`l.formula_tinta`/`l.empaque`) — NO se guardan en la ficha (sin columnas nuevas ni SQL): viajan solo al Recetario como `sku_especificaciones` 'Colores' / 'Fórmula de tinta' / 'Empaque' (ignoreDuplicates, nunca pisan lo ya cargado) y, si se llenan para un SKU que ya tiene receta, se ofrece completar solo esas especificaciones. Al editar una ficha vuelven en blanco (no hay de dónde leerlos). Datos para ML/DL.
view-productividad: si la fecha está vacía, buildUltimasLecturasHint() muestra las últimas
  10 lecturas clicables para saltar a su fecha — distingue "base vacía" de "fecha equivocada"
```

### Asistencia Mensual ↔ gestion.html → Personal → Faltas (sincronización)
`toggleAsistCell(codigo, fecha)` (grilla del board, `#asistGrid`) es la ÚNICA fuente que
dispara la sync — NO los otros toggles de asistencia del archivo (`toggleAsistHoy`,
`toggleAsistencia`), esos son paneles rápidos aparte y no sincronizan.
- Marcar `ausente` en la grilla → `sincronizarFaltaDesdeAsistencia()` crea (si no existe)
  una fila en `rrhh_faltas` con `origen='asistencia_serig'` → aparece como alerta 🚨 en
  gestion.html hasta justificarse.
- Destildar `ausente` → borra esa fila auto-generada SOLO si sigue sin justificar (una ya
  justificada se deja intacta, es registro de RRHH).
- Dirección inversa: registrar una falta manual en gestion.html para alguien de `area='serig'`
  → `sincronizarAsistenciaDesdeFalta()` marca `ausente` en `asistencia_diaria` para esa fecha
  (salvo que sea feriado — ver abajo). Solo Serigrafía tiene Asistencia Mensual por ahora —
  Tapas no sincroniza.
- Todo el flujo es best-effort (try/catch silencioso): si `sql/rrhh_faltas_v1.sql` no ha
  corrido, la asistencia normal sigue funcionando igual.
- ⚠️ La sync solo dispara hacia ADELANTE (clics nuevos). Ausencias que ya estaban en
  `asistencia_diaria` antes de que existiera este código no llegan solas — usar
  `sql/rrhh_faltas_backfill_v1.sql` (idempotente) para traerlas una vez.

### Días feriados — casilla gris en Asistencia Mensual (tabla `dias_feriados`)
Se tratan EXACTAMENTE igual que un domingo: `feriadosSet[fecha]` (cache global, cargado en
`init()` vía `cargarFeriados()`) se combina con `dow===0` en cada punto donde antes solo se
chequeaba domingo — `toggleAsistCell`, `buildRows`/`thDays` (grilla en vivo, `#asistGrid` y
`#personalAsist`) y `buildPersonaRows`/`thDias` (`exportarAsistGridPDF`). Un feriado:
- Nunca puede quedar en `ausente`/`tarde`/`velada` (el ciclo de clic salta directo a
  finde↔presente, igual que domingo) → nunca dispara `sincronizarFaltaDesdeAsistencia`.
- No rompe la racha "fila verde = asistencia completa del mes".
- **Clic derecho en el número del día** (header de la grilla) → `toggleFeriado(fecha)`
  marca/quita el feriado (pide descripción, requiere tabla desbloqueada — `asistLocked`).
- `sql/dias_feriados_v1.sql` crea la tabla + marca 2026-08-15 + limpia lo que ya se había
  generado mal ese día (faltas auto + registro 'ausente') — correr ANTES de
  `rrhh_faltas_backfill_v1.sql` si vas a correr ambos, para que el backfill ya los excluya.

### Estados de ficha — SOLO 4 (`ESTADOS_SERIG`)
`nueva` ⚪ → `proceso` 🔵 → `parcial` 🟡 → `lista` 🟢
**`lista` = ENTREGADO / COMPLETADO** — estado final, pinta la ficha de verde con badge
COMPLETADO. NO existen `programada` ni `entregada` (eliminados 2026-08-19; constraints
en `sql/solicitudes_parcial_constraint.sql`).

⚠️ El estado vive en DOS tablas y la tarjeta lee `l.estado || s.estado` — la LÍNEA gana.
Escribir solo en `solicitudes` guarda el cambio pero **no se ve**. Usar siempre
`syncEstado(s, estado)`, que actualiza `solicitudes` + todas sus `solicitud_lineas`.

Transiciones automáticas en `boardDrop()`:
- Entra a línea de producción → `proceso`
- Vuelve a Sin Asignar → `estadoPorEntregas(s)`: 0 entregas=`nueva` · parcial=`parcial` · completa=`lista`
- Una ficha ya en `lista` nunca se degrada al moverla

**Entregas**: la única fuente son las requis manuales vinculadas a la ficha
(`getEntregasManuales()`). El estado NO cuenta como entrega — sumarlo duplicaba unidades.

Tier de color: `lista`=2 verde · `parcial`=1 amarillo · resto=0 rojo.
Orden dentro de cada desplegable: rojo → amarillo → verde.

## gestion.html — Arquitectura de vistas

```
Tabs: Personal (activo) · Asistencia (activo) · Lockers (activo) · Planta (activo)

view-asistencia (oct/2026): cuadro MENSUAL de asistencia de TODO el personal, SOLO LECTURA (no es una
  fuente de datos nueva: lee `asistencia_diaria` — la llena la sincronización con la hoja "ASISTENCIA DE
  PLANTA" desde index.html y las grillas de Tapas/Serigrafía — y la cruza con `personal` por
  `operador_codigo` = `personal.codigo`, sin distinguir mayúsculas). `asCargarMes()` se dispara cada vez
  que se entra a la pestaña y al cambiar de mes (◀ ▶ / "Hoy"); trae el mes completo SIN filtrar por área y
  PAGINADO de a 1000 (un mes de toda la planta pasa de 2,500 filas — PostgREST corta en 1000) + los
  `dias_feriados` del mes. Filas = personal agrupado como en la pestaña Personal (AREA_GRUPOS, supervisor
  ★ primero con `ordenSupervisorPrimero`; Producción con `ordenProduccionPorTurno` y sub-fila "Turno
  Gabino/Alex"); columnas = días 1…fin de mes + totales Aus./Tar. Quién aparece (`asRoster`): activos,
  bajas con `fecha_baja` dentro/después del mes o con registros ese mes; nunca quien ingresó después del
  mes. Celdas (`asCelda`): ✓ presente · ✕ ausente · T tarde · V velada · P permiso · B baja · "·" SIN DATO
  (nunca se asume presente ni ausente, igual que la grilla de Tapas) · gris = domingo/feriado · rayado = fuera
  de su período (antes de `fecha_inicio` / después de `fecha_baja`). El sábado cuenta como día laborable.
  Si dos filas del mismo día vienen de áreas distintas (alguien que cambió de área) manda la de su área
  actual. La fila-título de cada área muestra por día cuántos presentes (y ausentes en rojo) y avisa "sin
  datos del mes" si esa área no tiene ningún registro (ej. áreas que la hoja aún no sincronizó). La tira de indicadores (clase `kpi-strip-h` para esquivar la
  regla de 2 columnas de shared/styles.css en pantallas ≤1024px) resume el último día con datos (presentes
  de N, ausentes, tarde, sin dato) y el ausentismo del mes (ausencias ÷ registros sin bajas, hasta hoy), y
  se recalcula sobre lo FILTRADO (selector de área + buscador nombre/código). Clic en un nombre = perfil
  (`abrirPerfil`). ⚠️ `renderAsistencia()` se llama también desde `cargarPersonal()` y no hace nada si la
  pestaña aún no cargó su mes.
  EXPORTAR PDF (botón "📄 Exportar PDF", `asExportarPDF()`): abre una ventana nueva (mismo patrón que el
  listado de lockers: `window.open` + `document.write`, avisa si el navegador bloquea pop-ups) con el MISMO
  cuadro del mes y del filtro actuales (`asBuildTabla`, compartida con la pantalla) puesto para carta
  HORIZONTAL (`@page`, encabezado repetido en cada hoja, colores forzados con `print-color-adjust`), con
  título, filtro aplicado, resumen del día y leyenda, y lanza el diálogo de impresión → "Guardar como PDF"
  (el `<title>` "Asistencia diaria YYYY-MM — TETRAPLASTIC" sale como nombre sugerido del archivo). Es el mes
  calendario completo: NO está partido por quincenas como los PDF de Asistencia de Tapas/Serigrafía (esos
  usan el corte de nómina con 2 días del mes anterior); si se necesita, habría que traer también el mes previo.

view-lockers: 86 espacios fijos (`LOCKERS_TOTAL`), SIN tabla propia — la disponibilidad se
  calcula en vivo desde `personal.locker` (personas activas) vía `renderLockers()`, ya
  disparado dentro de `cargarPersonal()`. `parseLockerNum()` extrae el primer número del
  texto libre (tolera "L-14"/"L14"/"14"); lo que no matchea 1–86 se lista aparte en
  `#lockersExtra` sin perderse.
  Clic en CUALQUIER ficha (libre u ocupada) → `abrirModalLocker(numero)`: cuadro de texto
  autorrellenable (`filtrarPersonasLocker`/`seleccionarPersonaLocker`, patrón `.pk-*` propio
  de este archivo — mismo estilo que el autocomplete de SKU en otros módulos, no lo reusa)
  filtra por nombre o código entre las personas activas; dejar el campo vacío = liberar.
  `guardarLocker()` primero desvincula a quien lo tenía (si cambia de dueño) y
  luego escribe `personal.locker = 'L-N'` en la nueva persona — sigue siendo el mismo campo
  de siempre, sin tabla ni lógica de escritura duplicada. Botón "+ Nueva persona" dentro del
  modal (`nuevaPersonaDesdeLocker()`) abre el mismo alta central (`abrirNuevaPersona()`) con
  `mpLocker` precargado a ese número — el área se sigue eligiendo ahí como siempre, no se
  bypasea ese paso. Botón "Ver perfil completo" dentro
  del modal (solo si hay ocupante) para ir al perfil vía `abrirPerfil`.
  Botón "📋 Ver listado" (`verListadoLockers()`) abre, en pestaña nueva, una tabla tipo Excel
  con los 1..`LOCKERS_TOTAL` (Locker/Estado/Nombre/Código/Área/Turno, ocupados en negro y
  disponibles atenuados) para visualizar de un vistazo qué está libre — incluye botón
  "⬇️ Descargar Excel (CSV)" (arma el CSV en el scope de gestion.html con comillas dobladas
  por campo — sin depender de ninguna librería — y lo pasa al popup ya serializado con
  `JSON.stringify(csvText).replace(/</g,'\\u003c')`, para que un nombre con "</script>" o "<"
  no pueda romper el `<script>` inline del popup) y "🖨 Imprimir". Mismo patrón de ventana
  nueva + `document.write()` que las etiquetas de abajo, sin tocar la BD.
  Botón "🖨 Imprimir etiquetas" (`abrirModalImprimirLockers()`) abre primero un modal de
  selección (`modalImprimirLockers`, checkboxes — todos DESmarcados por default, con
  botones "Seleccionar todos"/"Ninguno") para no tener que reimprimir todo el lote cada vez
  que cambia UN locker. La lista (`renderListaImprimirLockers()`) muestra TODOS los 1..
  `LOCKERS_TOTAL`, en dos grupos: "Ocupados" (desde `LOCKERS_OCUPACION`) y "Disponibles"
  (el resto — para poder imprimir una ficha "VACÍO" y pegarla de referencia visual en los
  lockers libres). "🖨 Imprimir" llama a `imprimirEtiquetasLockers(numeros)` ya solo con los
  números elegidos (sin argumento imprime todos los ocupados, para llamadas futuras desde
  otro lado). Cada fila tiene además un `<input>` de texto (no solo un `<span>`) con el
  nombre que dirá esa etiqueta — precargado con `p.nombre` (o "VACÍO" en Disponibles) pero
  editable ahí mismo antes de imprimir (`editarNombreImprimir()` guarda en
  `LOCKERS_NOMBRE_IMPRIMIR{numero:texto}`, capa efímera que NO toca `personal.nombre` en la
  base — solo cambia qué dice el papel impreso). Genera, en una pestaña nueva, una hoja con
  una ficha por locker seleccionado lista para imprimir y pegar en el locker físico — si el
  número no tiene ocupante, la ficha muestra solo "VACÍO" (o el texto editado) centrado
  (sin área/turno). Diseño en escala de grises puro
  (sin color, probado para imprimir bien en blanco y negro): "Locker #N" como chip de
  referencia arriba, NOMBRE en mayúsculas grande (lo que se lee al pasar), línea divisoria,
  ÁREA en mayúsculas grande, y "Turno Alex"/"Turno Gabino" en chico SOLO si
  `area==='produccion'` y tiene `turno_produccion`. Sin código de operador ni ícono por
  área (se probaron ambos y se descartaron a pedido de Álvaro).

view-planta: tarjetas de `mejoras_planta` (CRUD directo, sin ligar a `personal`) — filtros de
  área/estado + buscador de texto (título/descripción), KPI strip propio (Total/Pendientes/
  En proceso/Completadas). Clic en una tarjeta o "+ Nueva mejora" abre `modalMejora`
  (`abrirMejora(id)`/`abrirNuevaMejora()`), mismo patrón de un solo modal reusado para
  crear/editar que `modalPersona` (`mjEditId` null = alta). Campos: título*, área (General/
  Producción/Serigrafía/Tapas/Molino/Bodega/Moldes/Oficina — lista libre, NO ligada al
  `personal_area_check` de la tabla personal), estado (pendiente/en_proceso/completado/
  cancelado), prioridad, responsable, fecha_inicio/fecha_objetivo/fecha_cierre, descripción,
  notas. `toggleFechaCierreMejora()` muestra el campo Fecha de cierre solo si el estado es
  completado/cancelado y la precarga con `fechaHoy()`. Sirve para registrar entregas de
  mobiliario/equipo a planta (ej. sillas nuevas a Producción) además de mejoras en curso.

BARRA DE INDICADORES (arriba de las pestañas, `renderKpis()`; oct/2026): Total activos ·
  Producción Turno Gabino · Producción Turno Alex · Serigrafía · Tapas · Otras áreas (= todo lo
  que no es Tapas/Serigrafía/Producción; el mouse encima muestra el desglose). Solo cuenta
  personas ACTIVAS, vía `conteoActivosPorArea()` (única fuente, también del popup). CLIC en
  "Total activos" → `abrirModalKpiTotal()`: popup con área + cantidad (Producción con sus
  turnos Gabino/Alex y "Sin turno asignado" si alguien no tiene `turno_produccion`) y el total.
  Se QUITARON a pedido de Álvaro Permisos pendientes, EPP pendiente y Faltas sin justificar
  (ya no se consulta `rrhh_permisos` para la barra; las faltas pendientes siguen visibles en la
  tabla y en el perfil → Faltas).

view-personal: grid unificado de TODA la tabla personal (área tapas + serig juntas,
  sin duplicar el CRUD que ya existe en tapas.html/serigrafia.html — es la misma tabla,
  los cambios se ven de inmediato en cualquier módulo). SIEMPRE tabla (buildPersonalTable),
  agrupada por área — ya no hay vista de tarjetas (buildPersonalCard se eliminó).
  Filtros: área (Todos/Tapas/Serigrafía/Producción/Molino/Bodega/Moldes) · buscador
  nombre/código · toggle solo activos.
  `area` acepta 'tapas'/'serig'/'produccion'/'molino'/'bodega'/'moldes'. Molino, Bodega y
  Moldes TODAVÍA NO tienen módulo propio en la app — este registro de personal es la base
  para cuando se construyan, ninguna otra página los lee todavía (mismo caso que
  produccion.html con 'produccion': el módulo real llegó después que el registro de personal).
  ⚠️ `personal` tiene un CHECK constraint `personal_area_check` creado manual en el dashboard
  (no versionado en ningún CREATE TABLE) — hay que mantenerlo sincronizado a mano si se agrega
  otro valor de área nuevo. Ver `sql/personal_area_produccion_v1.sql`,
  `sql/personal_area_molino_bodega_v1.sql` y `sql/personal_area_moldes_v1.sql`.
  Columna `turno_produccion` ('alex'|'gabino', constraint `personal_turno_produccion_check`) —
  SOLO aplica a Producción: el campo "Turno" del modal se muestra/oculta con
  `toggleTurnoWrap()` según el `<select>` de Área (`onchange`), y `guardarPersona()` fuerza
  `turno_produccion=null` si el área no es 'produccion'. Ver `sql/personal_turno_produccion_v1.sql`.
  ⚠️ `personal` YA TENÍA una columna `turno` (texto libre, 'AM' en TODAS las filas de TODAS
  las áreas — ningún HTML del repo la lee/escribe, parece dato viejo sin explotar) — NO es la
  misma columna, NO se toca. `sql/personal_turno_v1.sql` (obsoleto, no correr) intentó reusar
  ese nombre y falló con "check constraint personal_turno_check is violated by some row".
  Antes de agregar cualquier columna nueva a `personal`, verificar primero con
  `select column_name from information_schema.columns where table_name='personal'` que el
  nombre no esté ya en uso — esta tabla se creó y se sigue editando manual en el dashboard,
  sin CREATE TABLE versionado, así que puede tener columnas que no aparecen documentadas acá.
  Columna Turno en la tabla: Producción muestra `turno_produccion` ("Turno Alex"/"Turno
  Gabino"/"—"); Tapas y Serigrafía muestran fijo "Matutino" (mismo turno para todos, no hay
  columna que lo respalde — es solo la etiqueta, no dato editable para esas áreas).
  Encabezado de la tabla con `position:sticky` (no se pierde al hacer scroll).
  Grupos por área desplegables (clic en el header del grupo, `toggleGrupoArea()`) — estado
  en `gruposColapsados{}`, expandido por default; cada grupo es su propio `<tbody>`.
  Columnas Faltas/Justificación: listan cada fecha del MES EN CURSO (rrhh_faltas vía
  `cargarFaltasResumen()`, que ya filtra por mes — una falta sin justificar de un mes
  anterior deja de contar/alertar) con su SI/NO de justificación en la misma fila; clic
  en cualquiera de las dos abre el perfil directo en la pestaña Faltas (`abrirPerfilEnFaltas`).
  ⚠️ Columna "Habilidades" RETIRADA de la tabla (30-sep-2026, a pedido de Álvaro — "aún no se
  usa"): `CAPACITACIONES_RESUMEN`/`cargarCapacitacionesResumen()` y `abrirPerfilEnCapacitaciones()`
  se dejaron intactos (la pestaña Capacitaciones del modal sigue funcionando igual) por si se
  quiere traer de vuelta la columna más adelante — solo falta restaurar el `<th>`/`<col
  class="c-habil">`/`<td class="td-multi">` en `buildPersonalTable()`/`buildPersonalRow()` y
  subir `P_TABLE_COLS` de 12 a 13.
  ROL CON LÍNEA EN SERIGRAFÍA (oct/2026, `rolPersona`/`rolCeldaHtml`, columna "Rol / Proceso"): en el grupo Serigrafía el rol va
  acompañado de un chip con su LÍNEA de color (L1 verde · L2 morado · L3 ámbar · L4 cian), como en la hoja de asistencia
  ("L2 - FLAMEO"). El rol sale de `mtx_rol` (posición normal del tablero de serigrafia.html: manda sobre `proceso_hab`, igual que
  `posKeyDefault` allá; `SERIG_MTX_A_ROL` es el espejo de `MATRIZ_TO_PROCESO`) y la línea de `mtx_linea`. Solo Flameador,
  Impresión y Receptor van por línea; Supervisor, Apoyo y Empaque son generales (sin chip). Flameador/Impresión/Receptor SIN línea
  asignada muestran "L?" punteado (se asigna en el tablero de Serigrafía; Gestión NO edita `mtx_rol`/`mtx_linea`); una persona
  de Serigrafía sin ningún rol muestra "Sin rol" en ámbar (antes decía "Operador"); un Prestado con rol de matriz sale
  "Prestado · Flameador". También aplica a las filas VACANTE (se ve qué línea/rol hay que cubrir). Las demás áreas no cambian.
  El/la supervisor(a) de cada grupo se ordena SIEMPRE primero dentro de su área
  (`ordenSupervisorPrimero()`, orden estable — el resto conserva activo desc/nombre asc) y se
  distingue con "★ " antes del nombre + fondo tenue + nombre en negrita (`tr.p-row.supervisor`).
  PLAZAS VACANTES (oct/2026, `personal.plaza_vacante`, `sql/personal_plaza_vacante_v1.sql`
  = SQL pendiente #31): al dar de baja a alguien, el formulario (Datos generales) muestra la
  casilla "Dejar la plaza vacante" (`actualizarVacanteWrap()`, solo visible si la persona queda
  inactiva). Esa ficha de baja, con la marca, se pinta en el listado "Solo activos" como una
  fila `VACANTE` (`buildFilaVacante()` — rol/proceso, turno y área de quien se fue; SIN
  código/edad/teléfono/locker) y el encabezado del grupo suma "N vacantes". Quién se fue se
  ve SOLO como una línea chica y translúcida bajo VACANTE (`.vac-antes`, opacity .6):
  "Antes: <nombre> · baja <fecha_baja>" — a pedido de Álvaro, para no perder la referencia.
  `esPlazaVacante(p, soloActivos)` es la única condición (marca + inactivo + "Solo activos"
  prendido): con "Solo activos" apagado se ve la ficha de baja normal con nombre + chip "plaza
  vacante". Es una marca EXPLÍCITA a propósito — `personal` tiene decenas de bajas históricas
  que NO deben salir como vacantes. Clic en la fila = `cubrirVacante(id)` (abre el alta con
  área/rol/proceso/turno precargados, `mpCubrirVacanteId`; al guardar, `guardarPersona()` apaga
  la marca de la ficha vieja); "✕ cerrar" = `cerrarVacante(id)` (la plaza ya no se necesita).
  El buscador encuentra vacantes por "vacante", por su proceso o por el nombre de quien se
  fue (el código no se muestra ni se busca). `plaza_vacante` solo viaja en el payload cuando se marca/desmarca, así guardar a
  cualquier otra persona no se rompe si el SQL aún no corrió.
  CUPO DE PRODUCCIÓN (oct/2026, `PLANTILLA_PRODUCCION_TURNO`=19 = 18 operadores + 1 supervisor por turno): en la vista "Solo activos" sin buscador, las vacantes de Producción salen del cupo (19 − activos del turno, contados sobre `personalTodos`) y NO de marcar la casilla — las bajas marcadas conservan su "Antes: …" (`buildFilasProduccionConCupo`), el resto son filas "VACANTE · plaza libre del cupo" (`buildFilaVacanteCupo`, clic = alta con Producción+turno). El encabezado del grupo muestra una pastilla por turno (`pillCupoTurno`): verde completo, ámbar "N vacantes", ROJA "⚠ sobra N" (solo señala, no bloquea ni cambia datos). Los demás grupos siguen con la casilla manual `plaza_vacante`. Si cambia la plantilla, tocar solo esa constante.
  ⚠️ Producción usa un comparador aparte (`ordenProduccionPorTurno()`, elegido en
  `buildPersonalTable()` solo para `a.key==='produccion'`): agrupa primero por
  `turno_produccion` (Gabino, luego Alex — mismo orden que la hoja de asistencia de planta;
  cualquier otro valor/null cae al final) y DENTRO de cada turno aplica el mismo criterio de
  supervisor-primero. Sin esto los dos supervisores de Producción quedaban juntos arriba del
  todo y los operarios de ambos turnos mezclados entre sí.
  Click en fila → modalPersona con 7 sub-tabs:
    Datos generales (editable: nombre/iniciales/código/área/rol/proceso_hab/teléfono/
                     fecha_nacimiento/activo/fechas — la columna "Edad" de la tabla y del
                     modal ya NO se edita como número: se pide fecha_nacimiento y
                     `calcularEdad()`/`edadDePersona()` la calculan en vivo (`mpEdadCalc`
                     bajo el campo, actualizado por `actualizarEdadCalculada()`). La vieja
                     columna `personal.edad` queda de solo-respaldo para quien no tenga
                     fecha_nacimiento cargada todavía — no se vuelve a escribir.)
    RRHH           (editable: locker/talla_uniforme/talla_botas/epp_asignado/epp_fecha/
                     notas_rrhh)
    Capacitaciones (historial rrhh_capacitaciones + registrar nueva — área de la habilidad
                     independiente del área de la persona, estado en_proceso/certificado,
                     comentario del supervisor OBLIGATORIO, foto de respaldo opcional
                     reusando el bucket `justificaciones` con prefijo `capacitacion-<id>`.
                     Si el área de la persona es 'produccion', arriba de la lista muestra un
                     resumen en vivo de `produccion_diaria` — unidades totales y por máquina
                     con `operador_codigo = personal.codigo` — `cargarResumenProduccion()`)
    Permisos       (historial rrhh_permisos + registrar nuevo)
    Faltas         (historial rrhh_faltas con selector de mes, default mes actual — alerta
                     hasta justificar con texto y/o foto; ver sincronización con Asistencia
                     Mensual de serigrafia.html más abajo)
    Incidentes     (historial rrhh_incidentes + registrar nuevo)
    Sueldos y Bonos (historial rrhh_bonos + registrar nuevo — rol_linea impresion/flameado/
                     recepcion/otro, cada uno con sus propios campos condicionales via
                     `toggleCamposBono()`: tiros/unidades + línea (flameado), bolsas de
                     empaque (solo flameado), % merma reportada (solo recepción). Estrategia
                     de incentivos de la línea de Serigrafía: Impresión Q750/día·10k tiros,
                     Flameado Q350/mes·10k unidades+4 bolsas, Recepción Q350/mes pierde si
                     merma>2%. `meta_cumplida`/`monto_bono` siguen siendo decisión MANUAL del
                     supervisor — pero `tiros_unidades` y `merma_pct` tienen botón 🔄 para
                     traerse solos de datos reales:
                     · `traerTirosBono()` — Impresión: suma delta diario de
                       `registro_tiros_serig.contador` (máx-mín por fecha, o la lectura misma
                       si solo hay una — el contador arranca en 0 cada día, mismo criterio que
                       `_trazaDelta()` en serigrafia.html) filtrado por `operador_codigo` =
                       código de la persona. Flameado: mismo cálculo pero filtrado por
                       `linea_id` (select Línea 1-4, precargado desde `personal.mtx_linea` si
                       existe) — el flameador no tiene contador propio, sus unidades se
                       empatan con el contador de la línea completa.
                     · `calcularMermaBono()` — Recepción: `(salida − PT) / salida`, donde
                       salida = suma de `movimientos_materiales` (`area='serig'`,
                       `tipo='salida_bodega'`) y PT = suma de `entregas_serig.cant`, ambas en
                       el rango del período. Es una cifra global de extremo a extremo (no
                       aísla en qué etapa se pierde el envase) — la vista más fina por pedido
                       (Flameado→PT) ya existe en serigrafia.html → Trazabilidad.
                     Período acepta 'YYYY-MM' (mensual) o 'YYYY-MM-DD' (diario) — ambos botones
                     resuelven el rango con `_rangoPeriodoBono()`. Al traer el dato se
                     PRE-marca "Cumplió la meta" contra el umbral oficial, pero sigue editable.)

⚠️ Al editar una persona EXISTENTE desde acá, NO se toca color_hex/mtx_rol/mtx_linea —
  esos campos gobiernan la matriz de líneas del board en serigrafia.html y solo se
  actualizan desde el picker de roles de esa página, para no romper esa sincronización.
  Sí se asigna un color por defecto al CREAR una persona nueva.

Acceso: restringido a rol master vía TETRA_PAGINAS_MASTER en shared/auth.js.
```

## registro-serigrafia.html — Flujos
Ver flujos completos y componentes en `.claude/docs/design-system.md` § Flujos.
Pantallas: `scrTarea(0)` → Impresión / Flameado / Empaque → `scrOk*`.
`mostrarPantalla()` · `buildOpCardGen()` · apoyo externo: `operador_codigo=null + area_origen`.

---

## comandas.html — Historial y aprobación de ingresos (oct/2026)
Acceso desde Tapas: pestaña "📋 Comandas" en la barra (irAComandas) con insignia ámbar "N por aprobar"
(refrescarPendientesComandas); con pendientes abre directo `comandas.html?modo=pendientes`.
Es el HISTÓRICO de cada ingreso: tres modos en la columna izquierda — 📅 Por fecha · 👤 Por operario
(rango de fechas) · ⏳ Por aprobar (cola de TODAS las fechas, con contador) — más filtro de estado
(Todas/Pendientes/Aprobadas/Rechazadas) y buscador; el detalle de cada comanda se edita (✏️) o elimina (🗑).
APROBACIÓN (`sql/comandas_aprobacion_v1.sql`, SQL pendiente #30): `comandas.estado_aprobacion`
('pendiente'|'aprobada'|'rechazada') + `aprobado_por`/`aprobado_en`/`motivo_rechazo`. Lo que registran
operarios/supervisión (registro-tapas.html) y el bot de WhatsApp (`bot_insertar_comanda_tapas`) nace
PENDIENTE (default de la columna); lo que carga el master desde comandas.html (formulario manual e
importador) nace APROBADO (`insertarComanda()`, que reintenta sin esos campos si el SQL aún no corrió).
El existente al correr el SQL queda aprobado (la columna se crea con default 'aprobada' y luego se cambia
a 'pendiente'). En el detalle: banner de estado + ✅ Aprobar / ⛔ Rechazar (pide motivo, obligatorio) /
↩ A pendiente (`cambiarEstadoComanda`). Solo master escribe el estado (política update_master).
SOLO CUENTAN LAS APROBADAS en: termómetro de tapas.html y de registro-tapas.html, Productividad,
KPI de comandas de hoy y dashboard.html — filtro cliente `comandaCuenta(c)` (sin columna = aprobada, así
nada se rompe si el SQL no se ha corrido); las queries traen `select('*, comanda_tareas(...)')` para eso.
Los KPI de comandas.html también suman solo aprobadas ("Und PT aprobadas") y muestran "Por aprobar".
⚠️ El editor ahora conoce los procesos nuevos (Revisado, Limpiar pestaña, Apoyo Serigrafía/Producción)
y conserva cualquier proceso fuera de lista (ej. "Otra tarea: detalle"); antes lo cambiaba a "Armado" al guardar.

## comandas.html — Importar reporte WhatsApp (oct/2026)
Botón "📥 Importar reporte WhatsApp" (junto a "+ Nueva") abre `overlayImportar`, flujo de 2
pasos sobre el mismo modelo comanda+tareas que ya usa el editor manual (una comanda =
operario+fecha, N `comanda_tareas`):
1. Pegar el texto crudo del reporte (`impTexto`) + fecha de referencia (`impFechaRef`,
   default `fechaHoyGT()`) → `analizarReporte()` llama a `api/parse-reporte-tapas.js` con el
   `access_token` de la sesión (`db.auth.getSession()`) en el header `Authorization`.
2. `construirGruposImportacion(filas)` agrupa las filas devueltas por (operario, fecha) en
   `impGrupos`, resolviendo cada operario vía RPC `bot_buscar_operario` y cada descripción vía
   RPC `bot_buscar_sku` — MISMO criterio tolerante que `resolverOperario`/`resolverSku` en
   `api/whatsapp.js` (solo auto-asigna si un candidato cubre todas las palabras y no hay
   empate; si no, deja el texto libre + insignia `.imp-warn`). `renderImportarPreview()`
   pinta una tarjeta por grupo (operario editable, fecha editable, tabla de tareas editable:
   proceso/descripción-SKU/cantidad/método, con `select.dudoso` resaltado en ámbar cuando
   `proceso_dudoso` vino marcado por el parser) — todo corregible antes de guardar, nada se
   inserta en el paso 1. "✅ Guardar todo" (`guardarImportacion()`) filtra tareas sin
   proceso o cantidad≤0 (se excluyen silenciosamente, no bloquean el resto del lote) e
   inserta una `comandas`+N `comanda_tareas` por grupo, reusando `getCapacidad()` ya
   existente — sin duplicar la fórmula de capacidad/horas_efectivas del editor manual.
   TAPA OBLIGATORIA (oct/2026): antes de guardar, si hay líneas sin SKU (insignia roja "sin SKU")
   `guardarImportacion()` pide confirmación con el conteo — aviso, no bloqueo (un reporte trae
   muchas líneas en texto libre). En cambio el editor manual (`guardar()`) SÍ bloquea: toda tarea
   en estado "Terminada" con cantidad>0 necesita un SKU elegido de la lista (borde rojo `.err` +
   foco en la primera); "Asignada"/"En proceso" no lo exigen todavía. ⚠️ Al editar una comanda
   vieja con tareas Terminadas sin SKU, hay que asignarlo para poder guardar.
⚠️ De paso se corrigió un hardcode que quedó de cuando Heidy (T0, inactiva) era supervisora:
  `guardar()` escribía siempre `supervisor_id:'T0', supervisor_nombre:'Heidy'` y el `<select
  id="fSupervisor">` tenía la opción fija "Heidy" — ambos ahora se resuelven en vivo contra
  `personal` (`cargarSupervisorTapas()`, area='tapas' + rol='supervisor' + activo=true, misma
  fuente que ya usa `bot_insertar_comanda_tapas`), igual en el editor manual y en la
  importación. Si Tapas cambia de supervisor otra vez, no hay que tocar código acá.

---

## Tablas Supabase (schema v2.0)
Ver descripciones completas: `.claude/docs/schema-tablas.md`

Notas críticas:
- `produccion_diaria`: llave única incluye `documento` — un turno puede tener varias requis con cantidades que se SUMAN.
  `operador_codigo` (text, default `''`, referencia `personal.codigo` NO `personal.id`) también entra en esa
  llave única (`ux_prod_fecha_turno_maq_sku_doc_op`) — dos filas del mismo día/turno/máquina/sku/documento con
  operarios distintos (ej. relevo de almuerzo cargado aparte) quedan separadas en vez de fusionarse.
  Se asigna por fila en los mismos 3 puntos donde ya se asigna la máquina: preview de PDF (`buildPrevRow`/
  `setPrevOperario`), captura manual (`addManRow`/`guardarManual`), y el modal post-guardado
  ("✏️ Máquinas / Operarios" → `abrirModalMaq`/`renderModalMaq`/`guardarMaquinas`). `guardarTurno()` agrupa
  por `maquina|sku|operador` (antes solo `maquina|sku`). `PERSONAL_PROD` (cargado en `init()` vía
  `cargarPersonalProd()`, personal activo de area='produccion') alimenta el `<select>` en los 3 sitios
  vía `buildOperarioOptions()`. gestion.html → Personal → pestaña Capacitaciones lee esta columna para
  mostrar unidades producidas por operario (ver arriba).
- `inventario`: +3 cols producción: `meta_12hrs`, `maquina_default`, `precio_ponderado_manual`
- `personal`: fuente única de supervisores — registro-tapas.html NO los hardcodea. +5 cols RRHH
  (`locker`, `talla_uniforme`, `epp_asignado`, `epp_fecha`, `notas_rrhh`) gestionadas desde gestion.html.
  `fecha_inicio`/`fecha_baja` son GENÉRICAS (no solo de Serigrafía) — gestion.html → Personal →
  Datos generales las edita para cualquier área; exportarAsistGridPDFTapas (tapas.html) también
  las usa desde sep/2026 (ver view-inicio arriba).
- `rrhh_permisos` / `rrhh_incidentes`: historial por persona (FK `personal_id` uuid), master-only
  lectura+escritura (RLS). Gestionadas desde gestion.html
- `mejoras_planta`: seguimiento de infraestructura — vista en gestion.html → Planta (ver arriba)
- `ventas`: fecha→DATE, RLS master-only escritura; importador reemplaza por rango de fechas (sin duplicar)
- `bot_estado`: 1 fila por número (`whatsapp_from` UNIQUE)
- `rechazos`: RLS activo con 4 políticas (verificado en la base 2026-10-09)
- `movimientos_insumos`: destino de bodega.html/molino.html (`area`='bodega'|'molino'), separada de
  `movimientos_materiales` (esa es de tapas/PT) para no forzar campos que no aplican (ej. `solicitud_id`).
  Lectura abierta a cualquier autenticado (soporta visor), escritura master-only. Ver
  `.claude/docs/contexto-bot-requis.md` para el mapeo completo de prefijos SICAF → esta tabla.
- `asistencia_diaria`: llave única (`fecha`,`operador_codigo`,`area`,`turno`) vía upsert onConflict.
  `area` ahora acepta 'tapas' además de 'serig' (sql/asistencia_area_tapas_v1.sql, sep/2026) — Tapas
  la usa desde view-inicio de tapas.html, con `turno` siempre 'dia' (sin turno noche en Tapas).
- `dias_feriados`: GLOBAL, sin columna `area` — un feriado aplica a toda la empresa por igual,
  Tapas y Serigrafía leen/escriben la misma tabla sin distinción.

### RPCs atómicas
- `descontar_inventario(p_sku, p_cantidad)` — usar en lugar de select+update manual.
  ⚠️ Recorta en 0 (`GREATEST(0, existencia - cantidad)`): nunca deja negativo, así que un
  descuadre (salida mayor a lo que el sistema tiene) queda oculto.
- `aumentar_inventario(p_sku, p_cantidad)` — ídem. ⚠️ Si el SKU no existe lo CREA (upsert con
  descripción "Producto terminado · pendiente descripción", facturable). Ninguna de las dos tiene
  el SQL versionado en `sql/` — definición leída de la base en oct/2026. No hay RPC equivalente
  para `insumos_b7`.

---

## SQL pendiente de correr en Supabase (dashboard → SQL Editor)
1. ~~`sql/rechazos_rls_fix.sql`~~ — YA CORRIDO (verificado 2026-10-09: RLS activo, 4 políticas)
2. `sql/operativo_tapas_v1.sql` — rol `operativo` + usuario tapas@tetrapp.app + políticas INSERT + trigger CMD-###
3. `sql/registro_procesos_serig_v1.sql` — crea registro_flameado_serig + registro_empaque_serig con RLS
4. `sql/ventas_financiero_v1.sql` — prepara tabla `ventas`: familia/codigo_cliente, fecha→DATE, RLS master
5. `sql/produccion_v1.sql` — crea `produccion_diaria` + cols meta_12hrs/maquina_default/precio_ponderado_manual
6. `sql/produccion_seed_historico.sql` — histórico Sheets (831 líneas, 5-may→6-jun, documento='SHEETS').
   Correr DESPUÉS del 5. ⚠️ Si luego subes PDF de un turno ya sembrado, borra primero sus líneas con documento='SHEETS'
7. `sql/sku_especificaciones_v1.sql` — tabla `sku_especificaciones` (ficha técnica extensible por
   SKU+área: Fase 2 del Recetario unificado — peso/material/colorante en Producción, tiros/colores/
   fórmula de tinta en Serigrafía, familia/accesorios en Tapas). RLS igual a `sku_recetas` (master).
8. `sql/operativo_produccion_v1.sql` — rol `operativo_prod` + usuario produccion@tetrapp.app +
   políticas insert/update/delete en produccion_diaria. Correr DESPUÉS del 5 (necesita la tabla).
9. `sql/personal_area_moldes_v1.sql` — agrega 'moldes' al CHECK constraint `personal_area_check`.
10. `sql/rrhh_capacitaciones_v1.sql` — tabla `rrhh_capacitaciones` (habilidades/certificaciones,
    columna Habilidades en gestion.html → Personal) + pestaña Capacitaciones del modal. Reusa
    el bucket Storage `justificaciones` (ya creado) para la foto de respaldo — sin bucket nuevo.
11. `sql/v_solicitudes_security_invoker_v1.sql` — ⚠️ parcial: `v_solicitudes` confirmado con
    `security_invoker=true`; falta correr la línea de `v_capacidad_hoy` (queda comentada en el
    archivo) si el Security Advisor también la marcó.
12. `sql/produccion_operario_v1.sql` — columna `operador_codigo` en `produccion_diaria` +
    reemplaza el índice único para incluirla. Sin esto, asignar operario en produccion.html
    falla (columna no existe) y "✏️ Máquinas / Operarios" no carga esa columna.
13. `sql/rrhh_bonos_v1.sql` — tabla `rrhh_bonos` (Sueldos y Bonos en gestion.html → Personal).
14. `sql/movimientos_insumos_v1.sql` — tabla `movimientos_insumos` (destino de bodega.html/molino.html).
    Sin esto, ambos módulos cargan pero no pueden registrar ni ver movimientos.
15. `sql/bot_buscar_sku_v2.sql` — arregla `bot_buscar_sku` (nunca se había creado en producción,
    ver § Funciones serverless) + tildes/plural + filtro facturable/Bodega 2. Correr ANTES del 16.
16. `sql/bot_sku_palabras_clave_v1.sql` — tabla `sku_palabras_clave` (apodos entrenables por SKU)
    + reemplaza `bot_buscar_sku` sumando esos alias a la búsqueda. Autocontenido (no depende del 15).
17. `sql/bot_tapas_v1.sql` — RPCs `bot_buscar_operario` y `bot_insertar_comanda_tapas` para que
    api/whatsapp.js registre producción de Tapas (comandas+comanda_tareas) por WhatsApp.
18. `sql/supervisor_tapas_v1.sql` (v1.1) — rol `supervisor_tapas` + política INSERT en
    comandas/comanda_tareas. REPROPÓSITA `tapas@tetrapp.app` (rol pasa de `operativo` a
    `supervisor_tapas`) — no crea cuenta nueva. Antes de correrlo, restablecer la contraseña
    de esa cuenta en Authentication → Users y dársela solo a Yenifer.
19. `sql/asistencia_area_tapas_v1.sql` — permite area='tapas' en `asistencia_diaria` (fix
    defensivo del CHECK constraint, igual patrón que personal_area_*). Sin esto, la Asistencia
    Mensual de Tapas (view-inicio) puede fallar al guardar con "violates check constraint".
20. `sql/fix_duplicados_karen_blandina_v1.sql` — desactiva las filas duplicadas de Karen
    Hernández y Blandina Solares en `personal` (quedaron con 2 filas cada una, codigo distinto,
    probablemente por crear "+ Nueva persona" desde un locker vacío en vez de encontrarlas con
    el buscador — ver nota abajo). Traslada el Locker L-13 a la ficha correcta de Blandina.
21. `sql/sku_recetario_operativo_prod_v1.sql` — abre escritura del Recetario
    (`sku_recetas`/`sku_receta_partes`/`sku_especificaciones`) al rol `operativo_prod`, además de
    master (antes solo master). Sin correr este SQL, el Recetario sigue bloqueado para Producción
    aunque el código cliente ya lo permita — RLS lo rechaza.
22. `sql/realtime_produccion_v1.sql` — agrega `produccion_diaria` a la publicación
    `supabase_realtime` (mismo patrón que `sql/realtime_serig.sql`). Sin correr esto, Inicio e
    Ingreso de produccion.html siguen funcionando pero sin refresco en vivo entre usuarios/equipos
    (hay que recargar). ⚠️ produccion.html NO refresca al volver a la pestaña/ventana (se quitó
    oct/2026: quien copia de un Excel y regresa perdía lo que llenaba); Recetario nunca se refresca solo.
23. `sql/moldes_v1.sql` — tabla nueva `moldes` (catálogo de moldes de Producción: nombre,
    cavidades, ciclo_seg) + RLS + 88 moldes importados de "MOLDES Y CICLOS - SEP 2026.xlsx".
    Alimenta el autocompletado de Molde/Cavidades en el Recetario (produccion.html). Sin correr
    esto, esos dos campos nuevos quedan como texto libre sin sugerencias ni alta automática.
24. `sql/personal_nacimiento_botas_v1.sql` — columnas `fecha_nacimiento` (reemplaza a `edad`,
    que ahora se calcula en vivo) y `talla_botas` en `personal`. Sin correr esto,
    gestion.html → Personal falla al guardar esos dos campos nuevos.
25. `sql/personal_area_mantenimiento_torno_v1.sql` — agrega 'mantenimiento'/'torno' al CHECK
    constraint `personal_area_check`. Correr ANTES del 26 (lo necesita).
26. `sql/reconciliacion_hoja_asistencia_v1.sql` (oct/2026) — reconciliación puntual de
    `personal` contra la hoja "ASISTENCIA DE PLANTA" (Google Sheets, ver nota abajo):
    recodifica el choque p-57/P-57, da de baja a Holger Baleu y Miriam Cano, reactiva a
    Karen Hernández en Tapas (quedó mal desactivada), reclasifica a Gerardo González y
    Josué Gamaliel Choc a Mantenimiento y a Ludwin Alvarez Pérez a Torno, y corrige
    `fecha_inicio` de ~60 personas con la fecha de ingreso real de la hoja.
27. `sql/personal_area_oficina_v1.sql` — agrega 'oficina' al CHECK constraint
    `personal_area_check`. Correr ANTES del 28 (lo necesita).
28. `sql/reconciliacion_hoja_asistencia_v2.sql` (oct/2026) — segunda parte de la
    reconciliación: código `T3` pasa de la ficha vieja de Elsa Tul (se BORRA, a pedido
    explícito de Álvaro) a Glenda Sequen; agrega 8 personas que estaban en la hoja y no
    en `personal` (Henry Mejía en Moldes, Luis González en Mantenimiento, Fox en Torno,
    y 5 personas de Oficina/Administración — incluido el propio Álvaro).

29. `sql/solicitud_lineas_componentes_tapas_v1.sql` (oct/2026) — columnas `sku_contratapa`, `sku_liner`, `sku_banda` (y `sku_base` por si faltara) en `solicitud_lineas`. Sin correrlo, el formulario de Tapas no puede guardar una ficha que lleve Contratapa, Liner o Banda.

30. `sql/comandas_aprobacion_v1.sql` (oct/2026) — columnas de aprobación en `comandas` (estado_aprobacion/aprobado_por/aprobado_en/motivo_rechazo). Sin correrlo: no se puede aprobar/rechazar (el botón avisa) y todo cuenta como aprobado.

31. ✅ YA CORRIDO (confirmado 9-oct-2026: Elizabeth Oliva P-41 y Lesly Rojas t-18 salen marcadas) —
    `sql/personal_plaza_vacante_v1.sql` (oct/2026) — columna `plaza_vacante` en `personal` +
    deja marcada como vacante la plaza de Lesly Rojas (Serigrafía, `t-18`, dada de baja). Sin
    correrlo, la casilla "Dejar la plaza vacante" avisa que falta el SQL y no guarda.

32. `sql/tareas_diarias_v1.sql` (oct/2026) — tabla `tareas_diarias` (inventario AM/PM que escribe bodega.html al importar + omisiones de la guía). Sin correrlo la guía cae al `localStorage` del equipo para el inventario y "Omitir hoy" avisa que falta el SQL.

33. ✅ CHECK YA CORRIDO (verificado 10-oct-2026: `asistencia_diaria_area_check` admite las 9 áreas; la columna `personal.nombre_hoja` NO se verificó) — `sql/asistencia_drive_v1.sql` (oct/2026) — amplía el CHECK de `asistencia_diaria.area` a todas las áreas + columna `personal.nombre_hoja`. Además requiere la variable de Vercel `ASISTENCIA_SHEET_ID` (id de la hoja; la hoja debe estar compartida como LECTOR por enlace). Sin el SQL, Tapas/Serig sincronizan y las demás áreas avisan del error.

34. ✅ YA CORRIDO (verificado 13-oct-2026: ambos CHECK admiten 'limpieza') — `sql/personal_area_limpieza_v1.sql` (oct/2026) — agrega 'limpieza' a los DOS CHECK (`personal_area_check` y `asistencia_diaria_area_check`). Sin esto no se puede dar de alta a Irma Azucena Ulicia Arias (única colaboradora de Limpieza) en Gestión y la sincronización con el Drive falla al guardar la asistencia de esa área. Orden: correr el SQL → Gestión → "+ Nueva persona" (Área Limpieza, código sugerido LI-01, nombre igual al de la hoja) → Inicio → "Sincronizar ahora".

35. `sql/tapas_lotes_v1.sql` (oct/2026) — tabla `tapas_lotes` (solicitud_id, cantidad, marcado_por, marcado_en) + RLS: lectura con perfil; insert/update/delete para master, supervisor_tapas y operativo (primera escritura de esos roles fuera de comandas). Sin correrlo, la pestaña Pedidos de registro-tapas.html se ve pero no deja marcar pedidos en proceso.

36. `sql/tapas_lote_tareas_v1.sql` (oct/2026) — tabla `tapas_lote_tareas` (lote_id → tapas_lotes, proceso, operario_codigo/nombre, iniciado_en) + RLS igual que `tapas_lotes`. Correr DESPUÉS del 35. Sin correrlo, la pestaña Pedidos marca lotes pero no registra qué operario inicia qué proceso.

37. `sql/solicitudes_plazo_tipo_v1.sql` (oct/2026) — columna `solicitudes.plazo_tipo` ('fecha'|'parciales'|'pendiente', default 'fecha') + quita el NOT NULL de `fecha_limite`. Sin correrlo, elegir "Entregas parciales"/"Pendiente" en el formulario o en el popup de plazo falla y avisa qué SQL falta; las fichas con fecha siguen funcionando igual.

38. `sql/sku_recetas_cliente_v1.sql` (oct/2026) — tabla `sku_recetas_cliente` (sku, cliente, area, partes jsonb) con RLS igual que `sku_recetas` (lectura con perfil; master u operativo_prod escriben). Sin correrlo, no se puede guardar una receta distinta por cliente (el botón "Guardar solo para <CLIENTE>" avisa) y el autorrelleno sigue usando solo la receta general.

39. `sql/maquinas_v1.sql` (oct/2026) — tabla `maquinas` (catálogo: nombre, corto, tipo, marca, modelo, centro, estación, referencia, foto, orden, activa) con las 20 variantes que van en los desplegables de Ingreso y Central de Ingreso. `produccion_diaria.maquina` NO cambia (smallint = `maquinas.id`): 1-5, 7 y 10 conservan su id; las dobles pasan a E1/E2 (ids 61/62, 81/82, 91/92) y los ids viejos 6/8/9 quedan 'histórico' (activa=false, sin adivinar la estación de las filas viejas); inyectoras 21-27; 11/12 'sin_definir' (el reporte las sigue ignorando). Sin correrlo, produccion.html usa una copia mínima en JS (`MAQ_FALLBACK`) y funciona igual pero sin marca/modelo; index.html cae a los números de siempre y gestion.html a "Máquina N".

### ⚠️ Duplicados en `personal` — causa probable y cómo evitarlos
`personal.codigo` es UNIQUE, así que un duplicado real son DOS filas con códigos distintos
para la misma persona (no un simple typo de UI) — confirmado con Karen Hernández y Blandina
Solares (sep/2026): cada una terminó con una fila en Tapas y otra en Serigrafía. Causa más
probable: `nuevaPersonaDesdeLocker()` en gestion.html (Lockers → clic en un locker vacío →
"+ Nueva persona") crea SIEMPRE una persona nueva — si quien lo usa no confirma primero con
`filtrarPersonasLocker()` que la persona no existe ya (con otra área/código), queda duplicada.
Antes de usar "+ Nueva persona" desde un locker, buscar primero por nombre en el cuadro de
autocompletar del locker; si aparece, usar `seleccionarPersonaLocker()` en vez de crear otra.

⚠️ El código también choca con PERSONAS DE BAJA: una ficha inactiva sigue ocupando su `codigo`
(el listado oculta inactivos por defecto, así que se ve "libre" y no lo está). Desde oct/2026
el alta de gestion.html lo previene: `siguienteCodigoLibre(area)` sugiere solo el próximo
código libre del área (prefijos en `AREA_PREFIJO_CODIGO`: P-/T-/S-/M-/B-/MT-/TO-/OF-, máximo
usado + 1 sobre TODAS las filas, sin distinguir mayúsculas — evita p-57 vs P-57; 2 dígitos en
B/M/MT/TO/OF como B-03, sin ceros en P/T/S), `cambiarAreaPersona()` la actualiza al cambiar
el área mientras no se haya escrito otro código a mano, y `guardarPersona()` avisa QUIÉN tiene
el código escrito (y si está de baja) en vez de mostrar el error crudo `personal_codigo_key`.
Las áreas `mantenimiento`/`torno`/`oficina` (agregadas en la reconciliación) y `limpieza` (oct/2026, prefijo `LI-`, 2 dígitos, sin módulo propio)
ya están también en el selector de Área, los filtros, la agrupación de la tabla y los colores por defecto.

### SQL ya corridos (solo si necesitas re-correr)
- `sql/seguridad_v1.sql` ⚠️ Su sección C borra TODAS las políticas y recrea solo las genéricas — después hay que re-correr los fix específicos (insert_operativo_serig etc.)
- `sql/fix_rls_serig_v2.sql` — reparó registro_tiros_serig RLS + columna hora + CHECK velada
- `sql/solicitudes_parcial_constraint.sql` (19-ago-2026) — CHECK de estado en `solicitudes`
  y `solicitud_lineas` limitado a los 4 oficiales; habilita `parcial`, elimina `programada`/`entregada`
- `sql/sku_recetario_fotos_v1.sql` (24-ago-2026) — columna `foto_url` en `sku_recetas` + bucket Storage `envases`
- `sql/gestion_v1.sql` (27-ago-2026) — tablas `mejoras_planta`/`rrhh_permisos`/`rrhh_incidentes` + cols RRHH en `personal`
- `sql/personal_edad_v1.sql` (27-ago-2026) — columna `edad` (smallint) en `personal`
- `sql/rrhh_faltas_v1.sql` (27-ago-2026) — tabla `rrhh_faltas` (incluye columna `origen`) + políticas RLS del bucket `justificaciones`
- `sql/dias_feriados_v1.sql` (27-ago-2026) — tabla `dias_feriados`; bucket Storage `justificaciones` confirmado creado
- `sql/personal_area_produccion_v1.sql` (28-ago-2026) — agrega 'produccion' al CHECK constraint `personal_area_check`
- `sql/personal_turno_produccion_v1.sql` (28-ago-2026) — columna `turno_produccion` ('alex'|'gabino') en `personal`
- `sql/personal_area_molino_bodega_v1.sql` (29-ago-2026) — agrega 'molino'/'bodega' al CHECK constraint `personal_area_check`
- `sql/planos_v1.sql` (13-oct-2026) — tabla `planos` (versiones del plano de planta) + bucket Storage `planos`, RLS master escribe / con perfil lee

---

## Seguridad — estado
Sólido: sin secretos hardcodeados; CSP + HSTS + X-Frame-Options en vercel.json (CSP incluye
`worker-src 'self' blob: cdnjs` para el worker de pdf.js, y `wss://` de Supabase en `connect-src` para
Realtime — sin él, el tiempo real de produccion.html/serigrafia.html quedaba bloqueado, hasta oct/2026); auth.js centralizado; anon sin privilegios;
api/whatsapp.js valida firma Twilio (fail-closed); los 3 endpoints de IA (`parse-doc`, `parse-requi`,
`parse-reporte-tapas`) exigen sesión vía `api/_auth.js` (oct/2026 — antes `parse-doc` estaba abierto).
Auditoría oct/2026: se escapó con `escHtml()` la descripción de feriados (texto libre de `prompt()`)
que iba sin escapar a `title="..."` en tapas.html y serigrafia.html.
⚠️ Pendiente: confirmar que `TWILIO_AUTH_TOKEN` existe en Vercel env vars (sin ella el bot rechaza todo).
⚠️ Conocido, bajo riesgo: los `onclick` arman `personal.codigo` solo escapando `'` (códigos los pone
master); el filtro de escrituras de `operativo_prod` en auth.js compara la URL por prefijo — RLS es la
barrera real.

## Roles de acceso (shared/auth.js)
- `master` → todo · `visor` → solo lectura (banner Modo Visual)
- `operativo` → enjaulado en registro-tapas.html; INSERT solo en comandas/comanda_tareas
- `operativo_serig` → enjaulado en registro-serigrafia.html; INSERT en registro_tiros_serig, paros_serig, registro_flameado_serig, registro_empaque_serig
- `operativo_prod` → NO enjaulado: ve TODOS los módulos en lectura (como visor), pero solo escribe en `produccion_diaria` (registrar turnos) y en el Recetario (`sku_recetas`/`sku_receta_partes`/`sku_especificaciones`, sep/2026 — mismo alcance que master ahí). auth.js bloquea escrituras a cualquier otra tabla (flag TETRA.esProdEditor + TETRA_PROD_TABLA + TETRA_PROD_TABLAS_EXTRA); RLS lo respalda (ver `sql/sku_recetario_operativo_prod_v1.sql`). Exento de logout por inactividad.
- `supervisor_tapas` → enjaulado en registro-tapas.html (comparte la misma página con `operativo`, no es un módulo nuevo). Piloto (sep/2026): se REPROPÓSITA la cuenta que ya existía (`tapas@tetrapp.app`, antes rol `operativo`) para que ahora sea de la supervisora (Yenifer) — los operarios YA NO tienen acceso a ese login (se les cambió la contraseña); cuando se restaure su participación se creará una cuenta nueva aparte, no esta. Mismo alcance de escritura que `operativo` (solo INSERT en comandas/comanda_tareas). Ver `sql/supervisor_tapas_v1.sql`. Próxima área candidata: Serigrafía (sin tocar todavía).
- La jaula vive en TETRA_PAGINAS_OPERATIVO (auth.js): rol → página permitida
- TETRA_PAGINAS_MASTER (auth.js): páginas restringidas SOLO a master (ej. `gestion`) — cualquier
  otro rol es redirigido a index.html antes de revelar contenido (dato sensible de RRHH)
- Sesiones expiran a 60 min de inactividad, EXCEPTO roles operativos (pantallas de planta)
- ⚠️ Todo `signOut()` va con `{ scope: 'local' }` (oct/2026). El default de supabase-js v2 es
  'global' y cerraba la sesión del usuario en TODOS sus equipos: un celular o pestaña dormida que
  expiraba por inactividad dejaba a la PC con un token "zombi" (lee tablas, pero `api/*` responde
  401 porque `auth/v1/user` da 403 → "tu sesión venció" en la sincronización del Drive).

---

## Metas de productividad — CUATRO tablas, sincronizadas jul/2026
Valores oficiales (und/hora):
- Armado, Liner, Banda (manual): **1500** · Encajado: **3000**
- Flameado, Impresión: **1500** · Armado, Liner (máquina — Press Top 28/33): **2500**
- Resto (Revisado, Limpiar pestaña, Apoyo Serig, Apoyo Prod, Otra tarea, sin meta): **1200**

Las 4 copias (misma lógica, autónomas por arquitectura):
1. `CAPACIDADES` en registro-tapas.html — rol operativo
2. `CAPACIDADES` en comandas.html — vista admin
3. `METAS` + `META_DEFAULT` en tapas.html — estima tiempo de entrega de solicitudes
4. `METAS` + `META_DEFAULT` en dashboard.html — calcula eficiencia real en KPIs ejecutivos

⚠️ Al agregar una tarea nueva: actualizarla en las 4 tablas (o confirmar que cae en default 1200).

---

## Reglas de trabajo OBLIGATORIAS
1. **Diagnóstico primero**: antes de modificar cualquier archivo, mostrar diagnóstico y esperar aprobación explícita.
2. **Sin template literals anidados**: usar funciones helper separadas (ej: `buildRechazoRow(r)`).
3. **No duplicar lógica de DB** entre módulos.
4. **Confirmar archivo base** antes de editar (especialmente tapas.html — es el más largo).
5. **Git siempre a ambas ramas**: `git push origin master && git push origin master:main`
6. **Verificar referencias eliminadas**: tras borrar IDs o funciones, grep para confirmar que no quedan usos huérfanos.
7. **var sobre const/let** en funciones globales de tapas.html (evitar errores de redeclaración entre módulos cargados múltiples veces).
9. **Varias sesiones de Claude comparten este mismo directorio y la misma rama** (Gestión, Seguridad,
   Ventas, Tapas, Serigrafía…), así que lo "sin commitear" que aparece en `git status` puede ser de otra
   sesión. Siempre: (a) correr `git status` y `git diff --stat` antes de commitear y dejar lo que no
   sea tuyo; (b) NUNCA `git add .` / `git add -A` / `git commit -a` — stagear por NOMBRE de archivo, y si
   un archivo compartido (CLAUDE.md) trae cambios ajenos, stagear solo tu bloque con
   `git apply --cached --unidiff-zero` sobre un parche de tu hunk; (c) agregar al mensaje del commit una
   línea `Sesión: <título de la sesión>` justo antes del trailer `Co-Authored-By` — así
   `git log` responde de dónde vino cada cambio (el autor siempre sale "Alvaro Mendoza" y el trailer
   solo distingue el modelo); (d) no versionar `BOM_Componentes_Tapas.xlsx` ni archivos de datos de
   negocio sin preguntar. Esta regla se carga al INICIAR una sesión: las que ya estaban abiertas no la ven.
8. **Fecha "hoy" SIEMPRE con `fechaHoy()`** — NUNCA `new Date().toISOString().slice(0,10)`: devuelve fecha UTC y Guatemala es UTC-6, después de las 18:00 marca el día siguiente. `toISOString()` solo válido sobre fechas ancladas a mediodía o para timestamps completos.

---

## Personal
Supervisora tapas: **Yenifer Leisi Lopez Espinal** (`T1`, activa) — ya corregida en `personal`
(el registro viejo con "Heidy" quedó como `codigo='T0'`, inactivo, sin borrar).
Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores.

### Referencia externa — "ASISTENCIA DE PLANTA" (Google Sheets)
Álvaro lleva un control de asistencia diaria de TODA la planta en Google Sheets (fuera de
TETRAPP, él la comparte por link cuando hace falta) — una pestaña por mes, agrupada por
Supervisor/Turno/Línea con un ✅/❌ por persona y día. Cubre MÁS áreas que TETRAPP: además de
tapas/serig/producción(turnos Alex y Gabino)/molino/bodega/moldes, tiene **Mantenimiento**,
**Torno** y **Oficina/Administración** (estas tres sin módulo ni tabla en TETRAPP todavía).
Es más confiable que `personal` para nombre completo, fecha de ingreso real y supervisor
correcto — se usó como fuente de verdad para `sql/reconciliacion_hoja_asistencia_v1.sql`
(oct/2026). Sin API ni credenciales de Google configuradas en el proyecto — cualquier
comparación contra ella hoy es manual (Claude la lee por navegador, el usuario pega el dump
de `personal` para comparar). Sincronización automática de asistencia diaria (no solo del
roster) quedó evaluada pero no construida — necesitaría una integración nueva con la API de
Google Sheets.
