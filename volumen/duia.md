# Declaración de Uso de IA (DUIA) — Food Store
## TP Unidad 3 Semana 1 — Índices, vistas y vistas materializadas

---

## Parte A — Índices (medición del impacto de indexación)

**Herramientas:** Kiro (especificar) → OpenCode (proponer el índice) → `EXPLAIN ANALYZE` (medir).

---

### Consulta 1 — Pedidos pendientes ordenados por fecha

**Consulta:**
```sql
SELECT id_pedido, fecha_pedido, total_pedido
FROM pedido
WHERE estado_pedido = 'PENDIENTE' AND eliminado_pedido = FALSE
ORDER BY fecha_pedido DESC;
```

**Diagnóstico ANTES (sin índice):**
- Escaneo Secuencial (Seq Scan): para encontrar los registros pendientes no eliminados, PostgreSQL revisó la tabla completa descartando 150.171 registros.
- Ordenamiento en memoria (Sort): al no haber índice, el motor ordenó 49.829 filas usando quicksort, consumiendo 3,4 MB de RAM.
- Tiempo total: 1627 ms (~1,6 segundos).

**Qué propuso la IA (OpenCode):** índice compuesto y parcial
```sql
CREATE INDEX idx_pedido_estado_fecha
ON pedido (estado_pedido, fecha_pedido DESC)
WHERE eliminado_pedido = FALSE;
```

**Qué se aceptó:** la propuesta completa, tal cual.

**Resultado DESPUÉS:**
- Cambio de plan: de Seq Scan a Bitmap Index Scan usando `idx_pedido_estado_fecha`.
- Reducción de lectura en disco: de 2.061 a 193 bloques leídos (`read=193`).
- Aceleración del filtrado: de ~1434 ms a ~101 ms (`actual time=16.634..101.28`) — mejora superior al 90%.

---

### Consulta 2 — Búsqueda de productos por nombre

**Especificación (Kiro):** búsqueda en el catálogo por coincidencia de nombre (`LIKE`). Frecuencia: alta (búsquedas en la app). Columna involucrada: `nombre_producto` (filtro).

**Diagnóstico ANTES (sin índice):**
```sql
SELECT id_producto, nombre_producto, precio_producto
FROM producto
WHERE lower(nombre_producto) LIKE 'pizza%';
```
- Escaneo Secuencial: PostgreSQL recorrió toda la tabla descartando 50.002 registros que no coincidían.
- Tiempo de ejecución: 370,97 ms.

**Qué propuso la IA (OpenCode):** índice funcional B-Tree con `varchar_pattern_ops` para acelerar búsquedas con `LIKE`:
```sql
CREATE INDEX idx_producto_nombre_lower
ON producto (lower(nombre_producto) varchar_pattern_ops);
```

**Qué se aceptó:** la propuesta completa, tal cual.

**Resultado DESPUÉS:** la consulta pasó de Seq Scan a Bitmap Index Scan usando `idx_producto_nombre_lower`. El tiempo de ejecución se redujo de 370,97 ms a solo 0,207 ms.

---

### Consulta 3 — Detalles asociados a un pedido

**Especificación (Kiro):** obtener los ítems de detalle asociados a un pedido determinado. Frecuencia: alta (cada vez que un usuario abre la vista de un pedido). Columna involucrada: `id_pedido` en `detalle_pedido` (filtro / clave foránea).

**Diagnóstico ANTES:**
```sql
SELECT * FROM detalle_pedido WHERE id_pedido = 12500;
```
Seq Scan sobre `detalle_pedido` por ausencia de índice sobre la FK.

**Qué propuso la IA (OpenCode):** evaluar la existencia de un índice B-Tree sobre la clave foránea `id_pedido`:
```sql
CREATE INDEX idx_detalle_pedido_id_pedido
ON detalle_pedido (id_pedido);
```

**Qué se aceptó:** la propuesta, tal cual — caso directo de FK sin índice de soporte.

**Resultado DESPUÉS:** Index Scan directo sobre `idx_detalle_pedido_id_pedido`.

---

### Medición del impacto en escrituras (INSERTs)

Para evaluar el sobrecosto en operaciones de escritura al sumar los tres índices anteriores, se ejecutó un script de carga masiva de 500 registros en `detalle_pedido`:
- Tiempo promedio de carga ANTES de los índices: 12,10 ms.
- Tiempo promedio de carga DESPUÉS de los índices: 18,40 ms.

**Conclusión:** la creación de índices acelera sustancialmente las lecturas, pero introduce un costo adicional en las escrituras por el mantenimiento de las estructuras B-Tree. Dado que en este sistema la frecuencia de lectura supera ampliamente a la de escritura, el incremento del 52% en el tiempo de inserción es aceptable frente a la ganancia de velocidad en las consultas.

---

### Propuesta descartada por sobreindexación

**Qué propuso la IA:** crear un índice B-Tree individual en `pedido(forma_pago_pedido)`.

**Decisión:** descartado explícitamente.

**Justificación técnica:** la columna `forma_pago_pedido` tiene baja cardinalidad (solo 3 valores posibles: `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`). Un índice B-Tree sobre una columna con tan poca variedad de datos no aporta beneficio real, ya que el optimizador de PostgreSQL preferirá un Seq Scan antes que recorrer un índice que devuelve un porcentaje elevado de las filas de la tabla. Mantenerlo solo consumiría espacio en disco y penalizaría innecesariamente el rendimiento de los `INSERT`.

---

### Segundo caso de sobreindexación descartado (revisión posterior)

**Qué se había propuesto originalmente:** `idx_detalle_pedido_id_pedido`, un índice B-Tree sobre `detalle_pedido(id_pedido)`, para la Consulta 3.

**Qué se descartó y por qué:** al revisar el `schema.sql`, `detalle_pedido` ya tiene una restricción `UNIQUE(id_pedido, id_producto)`, que PostgreSQL implementa como un índice B-Tree compuesto empezando por `id_pedido`. Por la regla del prefijo izquierdo, ese índice ya resuelve cualquier consulta filtrada solo por `id_pedido` sin necesitar un índice aparte.

**Verificación:** se ejecutó la Consulta 3 con y sin `idx_detalle_pedido_id_pedido` creado. En ambos casos el plan fue idéntico — `Index Scan using detalle_pedido_id_pedido_id_producto_key` — con el mismo tiempo de ejecución (~0,05–0,1 ms). El índice nuevo no cambiaba nada la lectura y sí sumaba costo de mantenimiento en cada escritura sobre `detalle_pedido`.

**Decisión final:** no crear `idx_detalle_pedido_id_pedido`. Se documenta como segundo caso de sobreindexación descartado, además del de `forma_pago_pedido`: la lección en ambos casos es la misma — antes de crear un índice hay que revisar si una restricción `UNIQUE`/FK ya existente lo cubre por prefijo, no solo si "ayuda" en aislado.

---

## Parte B — Vistas

> **Pendiente:** Luc dijo que ya tiene armada esta parte. Pegarla acá
> en el mismo formato que las Partes A y C (herramienta usada, spec
> entregada a Kiro/OpenCode, qué propuso la IA, qué se aceptó o
> modificó, verificación de equivalencia de cada vista).
>
> Si no la tiene todavía en este formato, el contenido ya existe en
> `informe_mediciones.md` (sección de vistas) y se puede reformatear
> desde ahí: las tres vistas (`vw_productos_vigentes`,
> `vw_pedidos_usuario`, `vw_detalle_pedido`), el criterio de seguridad
> con `app_user` sobre `vw_pedidos_usuario`, y la verificación por
> `EXCEPT` en ambas direcciones contra la consulta manual de cada una.

---

## Parte C — Vista materializada `mv_facturacion_categoria_mes`

**Herramienta:** Kiro (especificar) → OpenCode (generar) → psql (medir).
**Spec:** ver `specs/mv_facturacion_categoria_mes.md`. Se entregó a la IA el objetivo (acelerar el reporte de facturación por categoría y mes), la consulta agregada exacta, y el criterio de aceptación (mejora de al menos un orden de magnitud + refresco `CONCURRENTLY`).

**Qué propuso la IA:**
- La estructura `CREATE MATERIALIZED VIEW ... WITH DATA` con el JOIN de las 4 tablas y el `GROUP BY` por categoría y mes truncado.
- Filtro inicial solo por `estado_pedido = 'CONFIRMADO'`.
- Índice único propuesto inicialmente solo sobre `id_categoria`.

**Qué se modificó:**
- El filtro de estado se amplió a `estado_pedido IN ('CONFIRMADO', 'TERMINADO')`: un pedido confirmado ya es una venta en firme para el negocio, no hace falta esperar a que esté `TERMINADO` para contarlo en la facturación. Se agregó también `dp.eliminado_detalle_pedido = FALSE`, que la propuesta inicial no incluía.
- El índice único propuesto (`id_categoria` solo) **no cumplía la restricción de unicidad**: una misma categoría aparece en múltiples filas, una por cada mes. Se corrigió a un índice compuesto `(id_categoria, mes)`.
- Se decidió explícitamente **no** filtrar por `producto.eliminado_producto`, a diferencia de `vw_productos_vigentes` en la Parte B: la vigencia actual del producto no debe borrar del reporte una venta histórica ya ocurrida.

**Qué se descartó:**
- Alternativa propuesta de refrescar la vista con un `TRIGGER` en cada `INSERT` sobre `detalle_pedido`. Se descartó por sobrecosto: convertiría cada alta de un pedido en un recálculo completo del agregado, anulando el propósito de materializar el reporte. Se prefirió un refresco programado (diario, fuera de horario pico — justificación completa en `informe_mediciones.md`, Parte C, punto 4).

**Verificación de equivalencia:** se comparó el resultado de la vista contra la consulta agregada manual (mismo `COUNT(*)` y mismo `SUM(total_facturado)`), confirmando que la vista materializada no altera la lógica del reporte, solo su tiempo de respuesta.
