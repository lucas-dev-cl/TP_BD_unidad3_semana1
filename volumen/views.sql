-- ============================================================================
-- VISTAS — Food Store
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Vista 1: Catálogo de productos vigentes con su categoría
-- Propósito : Reporte del catálogo activo para frontend y operaciones.
-- Excluye   : stock_producto, eliminado_producto, disponible_producto,
--             created_at_producto, id_categoria (FK), eliminado_categoria,
--             created_at_categoria
-- Vigencia  : producto activo (eliminado = FALSE, disponible = TRUE)
--             y categoría activa (eliminado = FALSE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_productos_vigentes AS
SELECT
    p.id_producto,
    p.nombre_producto,
    p.descripcion_producto,
    p.precio_producto,
    p.imagen_producto,
    c.nombre_categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.eliminado_producto  = FALSE
  AND p.disponible_producto = TRUE
  AND c.eliminado_categoria = FALSE;


-- ----------------------------------------------------------------------------
-- Vista 2: Pedidos con datos del usuario
-- Propósito : Reporte de gestión y atención al cliente.
-- Excluye   : id_usuario (FK), contrasena_usuario, mail_usuario, rol_usuario,
--             eliminado_usuario, created_at_usuario,
--             eliminado_pedido, created_at_pedido
-- Vigencia  : pedido activo (eliminado = FALSE)
--             y usuario activo (eliminado = FALSE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_pedidos_usuario AS
SELECT
    p.id_pedido,
    p.fecha_pedido,
    p.estado_pedido,
    p.forma_pago_pedido,
    p.total_pedido,
    u.nombre_usuario,
    u.apellido_usuario
FROM pedido p
JOIN usuario u ON u.id_usuario = p.id_usuario
WHERE p.eliminado_pedido  = FALSE
  AND u.eliminado_usuario = FALSE;


-- ----------------------------------------------------------------------------
-- Vista 3: Detalle de pedido con nombre del producto
-- Propósito : Desglose de ítems por pedido para tickets, cocina y ventas.
-- Excluye   : id_producto (FK), eliminado_detalle_pedido,
--             created_at_detalle_pedido
-- Vigencia  : detalle activo (eliminado = FALSE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_detalle_pedido AS
SELECT
    dp.id_detalle_pedido,
    dp.id_pedido,
    pr.nombre_producto,
    dp.cantidad_detalle_pedido,
    dp.precio_unitario_detalle_pedido
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto
WHERE dp.eliminado_detalle_pedido = FALSE;
