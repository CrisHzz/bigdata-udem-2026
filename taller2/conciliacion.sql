-- TALLER 2 · conciliacion.sql
-- Equipo: CrisHzz · Anfitrión: Cristian Camilo Hernandez
--
-- Compruebo que las cifras cuadran de una capa a la siguiente, para la corrida final de
-- pipeline_taxi (glue_small, limite = todos, mes = 2024-01). Antes de esa corrida reseteé dev,
-- así que bronze tiene un solo lote.
-- Las consultas 1 y 2 van en Athena (workgroup bigdata-wg, base bigdata_lake); las demás en
-- Snowflake.


-- =====================================================================
-- 1. BRONZE -> SILVER (Athena)
-- =====================================================================

-- Filas de bronze del mes.
SELECT count(*) AS filas
FROM bigdata_lake.dev_bronze_fhvhv
WHERE mes = '2024-01';

-- Resultado: 19 663 930, igual a lo que bronze anotó en la tabla de control.


-- Descartes por tipo: aplico los filtros de limpiar_viajes (silver.py) en el mismo orden, así
-- cada fila cae en el primer filtro que no pasa y ningún descarte se cuenta dos veces.
SELECT
    CASE
        WHEN pickup_datetime IS NULL                              THEN '1 sin fecha de recogida'
        WHEN pulocationid IS NULL                                 THEN '2 sin zona de recogida'
        WHEN trip_miles IS NULL OR trip_miles <= 0                THEN '3 distancia 0 o nula'
        WHEN trip_miles >= 100                                    THEN '4 distancia de 100 mi o más'
        WHEN base_passenger_fare IS NULL OR base_passenger_fare <= 0
                                                                  THEN '5 tarifa 0 o negativa'
        WHEN trip_time IS NULL
          OR CAST(trip_time AS double) / 60 NOT BETWEEN 1 AND 180  THEN '6 duración fuera de 1 a 180 min'
        WHEN pickup_datetime <  TIMESTAMP '2024-01-01 00:00:00'
          OR pickup_datetime >= TIMESTAMP '2024-02-01 00:00:00'   THEN '7 fuera de enero'
        ELSE '0 válido (pasa a silver)'
    END AS motivo,
    count(*) AS filas
FROM bigdata_lake.dev_bronze_fhvhv
WHERE mes = '2024-01'
GROUP BY 1
ORDER BY 1;

-- Resultado (185,81 MB analizados):
--   0 válido (pasa a silver)          19 650 023
--   3 distancia 0 o nula                   3 286
--   4 distancia de 100 mi o más            1 660
--   5 tarifa 0 o negativa                  7 331
--   6 duración fuera de 1 a 180 min        1 630
--
-- Cuadra: 19 663 930 de bronze - 13 907 descartes = 19 650 023, justo lo que escribió silver.
-- Los descartes son el 0,07 % de los viajes y la mitad son por tarifa. No hubo viajes sin fecha,
-- sin zona ni fuera de enero, y ninguno se perdió por duplicado (bronze tiene un solo lote).


-- =====================================================================
-- 2. LA TABLA DE CONTROL (Snowflake)
-- =====================================================================

USE ROLE BIGDATA_DEV;
USE WAREHOUSE BIGDATA_WH;
USE DATABASE BIGDATA;

-- El último registro de cada tabla, capa y mes (reprocesar no borra filas viejas).
SELECT TABLA, CAPA, MES, FILAS, LEIDAS, COMPUTO, LIMITE, INICIO
FROM BIGDATA.CONTROL_DEV.WATERMARK
QUALIFY ROW_NUMBER() OVER (PARTITION BY TABLA, CAPA, MES ORDER BY INICIO DESC) = 1
ORDER BY CAPA, TABLA, MES;

-- Resultado (todas con glue_small y limite = todos):
--   TABLA                        CAPA       MES       FILAS       LEIDAS
--   clima                        bronze     2024-01          31           31
--   fhvhv                        bronze     2024-01  19 663 930   19 663 930
--   taxi_zones                   bronze     sin_mes         265          265
--   clima                        silver     2024-01          31           31
--   fhvhv                        silver     2024-01  19 650 023   19 663 930
--   taxi_zones                   silver     sin_mes         265          265
--   crishzz_propina_por_lluvia   gold       2024-01         373   19 650 023
--   tarifa_por_milla_barrio      gold       2024-01         744   19 650 023
--   crishzz_propina_por_lluvia   snowflake  2024-01         373          373
--   tarifa_por_milla_barrio      snowflake  2024-01         744          744
--
-- Silver leyó lo mismo que escribió bronze. Clima y zonas pasan sin cambios (31 días y 265
-- zonas), y por eso al unirlos gold no multiplica viajes. En gold, FILAS cuenta grupos y no
-- viajes; los viajes los comparo abajo.


-- =====================================================================
-- 3. SILVER -> GOLD -> SNOWFLAKE (Snowflake)
-- =====================================================================

SELECT 'casa'   AS TABLA, COUNT(*) AS FILAS, SUM(VIAJES) AS VIAJES
FROM BIGDATA.DEV.TARIFA_POR_MILLA_BARRIO
UNION ALL
SELECT 'equipo', COUNT(*), SUM(VIAJES)
FROM BIGDATA.DEV.CRISHZZ_PROPINA_POR_LLUVIA;

-- Resultado:
--   casa     744 filas   19 650 023 viajes
--   equipo   373 filas   19 650 023 viajes
--
-- Silver -> gold: las dos tablas suman los 19 650 023 viajes que escribió silver. Agrupar no
-- perdió ni duplicó viajes.
-- Gold -> Snowflake: 744 y 373 filas, las mismas que escribió gold según la tabla de control.
--
-- Además, 19 650 023 es el total de viajes de enero del Taller 1: mi pipeline, que parte del
-- archivo crudo, llega a la misma cifra que el paquete del curso.
