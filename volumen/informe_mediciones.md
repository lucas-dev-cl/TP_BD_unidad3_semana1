# Informe de Mediciones — Parte B: Vistas
## Food Store — TP Unidad 3 Semana 1

---

## 1. Especificación utilizada

### Objetivo

Crear las vistas SQL necesarias para dar soporte a los reportes habituales de la aplicación
Food Store, asegurando una estructura limpia, filtros de negocio consistentes y protección
de datos sensibles.

### Reglas Generales y Seguridad

**Filtro de Vigencia:**
Los productos vigentes deben filtrarse usando `eliminado_producto = FALSE` y `disponible_producto = TRUE`. Las categorías asociadas con `eliminado_categoria = FALSE`. Los pedidos con `eliminado_pedido = FALSE`. Los usuarios con `eliminado_usuario = FALSE`. Los detalles con `eliminado_detalle_pedido = FALSE`.

**FKs internas:**
No exponer columnas de clave foránea como valores numéricos. Reemplazarlas por el valor descriptivo obtenido mediante JOIN (ej: `nombre_categoria` en lugar de `id_categoria`).

**Seguridad y Privacidad — columnas excluidas globalmente:**

| Columna | Motivo |
|---|---|
| `eliminado_*` | Control de baja lógica, sin valor para el reporte |
| `created_at_*` | Metadatos técnicos de auditoría interna |
| FK numéricas | Reemplazadas por el valor descriptivo del JOIN |
| `stock_producto` | Dato operativo interno, no exponer al público |
| `disponible_producto` | Control interno (el filtro ya lo resuelve) |
| `contrasena_usuario` | Dato sensible, NUNCA exponer |
| `mail_usuario` | Dato personal, excluir por privacidad |
| `rol_usuario` | Dato de control interno |

---

### Vista 1 — `vw_productos_vigentes`

**Propósito:** Mostrar el catálogo activo de productos junto con su categoría asociada. Orientada al frontend público y reportes de operaciones.

**Tablas:** `producto JOIN categoria ON categoria.id_categoria = producto.id_categoria`

**Filtro:**
```sql
WHERE producto.eliminado_producto  = FALSE
  AND producto.disponible_producto = TRUE
  AND categoria.eliminado_categoria = FALSE
```

**Columnas excluidas:** `id_categoria`, `stock_producto`, `eliminado_producto`, `disponible_producto`, `created_at_producto`, `eliminado_categoria`, `created_at_categoria`

**Columnas expuestas:** `id_producto`, `nombre_producto`, `descripcion_producto`, `precio_producto`, `imagen_producto`, `nombre_categoria`

---

### Vista 2 — `vw_pedidos_usuario`

**Propósito:** Listar pedidos con los datos principales del cliente. Orientada a gestión y atención al cliente, sin exponer credenciales ni datos personales.

**Tablas:** `pedido JOIN usuario ON usuario.id_usuario = pedido.id_usuario`

**Filtro:**
```sql
WHERE pedido.eliminado_pedido    = FALSE
  AND usuario.eliminado_usuario  = FALSE
```

**Columnas excluidas:** `id_usuario`, `contrasena_usuario`, `mail_usuario`, `rol_usuario`, `eliminado_usuario`, `created_at_usuario`, `eliminado_pedido`, `created_at_pedido`

**Columnas expuestas:** `id_pedido`, `fecha_pedido`, `estado_pedido`, `forma_pago_pedido`, `total_pedido`, `nombre_usuario`, `apellido_usuario`

---

### Vista 3 — `vw_detalle_pedido`

**Propósito:** Desglosar los ítems de cada pedido incluyendo el nombre del producto. Orientada a tickets, cocina y reportes de ventas.

**Tablas:** `detalle_pedido JOIN producto ON producto.id_producto = detalle_pedido.id_producto`

**Filtro:**
```sql
WHERE detalle_pedido.eliminado_detalle_pedido = FALSE
```

**Columnas excluidas:** `id_producto`, `eliminado_detalle_pedido`, `created_at_detalle_pedido`

**Columnas expuestas:** `id_detalle_pedido`, `id_pedido`, `nombre_producto`, `cantidad_detalle_pedido`, `precio_unitario_detalle_pedido`

---

## 2. Vistas creadas

Las tres vistas se encuentran definidas en `views.sql` con `CREATE OR REPLACE VIEW`. A continuación el resumen de cada una.

### 2.1 `vw_productos_vigentes`

```sql
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
```

### 2.2 `vw_pedidos_usuario`

```sql
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
```

### 2.3 `vw_detalle_pedido`

```sql
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
```

---

## 3. Criterio de seguridad aplicado

La vista `vw_pedidos_usuario` implementa el criterio de seguridad visto en la teoría: exponer datos del usuario **sin incluir la columna contraseña**, de modo que pueda otorgarse `SELECT` sobre la vista sin dar acceso a la tabla base.

Esto se logra creando un rol de conexión específico para la aplicación y aplicando permisos a nivel de objeto:

```sql
-- Crear el rol de conexión para la aplicación
CREATE ROLE app_user WITH LOGIN PASSWORD 'foodstore123';

-- Acceso a la base y al schema
GRANT CONNECT ON DATABASE food_store TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;

-- Se bloquea el acceso directo a la tabla base
REVOKE SELECT ON usuario FROM app_user;

-- Solo se permite el acceso a través de la vista
GRANT SELECT ON vw_pedidos_usuario TO app_user;
```

Al conectarse con el rol `app_user` e intentar consultar la tabla `usuario` directamente, PostgreSQL deniega el acceso. La consulta sobre la vista funciona correctamente pero sin exponer `contrasena_usuario` ni `mail_usuario`.

![Control de acceso — SELECT denegado sobre tabla usuario](images/rol_control_acceso.png)

---

## 4. Verificación de equivalencia

Para cada vista se ejecutó la consulta `EXCEPT` en ambas direcciones contra su equivalente manual (ver `verify_views.sql`).

**Criterio de validación:** si el `EXCEPT` no devuelve filas, los conjuntos son idénticos.

```
A EXCEPT B → filas en la vista que NO están en la consulta manual
B EXCEPT A → filas en la consulta manual que NO están en la vista
Sin filas en ambos sentidos = equivalencia total ✅
```

---

### 4.1 `vw_productos_vigentes`

**A EXCEPT B** — filas en la vista que NO están en la consulta manual:

![productos_vigentes EXCEPT A→B](images/productos_vigentes_except.png)

**B EXCEPT A** — filas en la consulta manual que NO están en la vista:

![productos_vigentes EXCEPT B→A](images/productos_vigentes_except_b.png)

**Conclusión:** sin diferencias — la vista es equivalente a la consulta manual. ✅

---

### 4.2 `vw_pedidos_usuario`

**A EXCEPT B** — filas en la vista que NO están en la consulta manual:

![pedidos_usuario EXCEPT A→B](images/pedido_usuario_except.png)

**B EXCEPT A** — filas en la consulta manual que NO están en la vista:

![pedidos_usuario EXCEPT B→A](images/pedido_usuario_except_b.png)

**Conclusión:** sin diferencias — la vista es equivalente a la consulta manual. ✅

---

### 4.3 `vw_detalle_pedido`

**A EXCEPT B** — filas en la vista que NO están en la consulta manual:

![detalle_pedido EXCEPT A→B](images/detalle_pedido_except.png)

**B EXCEPT A** — filas en la consulta manual que NO están en la vista:

![detalle_pedido EXCEPT B→A](images/detalle_pedido_except_b.png)

**Conclusión:** sin diferencias — la vista es equivalente a la consulta manual. ✅

---

## 5. Archivos entregados

| Archivo | Contenido |
|---|---|
| `views.sql` | Definición de las tres vistas con `CREATE OR REPLACE VIEW` |
| `verify_views.sql` | Consultas individuales y verificación por `EXCEPT` en ambas direcciones |
| `informe_mediciones.md` | Este documento (incluye spec, vistas, criterio de seguridad y evidencia) |
