# Costos · Taller 1

Equipo: Cristian Camilo Hernandez · Cuenta que reporta (anfitrión): Cristian Camilo Hernandez

## Créditos usados

> Corre esta consulta en la cuenta del anfitrión (ajusta la fecha si mides otro día) y pega el resultado.
> Nota: la función va con la ruta completa `SNOWFLAKE.INFORMATION_SCHEMA`; `INFORMATION_SCHEMA` a secas
> apunta a la base actual (CURSO) y da el error «Invalid identifier».

```sql
SELECT ROUND(SUM(CREDITS_USED), 4) AS CREDITOS
FROM TABLE(SNOWFLAKE.INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
       DATE_RANGE_START => '2026-11-12'::DATE,
       WAREHOUSE_NAME => 'COMPUTE_WH'));
```

| Día medido | Warehouse | Tamaño | Créditos |
|---|---|---|---|
| 2026-11-12 | COMPUTE_WH | XS | 0.5400 |

Referencia de presupuesto (estimación del pensum, no medida): hasta 0.3 créditos el Lab 4 y hasta 0.8 el taller en clase. Mis 0.54 créditos quedan dentro de ese margen.

## Consulta más pesada

- Consulta: el INSERT de DIM_ZONA en `02_carga.sql` (la carga de la dimensión de zonas):

  ```sql
  INSERT INTO DIM_ZONA (ZONA_KEY, ZONA, BOROUGH, SERVICE_ZONE)
  SELECT DISTINCT ZONA AS ZONA_KEY, ZONA, BOROUGH, SERVICE_ZONE
  FROM CURSO.LAB4.DIM_ZONA;
  ```

- Duración: 2.0 s. Query ID: 01c8659c-0109-cae7-0012-b4d6000afe72. Warehouse X-Small.
- Cómo la encontraste: Snowsight > Monitoring > Query History > ordenar por Duration (de mayor a menor).
- Captura del Query Profile: `query_profile.png` (en esta carpeta).
- Por qué pesa más que las preguntas: tiene un SELECT DISTINCT sobre las 265 filas del lookup
  (quita los 3 nombres repetidos de la trampa 4) y fue la primera consulta pesada de la sesión,
  así que su tiempo incluye el arranque del warehouse. Aun así son solo 2.0 s.

## Lectura del Query Profile

- Operador que concentra el tiempo: TableScan sobre CURSO.LAB4.DIM_ZONA, 50 % del perfil (leer
  las 265 filas del lookup). Le sigue Insert con 12.5 % (escribir las 262 filas en
  CURSO.T1.DIM_ZONA). El Aggregate que hace el SELECT DISTINCT marca 0 %: quitar los 3 nombres
  repetidos (265 -> 262 filas) es instantáneo. El perfil muestra el flujo de la trampa 4: entran
  265 filas, salen 262.
- Qué harías para reducirlo: nada. El TableScan es de 265 filas, trivial, y la carga se corre
  una sola vez; 2.0 s es sobre todo el arranque del warehouse. Que el Aggregate del DISTINCT sea
  0 % confirma que resolver la trampa 4 no cuesta nada de rendimiento.

## Warehouse

COMPUTE_WH, tamaño X-Small, con suspensión automática a los 60 s (AUTO_SUSPEND = 60) y AUTO_RESUME activo, tal como lo deja el Paso 0 del Lab 4. 