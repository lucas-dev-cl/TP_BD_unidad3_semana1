-- ============================================================
-- PARTE A: MEDICIÓN DEL IMPACTO DE INDEXACIÓN EN CONSULTAS CLAVE
-- Integrantes: Acosta Cristina, Gallardo Lucas, Lara Juan, Torres Shirley
-- ============================================================

-- ------------------------------------------------------------
-- CONSULTA 1: Pedidos pendientes ordenados por fecha
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT id_pedido, fecha_pedido, total_pedido
FROM pedido
WHERE estado_pedido = 'PENDIENTE' AND eliminado_pedido = FALSE
ORDER BY fecha_pedido DESC;

-- Índice para Consulta 1:
CREATE INDEX idx_pedido_estado_fecha
ON pedido (estado_pedido, fecha_pedido DESC)
WHERE eliminado_pedido = FALSE;


-- ------------------------------------------------------------
-- CONSULTA 2: Búsqueda de productos por nombre (LIKE)
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT id_producto, nombre_producto, precio_producto
FROM producto
WHERE lower(nombre_producto) LIKE 'pizza%';

-- Índice para Consulta 2:
CREATE INDEX idx_producto_nombre_lower
ON producto (lower(nombre_producto) varchar_pattern_ops);


-- ------------------------------------------------------------
-- CONSULTA 3: Detalles asociados a un pedido
-- ------------------------------------------------------------
EXPLAIN ANALYZE
SELECT *
FROM detalle_pedido
WHERE id_pedido = 12500;

-- Índice para Consulta 3:
CREATE INDEX idx_detalle_pedido_id_pedido
ON detalle_pedido (id_pedido);
