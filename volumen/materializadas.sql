-- ============================================================
-- PARTE C: VISTA MATERIALIZADA — Facturación por categoría y mes
-- Spec de referencia: specs/mv_facturacion_categoria_mes.md
-- Generado con OpenCode a partir de esa especificación,
-- leído línea por línea antes de ejecutar (ver duia.md).
-- ============================================================

-- ------------------------------------------------------------
-- (0) Consulta original, sin materializar — medir ANTES
-- ------------------------------------------------------------
EXPLAIN ANALYZE
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


-- ------------------------------------------------------------
-- (1) Creación de la vista materializada
-- ------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;

CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
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
         date_trunc('month', p.fecha_pedido)
WITH DATA;

-- Índice único: clave natural del agregado y requisito de Postgres
-- para poder usar REFRESH ... CONCURRENTLY.
CREATE UNIQUE INDEX ux_mv_facturacion_categoria_mes
    ON mv_facturacion_categoria_mes (id_categoria, mes);

COMMENT ON MATERIALIZED VIEW mv_facturacion_categoria_mes IS
    'Facturación por categoría y mes, sobre pedidos CONFIRMADO/'
    'TERMINADO no eliminados. No filtra por vigencia del producto '
    '(la venta histórica se mantiene aunque el producto se dé de '
    'baja después). Política de refresh: ver informe_mediciones.md, '
    'Parte C, punto 4.';


-- ------------------------------------------------------------
-- (2) Medición DESPUÉS: leer la vista ya materializada
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM mv_facturacion_categoria_mes
ORDER BY mes, nombre_categoria;


-- ------------------------------------------------------------
-- (3) Verificación de equivalencia contra la consulta manual (0)
-- Deben coincidir cantidad de filas y totales.
-- ------------------------------------------------------------
SELECT COUNT(*) AS filas_vista FROM mv_facturacion_categoria_mes;

SELECT SUM(total_facturado) AS total_general
FROM mv_facturacion_categoria_mes;


-- ------------------------------------------------------------
-- (4) Refresco sin bloquear lecturas (requiere el índice único)
-- ------------------------------------------------------------
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
