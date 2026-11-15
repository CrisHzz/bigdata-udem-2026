-- GRANO: una fila por FECHA, ZONA y EMPRESA (un día de una zona para una empresa). 46 715 filas, igual que el gold.
-- =====================================================================
-- TALLER 1 · 01_estrella.sql · DDL de la estrella
-- Equipo: Cristian Camilo Hernandez · Anfitrión: Cristian Camilo Hernandez · Caso elegido: B
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
CREATE SCHEMA IF NOT EXISTS CURSO.T1;
USE SCHEMA CURSO.T1;

-- DIM_EMPRESA: la clave es el nombre de la empresa. Se llena con SELECT DISTINCT (02_carga.sql).
CREATE OR REPLACE TABLE DIM_EMPRESA (
    EMPRESA_KEY VARCHAR NOT NULL PRIMARY KEY,  -- nombre de la empresa (Uber / Lyft)
    EMPRESA     VARCHAR NOT NULL
);

-- DIM_ZONA: la clave es el nombre de la zona (así la identifica el gold).
--   Trampa 4: el lookup del Lab 4 repite 2 nombres (Corona; Governor's/Ellis/Liberty Island).
--   Dejo una fila por nombre con SELECT DISTINCT para no inflar los viajes al unir (262 filas).
CREATE OR REPLACE TABLE DIM_ZONA (
    ZONA_KEY      VARCHAR NOT NULL PRIMARY KEY,  -- nombre de la zona
    ZONA          VARCHAR NOT NULL,
    BOROUGH       VARCHAR,                       -- distrito de NYC
    SERVICE_ZONE  VARCHAR                        -- tipo de zona
);

-- DIM_FECHA: un día por fila. La lluvia va aquí una sola vez por día (trampa 1), no en el hecho.
CREATE OR REPLACE TABLE DIM_FECHA (
    FECHA          DATE    NOT NULL PRIMARY KEY,
    ANIO           NUMBER  NOT NULL,
    MES            NUMBER  NOT NULL,
    DIA_SEMANA     NUMBER  NOT NULL,             -- 1 = lunes ... 7 = domingo
    NOMBRE_DIA     VARCHAR NOT NULL,
    FIN_DE_SEMANA  BOOLEAN NOT NULL,
    ES_FESTIVO     BOOLEAN NOT NULL,
    NOMBRE_FESTIVO VARCHAR,
    LLUVIA_MM      FLOAT
);

-- FACT_VIAJES_DIA: las llaves de las dimensiones y solo medidas aditivas.
--   No guardo los promedios, sino sus sumas (promedio * viajes), para rehacer el promedio
--   ponderado con SUM(.)/SUM(VIAJES). La lluvia no va aquí.
CREATE OR REPLACE TABLE FACT_VIAJES_DIA (
    FECHA          DATE    NOT NULL,  -- -> DIM_FECHA
    ZONA_KEY       VARCHAR NOT NULL,  -- -> DIM_ZONA
    EMPRESA_KEY    VARCHAR NOT NULL,  -- -> DIM_EMPRESA
    VIAJES         NUMBER  NOT NULL,
    INGRESO_TOTAL  FLOAT   NOT NULL,
    SUMA_PROPINA   FLOAT,             -- PROPINA_PROMEDIO * VIAJES
    SUMA_DISTANCIA FLOAT,             -- DISTANCIA_PROMEDIO * VIAJES
    PRIMARY KEY (FECHA, ZONA_KEY, EMPRESA_KEY)
);

-- Claves (cómo une cada dimensión con el hecho y por qué es única):
--   DIM_EMPRESA  FACT.EMPRESA_KEY = DIM_EMPRESA.EMPRESA_KEY. Única: un SELECT DISTINCT del nombre.
--   DIM_ZONA     FACT.ZONA_KEY    = DIM_ZONA.ZONA_KEY.       Única: una fila por nombre (262, trampa 4).
--   DIM_FECHA    FACT.FECHA       = DIM_FECHA.FECHA.          Única: un día por fila (91 días).
