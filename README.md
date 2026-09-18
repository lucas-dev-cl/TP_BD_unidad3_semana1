# Food Store — TP Unidad 3, Semana 1
Índices, vistas y vistas materializadas

## Requisitos
- PostgreSQL 16+
- `psql` o un cliente equivalente

## Orden de ejecución

```bash
# 1. Esquema base (heredado, sin modificar)
psql -d food_store -f schema.sql

# 2. Datos base (heredados)
psql -d food_store -f data.sql

# 3. Ampliar el volumen de datos para que las diferencias de plan
#    y tiempo sean observables (Parte A trabajó con ~150.000 filas
#    en pedido y ~50.000 en producto — replicar una escala similar
#    con el generador de datos que hayan usado).

# 4. Parte A — índices: cada bloque de indices.sql trae primero el
#    EXPLAIN ANALYZE "antes" y luego el CREATE INDEX. Ejecutar de a
#    un bloque por vez para ver el cambio de plan.
psql -d food_store -f indices.sql

# 5. Parte B — vistas
psql -d food_store -f views.sql

# 6. Parte C — vista materializada (requiere que existan los datos
#    ampliados del paso 3, sobre pedido/detalle_pedido/producto/categoria)
psql -d food_store -f materializadas.sql
```

## Reproducir las mediciones

- **Parte A:** correr cada `EXPLAIN ANALYZE` de `indices.sql` antes y
  después de su `CREATE INDEX` correspondiente. El detalle de los
  planes obtenidos está en `informe_mediciones.md` (sección Parte A) y
  en `Parte_A_BASE_DE_DATOS.docx`.
- **Parte B:** las tres vistas se verifican contra su consulta manual
  equivalente con `EXCEPT` en ambas direcciones (ver
  `informe_mediciones.md`, sección Parte B, y las capturas en
  `images/`).
- **Parte C:** `materializadas.sql` incluye, en orden, la medición
  "antes" (consulta agregada original), la creación de la vista, la
  medición "después" (lectura de la vista) y el refresco concurrente.
  Volcar los tiempos reales obtenidos a `informe_mediciones.md`,
  sección Parte C — los valores que aparecen ahí hoy son una
  estimación de referencia a completar con la corrida real.

## Verificar el criterio de seguridad de la Parte B

```sql
CREATE ROLE app_user WITH LOGIN PASSWORD 'foodstore123';
GRANT CONNECT ON DATABASE food_store TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
REVOKE SELECT ON usuario FROM app_user;
GRANT SELECT ON vw_pedidos_usuario TO app_user;
```

Conectado como `app_user`, `SELECT * FROM usuario` debe ser rechazado;
`SELECT * FROM vw_pedidos_usuario` debe funcionar sin exponer
`contrasena_usuario` ni `mail_usuario`.

## Estructura del repositorio

```
food-store/
├── schema.sql              (heredado, sin modificar)
├── data.sql                (heredado)
├── queries.sql              (heredado, consultas de negocio)
├── indices.sql              (Parte A)
├── views.sql                (Partes B)
├── materializadas.sql       (Parte C)
├── specs/                   (especificaciones de Kiro)
├── duia.md                  (bitácora de uso de IA — A, B y C)
├── informe_mediciones.md    (mediciones antes/después — A, B y C)
├── images/                  (evidencia de la verificación de la Parte B)
└── README.md                (este archivo)
```
