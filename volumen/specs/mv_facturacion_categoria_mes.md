# spec: mv_facturacion_categoria_mes

## Objetivo
Acelerar el reporte gerencial "facturación total por categoría de
producto y mes", usado para el panel de ventas y el cierre mensual.
Hoy se resuelve con una consulta agregada sobre `detalle_pedido` +
`pedido` + `producto` + `categoria` que recorre todo el historial de
pedidos en cada ejecución — con el volumen ya cargado en la Parte A
(~150.000 filas en `pedido`), es la consulta agregada más pesada del
sistema.

## Por qué materializar y no solo indexar
No es una consulta transaccional de alta frecuencia como las tres de la
Parte A: se ejecuta pocas veces por día (paneles gerenciales, cierre
mensual), pero cada ejecución agrega sobre miles de filas de
`detalle_pedido`. Ningún índice evita recorrer y sumar esas filas en
cada consulta — solo evita el `Seq Scan`. Una vista materializada
precalcula el agregado una vez y lo sirve después como una simple
lectura de tabla chica.

## Consulta afectada (equivalente, sin materializar)
```sql
SELECT
    c.id_categoria,
    c.nombre_categoria,
    date_trunc('month', p.fecha_pedido)::date          AS mes,
    COUNT(DISTINCT p.id_pedido)                          AS cantidad_pedidos,
    SUM(dp.cantidad_detalle_pedido)                      AS unidades_vendidas,
    SUM(dp.cantidad_detalle_pedido
        * dp.precio_unitario_detalle_pedido)             AS total_facturado
FROM detalle_pedido dp
JOIN pedido    p  ON p.id_pedido   = dp.id_pedido
JOIN producto  pr ON pr.id_producto = dp.id_producto
JOIN categoria c  ON c.id_categoria = pr.id_categoria
WHERE p.estado_pedido IN ('CONFIRMADO', 'TERMINADO')
  AND p.eliminado_pedido = FALSE
  AND dp.eliminado_detalle_pedido = FALSE
GROUP BY c.id_categoria, c.nombre_categoria,
         date_trunc('month', p.fecha_pedido);
```

## Frecuencia y columnas
- Frecuencia de uso: baja (paneles gerenciales / cierre mensual), no
  cada request de usuario final — por eso el candidato correcto es
  materializar, no solo indexar.
- Agrupa por categoría y por mes calendario de `fecha_pedido`.
- Filtro de estado: `CONFIRMADO` o `TERMINADO` — se decide incluir
  ambos porque un pedido `CONFIRMADO` ya representa una venta en firme
  para el negocio, no solo un pedido entregado. Se excluye
  `PENDIENTE` (todavía no es venta) y `CANCELADO` (no factura).
- **Decisión de diseño explícita:** no se filtra por
  `producto.eliminado_producto`. La vigencia actual del producto no
  debe afectar la facturación histórica: si un producto se da de baja
  después de haberse vendido, esa venta ya ocurrida tiene que seguir
  contando en el reporte del mes en que se hizo. Es distinto del
  criterio de `vw_productos_vigentes` (Parte B), que sí filtra
  vigencia porque ahí el objetivo es mostrar catálogo activo, no
  historial.

## Requisito de refresco concurrente
La vista debe tener un **índice único** sobre `(id_categoria, mes)`
— es la clave natural del agregado y el requisito de PostgreSQL para
poder ejecutar `REFRESH MATERIALIZED VIEW ... CONCURRENTLY`, que no
bloquea las lecturas del panel mientras se recalcula.

## Criterio de aceptación
1. La vista se crea con `WITH DATA` y sus totales coinciden
   exactamente con la consulta manual equivalente de arriba.
2. `EXPLAIN ANALYZE` sobre `SELECT * FROM mv_facturacion_categoria_mes`
   muestra un `Seq Scan` sobre una tabla de pocas filas (categorías ×
   meses) con tiempo del orden de milisegundos, sensiblemente menor
   al de la consulta agregada original sobre el volumen cargado en
   la Parte A.
3. `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes`
   se ejecuta sin error gracias al índice único.
