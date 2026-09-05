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
  ⚠️ Valida firma `X-Twilio-Signature` (HMAC-SHA1, fail-closed) — sin `TWILIO_AUTH_TOKEN` rechaza TODO POST.
  Env: ANTHROPIC_API_KEY, SUPA_URL, SUPA_SERVICE_KEY, TWILIO_AUTH_TOKEN (obligatorio), TWILIO_WEBHOOK_URL, TETRA_WA_ALLOW.
- `api/parse-doc.js` — parsea foto de requi con Claude Vision → JSON {requi, fecha, productos[]}.
  ⚠️ PENDIENTE: CORS `*` + sin auth → gasto de tokens de Claude. Falta gatear con JWT de sesión.

### Módulos activos
| Archivo | Descripción |
|---|---|
| `index.html` | Fachada principal — 8 cards de módulo |
| `tapas.html` | Módulo completo Tapas: hub + pedidos + movimientos (salidas/ingresos/rechazos) + personal |
| `serigrafia.html` | Módulo admin Serigrafía: Inicio (board) + Movimientos + Productividad + Personal |
| `registro-serigrafia.html` | Formulario móvil rol `operativo_serig`: Flameado / Impresión / Empaque |
| `comandas.html` | Registro de producción diaria por operario (vista admin) |
| `registro-tapas.html` | Formulario móvil rol `operativo`: comanda concluida, correlativo CMD-### vía trigger DB |
| `dashboard.html` | KPIs ejecutivos globales |
| `ventas.html` | Ventas y Financiero: Resumen · Productos · Clientes · Rotación · Importar facturación (Excel/CSV cols A-R) · toggle IVA |
| `produccion.html` | Sopladoras: Ingreso PDF/manual (pdf.js) · Reporte Semanal (pivote máquina×SKU) · Mensual. Asigna máquina Y operario por fila (`personal` area='produccion') |
| `gestion.html` | Gestión de Personal y Planta: tabla unificada tapas+serig+producción+molino+bodega+moldes sobre la misma tabla `personal` + RRHH (locker/EPP/talla) + permisos/incidentes/faltas/capacitaciones/bonos + Lockers + Planta (mejoras_planta, CRUD simple por tarjetas). Master-only. |
| `bodega.html` | Bodega — Inicio (KPIs) · **Existencias** (ex-`inventario.html`, integrado sep/2026: catálogo Bodega 02/05/07, tablas `inventario`+`insumos_b7`, importación Excel, alertas de bajo stock) · Movimientos (`movimientos_insumos`, área='bodega', destino de los prefijos SICAF `MPI`/`MPS`) · Personal. `inventario.html` ahora es solo un redirect a `bodega.html#existencias` (no borrado, por si hay bookmarks/PWA viejos). |
| `molino.html` | Molienda/mezcla/distribución de materia prima a máquina: mismo patrón que bodega.html (Inicio · Movimientos `área='molino'` · Personal). Alcance MVP — no modela todavía fórmulas ni distribución por máquina, ver `.claude/docs/contexto-bot-requis.md`. |

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
switchTab(tab) controla qué view se muestra.
'rechazos' es ALIAS → switchTab('movimientos') + setMovVista('rechazos')

view-inicio      HUB default: 4 KPIs + 5 sub-cards (Pedidos/Procesos/Personal/Rechazos/Dashboard)
view-tapas       Solicitudes — split pane: lista + detalle
view-movimientos Segmented control de 3:
  [📤 Salidas de Bodega] [📦 Ingresos PT] [⛔ Rechazos]
  Comparten: movDesde/movHasta, movBuscar, kpi-strip (mkpi-v1..v4), movTabla
  setMovVista('salida'|'ingreso'|'rechazos') actualiza todo
  movRegistrar() delega a abrirModalMov() o abrirModalRechazo()
view-personal    Grid de operadores
```

## serigrafia.html — Arquitectura de vistas

```
Tabs: Inicio · Movimientos · Productividad · Personal · Dashboard (link)
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
Tabs: Personal (activo) · Lockers (activo) · Planta (activo)

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
  Botón "🖨 Imprimir etiquetas" (`abrirModalImprimirLockers()`) abre primero un modal de
  selección (`modalImprimirLockers`, checkboxes sobre `LOCKERS_OCUPACION` — todos
  DESmarcados por default, con botones "Seleccionar todos"/"Ninguno") para no tener que
  reimprimir las 86 fichas cada vez que cambia UN locker; "🖨 Imprimir" llama a
  `imprimirEtiquetasLockers(numeros)` ya solo con los números elegidos (sin argumento
  imprime todos los ocupados, para llamadas futuras desde otro lado). Genera, en una pestaña
  nueva, una hoja con una ficha por locker seleccionado lista para imprimir y pegar en el
  locker físico. Diseño en escala de grises puro (sin color, probado para imprimir bien en
  blanco y negro): "Locker #N" como chip de referencia arriba, NOMBRE en mayúsculas grande
  (lo que se lee al pasar), línea divisoria, ÁREA en mayúsculas grande, y "Turno Alex"/"Turno
  Gabino" en chico SOLO si `area==='produccion'` y tiene `turno_produccion`. Sin código de
  operador ni ícono por área (se probaron ambos y se descartaron a pedido de Álvaro).
  Lockers libres no generan ficha (nada que identificar todavía).

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
  Columna Habilidades: lista cada capacitación (ícono ✅ certificado / 🕐 en proceso +
  habilidad, con el área entre paréntesis SOLO si es distinta al área de la persona — ej.
  alguien de Tapas certificado para cubrir una máquina de Producción en almuerzo). Clic abre
  el perfil directo en la pestaña Capacitaciones (`abrirPerfilEnCapacitaciones`).
  Click en fila → modalPersona con 7 sub-tabs:
    Datos generales (editable: nombre/iniciales/código/área/rol/proceso_hab/teléfono/edad/activo/fechas)
    RRHH           (editable: locker/talla_uniforme/epp_asignado/epp_fecha/notas_rrhh)
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
- `personal`: fuente única de supervisores — registro-tapas.html NO los hardcodea. `area` es 1:1
  por persona (solo valores `'tapas'`/`'serig'` — produccion.html no usa esta tabla). +5 cols RRHH
  (`locker`, `talla_uniforme`, `epp_asignado`, `epp_fecha`, `notas_rrhh`) gestionadas desde gestion.html
- `rrhh_permisos` / `rrhh_incidentes`: historial por persona (FK `personal_id` uuid), master-only
  lectura+escritura (RLS). Gestionadas desde gestion.html
- `mejoras_planta`: seguimiento de infraestructura — tabla lista, vista pendiente en gestion.html
- `ventas`: fecha→DATE, RLS master-only escritura; importador reemplaza por rango de fechas (sin duplicar)
- `bot_estado`: 1 fila por número (`whatsapp_from` UNIQUE)
- `rechazos`: existe, RLS pendiente (sql/rechazos_rls_fix.sql)
- `movimientos_insumos`: destino de bodega.html/molino.html (`area`='bodega'|'molino'), separada de
  `movimientos_materiales` (esa es de tapas/PT) para no forzar campos que no aplican (ej. `solicitud_id`).
  Lectura abierta a cualquier autenticado (soporta visor), escritura master-only. Ver
  `.claude/docs/contexto-bot-requis.md` para el mapeo completo de prefijos SICAF → esta tabla.

### RPCs atómicas
- `descontar_inventario(p_sku, p_cantidad)` — usar en lugar de select+update manual
- `aumentar_inventario(p_sku, p_cantidad)` — ídem

---

## SQL pendiente de correr en Supabase (dashboard → SQL Editor)
1. `sql/rechazos_rls_fix.sql` — activa RLS en tabla rechazos
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

---

## Seguridad — estado
Sólido: sin secretos hardcodeados; CSP + HSTS + X-Frame-Options en vercel.json; auth.js centralizado; anon sin privilegios; api/whatsapp.js valida firma Twilio (fail-closed).
⚠️ Pendiente: `api/parse-doc.js` CORS `*` sin auth → tokens expuestos. `TWILIO_AUTH_TOKEN` debe existir en Vercel env vars.

## Roles de acceso (shared/auth.js)
- `master` → todo · `visor` → solo lectura (banner Modo Visual)
- `operativo` → enjaulado en registro-tapas.html; INSERT solo en comandas/comanda_tareas
- `operativo_serig` → enjaulado en registro-serigrafia.html; INSERT en registro_tiros_serig, paros_serig, registro_flameado_serig, registro_empaque_serig
- `operativo_prod` → NO enjaulado: ve TODOS los módulos en lectura (como visor), pero solo escribe en produccion_diaria (registrar turnos). auth.js bloquea escrituras a otras tablas (flag TETRA.esProdEditor + TETRA_PROD_TABLA); RLS lo respalda. Exento de logout por inactividad. NO edita recetas/fichas (solo-master)
- `supervisor_tapas` → enjaulado en registro-tapas.html (comparte la misma página con `operativo`, no es un módulo nuevo). Piloto (sep/2026): se REPROPÓSITA la cuenta que ya existía (`tapas@tetrapp.app`, antes rol `operativo`) para que ahora sea de la supervisora (Yenifer) — los operarios YA NO tienen acceso a ese login (se les cambió la contraseña); cuando se restaure su participación se creará una cuenta nueva aparte, no esta. Mismo alcance de escritura que `operativo` (solo INSERT en comandas/comanda_tareas). Ver `sql/supervisor_tapas_v1.sql`. Próxima área candidata: Serigrafía (sin tocar todavía).
- La jaula vive en TETRA_PAGINAS_OPERATIVO (auth.js): rol → página permitida
- TETRA_PAGINAS_MASTER (auth.js): páginas restringidas SOLO a master (ej. `gestion`) — cualquier
  otro rol es redirigido a index.html antes de revelar contenido (dato sensible de RRHH)
- Sesiones expiran a 60 min de inactividad, EXCEPTO roles operativos (pantallas de planta)

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
8. **Fecha "hoy" SIEMPRE con `fechaHoy()`** — NUNCA `new Date().toISOString().slice(0,10)`: devuelve fecha UTC y Guatemala es UTC-6, después de las 18:00 marca el día siguiente. `toISOString()` solo válido sobre fechas ancladas a mediodía o para timestamps completos.

---

## Personal
⚠️ Supervisora actual real tapas: **Yenifer** (tabla `personal` aún dice Heidy — pendiente Álvaro).
registro-tapas.html lee supervisor en vivo → se corregirá solo al actualizar el registro.
Serigrafía: S0 Luis Cordova (supervisor), S1-S7 operadores.
