# TETRAPP — Schema de Tablas Supabase (referencia completa)

> Leer este archivo cuando se trabaje con queries, RLS, o estructura de datos.
> Las notas críticas viven en CLAUDE.md § Tablas Supabase.

| Tabla | Descripción |
|---|---|
| `solicitudes` | Órdenes (código T-001/S-001 via trigger DB) |
| `solicitud_lineas` | Líneas de producto (operadores_ids TEXT[]) |
| `solicitud_operadores` | Asignación de operadores |
| `solicitud_historial` | Historial de cambios de estado |
| `personal` | Operarios/supervisores (codigo UNIQUE, proceso_hab, color_hex, rol: 'operador'\|'supervisor') — fuente única de verdad; registro-tapas.html lee el supervisor activo de aquí, no lo hardcodea |
| `inventario` | 2358 SKUs activos (sku, descripcion, existencia, facturable, activo). +3 columnas de producción (sql/produccion_v1.sql): `meta_12hrs` (capacidad por turno de 12h, base de la eficiencia), `maquina_default` (máquina habitual del SKU, la escribe produccion.html al guardar un turno), `precio_ponderado_manual` (respaldo solo para SKUs que se producen pero nunca se facturan, ej. 214774/214776) |
| `produccion_diaria` | Producción de sopladoras: una fila por (fecha, turno 'dia'\|'noche', maquina, sku, **documento**) + descripcion, cantidad, origen 'pdf'\|'manual'\|'sheets'. ⚠️ `documento` (correlativo de la requi, ej. PRI2-421) entra en la llave única porque **un turno puede tener varias requis distintas** (ingresos anticipados + la principal) con cantidades que se SUMAN — verificado en 13-may-2026: PRI2-412, 418 y 421 traen cantidades diferentes del mismo turno. Recargar una requi reemplaza solo sus líneas. El ingreso manual usa documento='MANUAL'. maquina=0 = sin asignar / producto que no es de sopladora |
| `movimientos_materiales` | Trazabilidad (tipo: 'salida_bodega' \| 'entrada_pt') |
| `rechazos` | ✅ Existe (la creó movimientos_serigrafia_v1.sql) — RLS pendiente: correr sql/rechazos_rls_fix.sql |
| `perfiles` | Roles de acceso: master / visor / operativo / operativo_serig |
| `paros_maquina` | Registro de paros (legado tapas) |
| `registro_tiros_serig` | Lecturas de contador por línea/fecha/momento (inicio/mediodia/fin/velada) + hora + foto_url — la llena Impresión en registro-serigrafia.html; la lee Productividad en serigrafia.html. RLS reparada con sql/fix_rls_serig_v2.sql |
| `paros_serig` | Paros por línea/fecha con motivo (incl. EMPAQUE con envase+cantidad) |
| `registro_flameado_serig` | Una fila por bolsa flameada: hora, flameador, sku/descripcion, cantidad, para_linea 1-4 (sql/registro_procesos_serig_v1.sql) |
| `registro_empaque_serig` | Empaques: operador_codigo (null = apoyo externo), area_origen, sku/descripcion, cantidad (sql/registro_procesos_serig_v1.sql) |
| `entregas_serig` | Entregas/requis de serigrafía (migradas desde localStorage) |
| `asistencia_diaria` | Asistencia por fecha/área/turno (presente/ausente/tarde/velada) — la usan serigrafia.html Personal y sus PDFs |
| `comandas` + `comanda_tareas` | Producción diaria tapas |
| `bot_estado` | Estado conversacional del bot de WhatsApp (1 fila por número: whatsapp_from UNIQUE, estado JSON, updated_at). La usa api/whatsapp.js |
| `ventas` | Detalle de facturación, una fila por línea de factura (serie, docu, fecha DATE, codigo_cliente, nit, cliente, familia, descripcion_familia, sku, descripcion, precio_unidad, total_quetzales, total_unidades, costo, utilidad). La escribe ventas.html (importador principal, reemplaza por rango de fechas). ⚠️ Existía antes del módulo, sql/ventas_financiero_v1.sql la normaliza. (El importador duplicado que tenía inventario.html se eliminó sep/2026 al fusionar ese módulo en bodega.html) |
| `clientes`, `cat_procesos`, `asistencia`, `configuracion` | Catálogos / preferencias UI |
| `v_solicitudes`, `v_capacidad_hoy` | Vistas |

## ventas — nota SKU vs facturación
La tab Rotación de ventas.html compara produccion_diaria vs `ventas` por mes: unidades producidas
vs TODA la facturación del mes sin filtrar por SKU. El aviso permanente explica que algunos SKUs
se facturan con código diferente (ej. 10033 se factura también como 100332). Pendiente: mapear
esas "recetas"/variantes para afinar la comparación SKU a SKU.

## RPCs atómicas disponibles
- `descontar_inventario(p_sku, p_cantidad)` — usar en lugar de select+update manual
- `aumentar_inventario(p_sku, p_cantidad)` — ídem
