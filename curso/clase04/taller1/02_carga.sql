-- =====================================================================
-- TALLER 1 · 02_carga.sql · Carga reproducible desde el Lab 4
-- Equipo: Cristian Camilo Hernandez · Anfitrión: Cristian Camilo Hernandez · Caso elegido: B
-- =====================================================================
-- Carga las dimensiones primero y el hecho al final. Se puede correr más de una vez (TRUNCATE
-- antes de cada INSERT). Origen: CURSO.LAB4 (DAILY_ZONE_METRICS, DIM_ZONA, FESTIVOS_2024).
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;

-- DIM_EMPRESA: una fila por empresa, con SELECT DISTINCT (no se escriben "Uber"/"Lyft" a mano).
TRUNCATE TABLE IF EXISTS DIM_EMPRESA;
INSERT INTO DIM_EMPRESA (EMPRESA_KEY, EMPRESA)
SELECT DISTINCT EMPRESA AS EMPRESA_KEY, EMPRESA
FROM CURSO.LAB4.DAILY_ZONE_METRICS;

-- DIM_ZONA: una fila por nombre de zona (trampa 4). El DISTINCT sobre (ZONA, BOROUGH,
-- SERVICE_ZONE) colapsa los 2 nombres repetidos del lookup y deja 262 filas únicas.
TRUNCATE TABLE IF EXISTS DIM_ZONA;
INSERT INTO DIM_ZONA (ZONA_KEY, ZONA, BOROUGH, SERVICE_ZONE)
SELECT DISTINCT ZONA AS ZONA_KEY, ZONA, BOROUGH, SERVICE_ZONE
FROM CURSO.LAB4.DIM_ZONA;

-- DIM_FECHA: los 91 días del rango del gold. La lluvia del día una sola vez con MAX(LLUVIA_MM);
-- el festivo sale del cruce con FESTIVOS_2024; fin de semana = sábado(6) o domingo(7).
TRUNCATE TABLE IF EXISTS DIM_FECHA;
INSERT INTO DIM_FECHA (FECHA, ANIO, MES, DIA_SEMANA, NOMBRE_DIA, FIN_DE_SEMANA, ES_FESTIVO, NOMBRE_FESTIVO, LLUVIA_MM)
WITH
rango AS (
  SELECT MIN(FECHA) AS MINF, MAX(FECHA) AS MAXF
  FROM CURSO.LAB4.DAILY_ZONE_METRICS
),
dias AS (
  SELECT DATEADD('day', ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, MINF) AS FECHA
  FROM rango, TABLE(GENERATOR(ROWCOUNT => 400))
  QUALIFY FECHA <= MAXF
),
lluvia_dia AS (
  SELECT FECHA, MAX(LLUVIA_MM) AS LLUVIA_MM
  FROM CURSO.LAB4.DAILY_ZONE_METRICS
  GROUP BY FECHA
)
SELECT
  d.FECHA,
  YEAR(d.FECHA)                                   AS ANIO,
  MONTH(d.FECHA)                                  AS MES,
  DAYOFWEEKISO(d.FECHA)                           AS DIA_SEMANA,
  DAYNAME(d.FECHA)                                AS NOMBRE_DIA,
  (DAYOFWEEKISO(d.FECHA) >= 6)                    AS FIN_DE_SEMANA,
  (f.FECHA IS NOT NULL)                           AS ES_FESTIVO,
  f.NOMBRE                                        AS NOMBRE_FESTIVO,
  l.LLUVIA_MM                                     AS LLUVIA_MM
FROM dias d
LEFT JOIN lluvia_dia l                ON l.FECHA = d.FECHA
LEFT JOIN CURSO.LAB4.FESTIVOS_2024 f  ON f.FECHA = d.FECHA;

-- FACT_VIAJES_DIA: el gold ya está al grano fecha × zona × empresa; el GROUP BY lo deja
-- idempotente. Medidas aditivas; los promedios se guardan como sumas (promedio * viajes).
TRUNCATE TABLE IF EXISTS FACT_VIAJES_DIA;
INSERT INTO FACT_VIAJES_DIA (FECHA, ZONA_KEY, EMPRESA_KEY, VIAJES, INGRESO_TOTAL, SUMA_PROPINA, SUMA_DISTANCIA)
SELECT
  FECHA,
  ZONA                              AS ZONA_KEY,
  EMPRESA                           AS EMPRESA_KEY,
  SUM(VIAJES)                       AS VIAJES,
  SUM(INGRESO_TOTAL)                AS INGRESO_TOTAL,
  SUM(PROPINA_PROMEDIO * VIAJES)    AS SUMA_PROPINA,
  SUM(DISTANCIA_PROMEDIO * VIAJES)  AS SUMA_DISTANCIA
FROM CURSO.LAB4.DAILY_ZONE_METRICS
GROUP BY FECHA, ZONA, EMPRESA;

-- Conteo de control: debe dar 46715 filas y 60268466 viajes.
SELECT COUNT(*) AS FILAS, SUM(VIAJES) AS VIAJES
FROM CURSO.T1.FACT_VIAJES_DIA;
