-- TALLER 2 · respuesta.sql
-- Equipo: CrisHzz · Anfitrión: Cristian Camilo Hernandez
--
-- Pregunta: en enero de 2024, ¿la propina por viaje es mayor en días de lluvia fuerte
-- (más de 10 mm) que en días secos?
-- Tabla: BIGDATA.DEV.CRISHZZ_PROPINA_POR_LLUVIA (glue_small, limite = todos, mes = 2024-01).
-- La propina la pondero con SUM/SUM y los días los cuento con COUNT(DISTINCT FECHA).

USE ROLE BIGDATA_DEV;
USE WAREHOUSE BIGDATA_WH;
USE DATABASE BIGDATA;

WITH POR_NIVEL AS (
    SELECT
        NIVEL_LLUVIA,
        COUNT(DISTINCT FECHA)                       AS DIAS,
        SUM(VIAJES)                                 AS VIAJES,
        SUM(PROPINA_TOTAL) / SUM(VIAJES)            AS PROPINA_POR_VIAJE,
        100 * SUM(VIAJES_CON_PROPINA) / SUM(VIAJES) AS PCT_VIAJES_CON_PROPINA
    FROM BIGDATA.DEV.CRISHZZ_PROPINA_POR_LLUVIA
    GROUP BY NIVEL_LLUVIA
)
SELECT
    NIVEL_LLUVIA,
    DIAS,
    VIAJES,
    ROUND(PROPINA_POR_VIAJE, 3)        AS PROPINA_POR_VIAJE,
    ROUND(PCT_VIAJES_CON_PROPINA, 2)   AS PCT_VIAJES_CON_PROPINA,
    -- la ventana pone la propina de los días secos en todas las filas para comparar
    ROUND(100 * (PROPINA_POR_VIAJE
          / MAX(IFF(NIVEL_LLUVIA = 'seca', PROPINA_POR_VIAJE, NULL)) OVER () - 1), 1)
                                       AS DIFERENCIA_VS_SECA_PCT
FROM POR_NIVEL
ORDER BY NIVEL_LLUVIA;

-- Resultado:
--   fuerte    5 días   3 355 026 viajes   1.005 USD   19.03 %   -2.7 %
--   ligera   13 días   8 237 482 viajes   1.103 USD   19.31 %   +6.8 %
--   seca     13 días   8 057 515 viajes   1.033 USD   18.60 %    0.0 %
-- Los días suman 31 y los viajes 19 650 023, igual que silver.
--
-- En el total, con lluvia fuerte la propina por viaje fue 1,005 USD contra 1,033 USD en días
-- secos, un 2,7 % menos. Pero la consulta de abajo muestra que esa caída viene de qué días
-- llovió y no de la lluvia.


-- ¿Pesa el día de la semana? 3 de los 5 días de lluvia fuerte fueron fin de semana.
SELECT
    IFF(DAYOFWEEKISO(FECHA) >= 6, 'fin de semana', 'entre semana')  AS TIPO_DIA,
    NIVEL_LLUVIA,
    COUNT(DISTINCT FECHA)                                           AS DIAS,
    ROUND(SUM(PROPINA_TOTAL) / SUM(VIAJES), 3)                      AS PROPINA_POR_VIAJE
FROM BIGDATA.DEV.CRISHZZ_PROPINA_POR_LLUVIA
GROUP BY TIPO_DIA, NIVEL_LLUVIA
ORDER BY TIPO_DIA, NIVEL_LLUVIA;

-- Resultado:
--   entre semana    fuerte    2 días   1.075
--   entre semana    ligera   11 días   1.118
--   entre semana    seca     10 días   1.071
--   fin de semana   fuerte    3 días   0.967
--   fin de semana   ligera    2 días   1.016
--   fin de semana   seca      3 días   0.936
-- Los días suman 31; los de fin de semana son 8 (los 4 sábados y 4 domingos de enero).
--
-- Comparando días del mismo tipo, la lluvia fuerte no baja la propina: entre semana queda
-- igual (+0,4 %) y el fin de semana sube un poco (+3,3 %). El -2,7 % del total salía porque
-- el fin de semana se deja menos propina, y 3 de los 5 días de lluvia fuerte fueron fin de
-- semana, mientras que 10 de los 13 días secos fueron entre semana (paradoja de Simpson).
--
-- Respuesta: la lluvia fuerte no baja la propina por viaje; si tiene efecto, es pequeño y hacia
-- arriba. Con 2 y 3 días por grupo no lo puedo afirmar: mi hipótesis no se confirma ni se
-- descarta con un solo mes.
