# Contexto — Módulo Ventas y Financiero
> Documento de arranque de sesión. Última actividad: ago/2026.

## Qué existe y funciona

### `ventas.html` — 4 tabs
| Tab | Qué hace |
|---|---|
| **Resumen** | KPIs del mes en foco (total Q, unidades, precio prom, utilidad), gráfico mensual de barras CSS, desglose por familia, top clientes |
| **Productos** | Top SKUs por periodo, Δ vs mes anterior, búsqueda libre |
| **Clientes** | Concentración top 3, Δ vs mes anterior |
| **Rotación** | Producción (produccion_diaria) vs facturación (ventas) por mes — venta potencial (precio ponderado × producción) vs facturado real, badge Positiva/Negativa |

### `produccion.html` — 3 tabs (construidos en la misma sesión)
| Tab | Qué hace |
|---|---|
| **Ingreso** | PDF de requi (pdf.js) o manual fila por fila; deduce fecha/turno del nombre del archivo; pre-asigna máquina por `maquina_default` |
| **Reporte Semanal** | Pivote máquina×SKU, 12 columnas Día/Noche (Lun–Sáb), eficiencia = total ÷ (meta_12hrs × turnos) |
| **Mensual** | Replica la hoja "Mayo 2026": una caja por semana, separador grueso entre semanas, sombreado alterno por bloque de máquina (`.band-a`), panel de Resumen de eficiencia (eficiencia global, mejor/peor máquina, concentración, venta potencial) |

## SQL corrido y verificado
Todos los siguientes quedaron confirmados con `sql/verificacion_general.sql`:
- `sql/produccion_v1.sql` ✅ — tabla `produccion_diaria` + RLS + columnas `meta_12hrs`/`maquina_default`/`precio_ponderado_manual` en `inventario`
- `sql/produccion_seed_historico.sql` ✅ — 831 líneas · 29 días (5-may → 6-jun) · 4,901,703 und. Se tuvo que reinsertar el 13-may por separado con `sql/produccion_seed_fix_1305.sql`
- `sql/ventas_financiero_v1.sql` ✅ — tabla `ventas` con `fecha`→DATE, columnas `familia`/`descripcion_familia`/`codigo_cliente`, RLS master-only escritura
- `sql/rechazos_rls_fix.sql` ✅ — RLS activo en `rechazos` (confirmado de paso)

## Cómo funciona la importación de ventas
- Botón "Importar facturación" acepta Excel/CSV del reporte "VENTAS DISTRIBUCION" (columnas A-R)
- Reemplaza por rango de fechas (DELETE + INSERT) → se puede recargar un mes sin duplicar
- Toggle sin IVA / con IVA (×1.12) — el reporte viene sin IVA
- La tabla `ventas` tenía 4,588 filas verificadas (ene → ago 2026)
- El importador antiguo de `inventario.html` ("Ventas · Facturación") era más viejo y no mandaba `familia`/`codigo_cliente`
  — **eliminado sep/2026** al fusionar inventario.html dentro de bodega.html (ver `.claude/docs/contexto-bot-requis.md`);
  ventas.html es ahora la única fuente de importación de facturación

## Decisiones de diseño importantes
1. **Rotación compara totales, no SKU a SKU** — hay códigos que cambian antes de facturarse (ej. `10033` se factura también como `100332`). Se puso un aviso permanente explicando esto. Pendiente: mapear esas "recetas"/variantes SKU cuando Álvaro tenga la lista.
2. **Precio ponderado** se calcula automáticamente desde `ventas` (promedio histórico). Hay 77 SKUs con `precio_ponderado_manual` para los que se producen pero nunca se facturan (ej. 214774/214776).
3. **Sin cifras de facturación real en Mensual de produccion.html** — esa comparación financiera vive en ventas.html → Rotación, no en produccion.html.

## Pendiente de implementar (quedó al final de la sesión)
- **Tabla `sku_equivalencias`** + bloque scrolleable en Rotación para confirmar "recetas" de variantes SKU uno a uno — el usuario lo pidió pero la sesión alcanzó el límite de contexto antes de implementarlo.

## Catálogo de producción (inventario)
- 84 SKUs con `meta_12hrs` definida
- 73 con `maquina_default` asignada
- 77 con `precio_ponderado_manual`
- `maquina=0` = sin asignar / producto que no es de sopladora

## Archivos relevantes
- `ventas.html` — módulo principal
- `produccion.html` — módulo producción (Sopladoras)
- `sql/verificacion_general.sql` — script de verificación del estado de la DB
- `sql/produccion_seed_fix_1305.sql` — reinserción del 13-may que quedó fuera del seed inicial
