-- =====================================================================
-- TALLER 1 · 04_chequeos.sql · Controles de integridad de la estrella
-- =====================================================================
-- Un solo archivo ejecutable (Run All). Cubre el núcleo y el reto R4.
--
--   PARTE 1 · Los cuatro controles del enunciado (sección 15): filas, grano, sin zona huérfana
--             y viajes totales.
--   PARTE 2 · Controles extra (reto R4): huérfanos de fecha y de empresa, claves únicas en cada
--             dimensión, reconciliación contra el origen (CURSO.LAB4) y la lluvia fuera del hecho.
--   PARTE 3 · Reconciliación por mes contra el conteo del paquete (README, sección 3).
--
-- CÓMO LEER EL RESULTADO
--   Cada fila trae HECHO (lo que medimos), ESPERADO (lo que debe dar) y RESULTADO:
--   OK = coincide; REVISAR = no coincide.
--   Si `filas` o `viajes` no coinciden, revisa la trampa 4; si `grano` es menor que `filas`,
--   hay duplicados.
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;


-- =====================================================================
-- PARTE 1 y PARTE 2 · Controles de integridad
-- =====================================================================

WITH CONTROLES AS (

    -- ---------------- PARTE 1 · los cuatro del enunciado ----------------

    -- Filas: una por fecha, zona y empresa, igual que el gold.
    SELECT 1 AS ORDEN, 'filas' AS CONTROL, COUNT(*) AS HECHO, 46715 AS ESPERADO
    FROM FACT_VIAJES_DIA

    UNION ALL

    -- Grano: cada combinación fecha|zona|empresa aparece una sola vez.
    SELECT 2, 'grano', COUNT(DISTINCT FECHA || '|' || ZONA_KEY || '|' || EMPRESA_KEY), 46715
    FROM FACT_VIAJES_DIA

    UNION ALL

    -- Sin zona: filas del hecho cuya zona no existe en DIM_ZONA.
    SELECT 3, 'sin zona', COUNT(*), 0
    FROM FACT_VIAJES_DIA F
    LEFT JOIN DIM_ZONA Z
      ON F.ZONA_KEY = Z.ZONA_KEY
    WHERE Z.ZONA_KEY IS NULL

    UNION ALL

    -- Viajes: el total del paquete.
    SELECT 4, 'viajes', SUM(VIAJES), 60268466
    FROM FACT_VIAJES_DIA

    -- ---------------- PARTE 2 · controles extra (R4) ----------------

    UNION ALL

    -- Sin fecha: filas del hecho cuya fecha no existe en DIM_FECHA.
    SELECT 5, 'sin fecha', COUNT(*), 0
    FROM FACT_VIAJES_DIA F
    LEFT JOIN DIM_FECHA D
      ON F.FECHA = D.FECHA
    WHERE D.FECHA IS NULL

    UNION ALL

    -- Sin empresa: filas del hecho cuya empresa no existe en DIM_EMPRESA.
    SELECT 6, 'sin empresa', COUNT(*), 0
    FROM FACT_VIAJES_DIA F
    LEFT JOIN DIM_EMPRESA E
      ON F.EMPRESA_KEY = E.EMPRESA_KEY
    WHERE E.EMPRESA_KEY IS NULL

    UNION ALL

    -- DIM_FECHA: 91 días (31 + 29 + 31) y ninguno repetido.
    SELECT 7, 'dim_fecha · dias', COUNT(*), 91
    FROM DIM_FECHA

    UNION ALL

    SELECT 8, 'dim_fecha · clave repetida', COUNT(*) - COUNT(DISTINCT FECHA), 0
    FROM DIM_FECHA

    UNION ALL

    -- DIM_ZONA: una fila por nombre de zona (trampa 4).
    SELECT 9, 'dim_zona · zonas', COUNT(*), 262
    FROM DIM_ZONA

    UNION ALL

    SELECT 10, 'dim_zona · clave repetida', COUNT(*) - COUNT(DISTINCT ZONA_KEY), 0
    FROM DIM_ZONA

    UNION ALL

    -- DIM_EMPRESA: tantas empresas como trae el gold (construida con SELECT DISTINCT).
    SELECT 11, 'dim_empresa · empresas', COUNT(*),
           (SELECT COUNT(DISTINCT EMPRESA) FROM CURSO.LAB4.DAILY_ZONE_METRICS)
    FROM DIM_EMPRESA

    UNION ALL

    SELECT 12, 'dim_empresa · clave repetida', COUNT(*) - COUNT(DISTINCT EMPRESA_KEY), 0
    FROM DIM_EMPRESA

    UNION ALL

    -- Reconciliación con el origen: los viajes del hecho contra los del gold del Lab 4.
    SELECT 13, 'viajes vs origen',
           (SELECT SUM(VIAJES) FROM FACT_VIAJES_DIA),
           (SELECT SUM(VIAJES) FROM CURSO.LAB4.DAILY_ZONE_METRICS)

    UNION ALL

    -- Ingreso contra el origen. Es FLOAT: no se compara con =, se mide la diferencia
    --     redondeada a 2 decimales (trampa 3).
    SELECT 14, 'ingreso · diferencia vs origen',
           ROUND(ABS((SELECT SUM(INGRESO_TOTAL) FROM FACT_VIAJES_DIA)
                   - (SELECT SUM(INGRESO_TOTAL) FROM CURSO.LAB4.DAILY_ZONE_METRICS)), 2),
           0

    UNION ALL

    -- La lluvia no está en el hecho (trampa 1): la columna LLUVIA_MM no debe existir ahí.
    SELECT 15, 'lluvia fuera del hecho', COUNT(*), 0
    FROM CURSO.INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'T1'
      AND TABLE_NAME   = 'FACT_VIAJES_DIA'
      AND COLUMN_NAME  = 'LLUVIA_MM'
)
SELECT
    CONTROL,
    HECHO,
    ESPERADO,
    IFF(HECHO = ESPERADO, 'OK', 'REVISAR') AS RESULTADO
FROM CONTROLES
ORDER BY ORDEN;

-- Salida esperada: 15 filas, todas con RESULTADO = OK.
-- Las cuatro primeras son las del enunciado (sección 15):
--   filas 46715 · grano 46715 · sin zona 0 · viajes 60268466


-- =====================================================================
-- PARTE 3 · Reconciliación por mes contra el conteo del paquete
-- =====================================================================
-- Los números esperados son los del README (sección 3). Se escriben con VALUES, igual que en
-- el ejercicio C8 del Lab 3C.

WITH ESPERADO AS (
    SELECT *
    FROM VALUES
        ('2024-01', 15909, 19650023),
        ('2024-02', 14889, 19344724),
        ('2024-03', 15917, 21273719)
        AS V(MES, FILAS, VIAJES)
),
MEDIDO AS (
    SELECT
        TO_CHAR(FECHA, 'YYYY-MM') AS MES,
        COUNT(*)                  AS FILAS,
        SUM(VIAJES)               AS VIAJES
    FROM FACT_VIAJES_DIA
    GROUP BY 1
)
SELECT
    E.MES,
    M.FILAS                                                         AS FILAS_HECHO,
    E.FILAS                                                         AS FILAS_PAQUETE,
    M.VIAJES                                                        AS VIAJES_HECHO,
    E.VIAJES                                                        AS VIAJES_PAQUETE,
    IFF(M.FILAS = E.FILAS AND M.VIAJES = E.VIAJES, 'OK', 'REVISAR')  AS RESULTADO
FROM ESPERADO E
LEFT JOIN MEDIDO M
  ON E.MES = M.MES
ORDER BY E.MES;

-- Salida esperada: 3 filas (enero, febrero y marzo), las tres en OK.
-- Si un mes sale vacío o en REVISAR, la carga de ese mes quedó incompleta o duplicada.
