# Contexto — Módulo Serigrafía
> Documento de arranque de sesión. Última actividad: ago/2026.
> Esta fue la sesión más larga (9,200+ mensajes). Cubre `serigrafia.html` y `registro-serigrafia.html`.

## Archivos del módulo
- `serigrafia.html` — vista admin: Inicio · Movimientos · Productividad · Personal
- `registro-serigrafia.html` — formulario móvil operadores (rol `operativo_serig`)

---

## serigrafia.html — Estado actual por tab

### Tab Inicio
- Board de solicitudes por línea (1-4), entregados, órdenes sin asignar

### Tab Movimientos
- Salidas e ingresos de serigrafía + resumen por ficha

### Tab Productividad
- Gráfico de lecturas de contador por línea y fecha
- Si la fecha elegida está vacía: `buildUltimasLecturasHint()` muestra las últimas 10 lecturas clicables para saltar a su fecha (distingue "base vacía" de "fecha equivocada")
- **Gráfico de productividad de Impresión** (vista master):
  - Eje X: número arriba en negrita + día de semana abajo (ej. `14` / `LUN`) — implementado con plugin propio de Chart.js que dibuja dos líneas en el canvas
  - Puntos de velada (rombos): se dibujan al frente con `prodVeladaFrontPlugin` (plugin `afterDatasetsDraw`) — radio 8, shadowBlur con color de línea, borde 3px; siempre encima de los puntos del turno diurno aunque coincidan en fecha y cantidad
  - Panel de detalle al hacer clic en la banda del eje X: muestra todas las líneas de ese día

### Tab Personal
- Grid de operadores con drag-and-drop por rol/línea
- **Matriz "Personal y Roles"**: filas globales (Supervisor, Auxiliar, Empaque) + filas por línea 1-4 (Flameador, Impresor, Receptor)
  - Rol **Empaque**: color naranja vivo `#EA580C` — añadido porque el empaque saca personal prestado de cualquier línea, no está fijo a una
  - Al arrastrar un chip entre roles se actualiza `proceso_hab` + `color_hex` en tabla `personal`
- **Asistencia Mensual**:
  - Muestra los **últimos 5 días del mes anterior** antes del día 1 del mes actual — con fondo ámbar y mes abreviado (ej. `31` / `JUL`), separador naranja grueso en la frontera de meses
  - Motivo: corte de nómina el día 25; veladas del 26-31 se pagan en el siguiente corte
  - La racha verde y el "Resumen del mes" del PDF miden solo el mes actual (la cola anterior no afecta esas métricas)
  - PDF exportado con el mismo tratamiento visual (columnas ámbar + mes abreviado)

---

## registro-serigrafia.html — Estado actual por flujo

### Flujo Impresión
- Pantallas: `scrSel` → `scrForm` (contador, momentos, paros, foto) → `scrOk` (gráfico)
- **Momentos disponibles**: Velada siempre activa (antes requería un Inicio previo). Velada ya no cierra el turno — después de registrar Velada se habilitan Inicio y Paro para seguir registrando
- En `scrForm` paso 2: cuadro "Lecturas de hoy en esta línea" muestra SKU + descripción completa (truncada 34 chars) + barra de progreso visual (morado <50%, ámbar 50-99%, verde ≥100%) con porcentaje numérico
- Gráfico en `scrOk`: eje X con día de semana (`LUN 14`); tooltip al clic muestra `Martes 14/07/2026`; helper `_okDiaSemana()` anclado a mediodía para evitar bug UTC-6

### Flujo Flameado
- Pantallas: `scrSelFlam` → `scrFormFlam` → `scrOkFlam`
- Tabla: `registro_flameado_serig` — una fila por bolsa: hora, flameador, sku/descripcion, cantidad, para_linea 1-4
- "Otra bolsa" conserva flameador/envase/línea seleccionados

### Flujo Empaque
- Pantallas: `scrSelEmp` (+tarjeta "Apoyo de otra área" → `ovApoyo`) → `scrFormEmp` → `scrOkEmp`
- Tabla: `registro_empaque_serig` — operador_codigo (null si apoyo externo), area_origen, sku/descripcion, cantidad
- El apoyo externo NO se agrega a `personal`

---

## inventario.html — Vista previa de importación (mejorada en esta sesión)
- Las 4 fichas de resumen ("En el Excel", "Existencias cambian", "Productos nuevos", "Sin cambio") son **clicables**
- Al hacer clic en una ficha: se resalta (borde + fondo teal) y el cuadro de abajo muestra el detalle **completo** de esa categoría (no una muestra, la lista entera con scroll 240px)
- Clic de nuevo sobre la misma ficha: vuelve a la vista mixta inicial

---

## Sistema de cierres de período
- Tabla `periodo_cierres` + columna `solicitudes.periodo_efectivo` (SQL: `sql/periodo_cierres_v1.sql`)
- Lógica: al cierre del período (día 25), las solicitudes se "trasladan" al mes siguiente asignándoles `periodo_efectivo`
- **Excepciones** (`NO_TRASLADAR_CODIGOS`): S-015 y S-105 — nunca se trasladan, se manejaron con `sql/excepcion_s015_julio.sql`
- ⚠️ Si se vuelve a correr `sql/seguridad_v1.sql` (que borra y recrea todas las políticas), hay que re-correr después los fix específicos de serigrafía (`insert_operativo_serig`, etc.)

---

## SQL corridos (serigrafía)
- `sql/fix_rls_serig_v2.sql` ✅ — reparó `registro_tiros_serig`: política `insert_operativo_serig`, columna `hora`, CHECK con 'velada', fechas UTC corregidas
- `sql/registro_procesos_serig_v1.sql` — crea `registro_flameado_serig` + `registro_empaque_serig` con RLS (**confirmar si ya se corrió**)
- `sql/periodo_cierres_v1.sql` — crea `periodo_cierres` + columna `solicitudes.periodo_efectivo`

---

## Alerta de CSP en consola (inofensiva)
Chrome intenta cargar `chart.umd.js.map` (source map de Chart.js) y el CSP de `vercel.json` lo bloquea porque `connect-src` solo permite Supabase. Es solo ruido de debugging, no afecta funcionalidad. **No tocar el CSP para silenciarlo.**

---

## Reglas específicas de serigrafía
- **`fechaHoy()`** siempre para fecha local — nunca `new Date().toISOString().slice(0,10)` (Guatemala UTC-6, bug real en jul/2026)
- Chart.js plugins propios para funcionalidad que la librería no soporta nativamente (etiquetas de 2 líneas, rombos al frente)
- Errores de guardado en recuadro rojo persistente (no toast efímero)
- `buildOpCardGen(op, fn)` genera tarjetas de operario para los 3 flujos

---

## Personal de serigrafía (referencia)
- S0 Luis Cordova (supervisor)
- S1-S7 operadores
- Roles en `ROLES_SERIG`: Supervisor · Flameador · Impresor · Receptor · Auxiliar · Empaque
