-- =====================================================================
-- TALLER 1 · 03_preguntas.sql · Las cinco preguntas del caso
-- =====================================================================
-- Caso elegido: B · Clima y festivos
-- Pregunta guía: ¿cuándo se dispara o se cae la demanda?
--
-- Ventanas usadas (el enunciado pide al menos estas tres):
--   B2 · LAG            -> comparar cada día con el día anterior
--   B3 · AVG() OVER     -> media móvil de 7 días
--   B4 · RANK + QUALIFY -> top 3 de zonas por día de la semana
--
-- Tablas: todo sale de la estrella en CURSO.T1 (FACT_VIAJES_DIA + DIM_FECHA).
--   La lluvia y los festivos ya están en DIM_FECHA, una sola vez por día.
--
-- Cada pregunta lleva su enunciado arriba, su consulta y, debajo, un comentario que interprete
-- el resultado (qué dice el número y qué no dice).
-- =====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA CURSO.T1;


-- ---------------------------------------------------------------------
-- Pregunta B1: Viajes por día con lluvia y sin lluvia, sin contar filas como días.
-- ---------------------------------------------------------------------
-- Sumo los viajes por día antes de unir con DIM_FECHA, así COUNT(*) cuenta días y no filas
-- (trampa 1). Definición: un día "con lluvia" es un día con LLUVIA_MM > 0.

WITH VIAJES_DIA AS (
    SELECT
        FECHA,
        SUM(VIAJES) AS VIAJES
    FROM FACT_VIAJES_DIA
    GROUP BY FECHA
)
SELECT
    IFF(D.LLUVIA_MM > 0, 'Con lluvia', 'Sin lluvia') AS TIPO_DIA,
    COUNT(*)                                        AS DIAS,
    SUM(V.VIAJES)                                   AS VIAJES_TOTALES,
    ROUND(AVG(V.VIAJES), 0)                         AS VIAJES_POR_DIA
FROM VIAJES_DIA V
JOIN DIM_FECHA D
  ON V.FECHA = D.FECHA
GROUP BY TIPO_DIA
ORDER BY TIPO_DIA;

-- Resultado:
--   TIPO_DIA     DIAS   VIAJES_TOTALES   VIAJES_POR_DIA
--   Con lluvia     48       32 553 003          678 188
--   Sin lluvia     43       27 715 463          644 546
-- Control: 48 + 43 = 91 días y 32 553 003 + 27 715 463 = 60 268 466 viajes (el total del paquete).
--
-- Interpretación: un día con lluvia tuvo en promedio 678 188 viajes y un día sin lluvia
--   644 546: unos 33 600 viajes más, un 5.2 % más. La lluvia no espanta la demanda de Uber y
--   Lyft; si acaso la sube un poco, quizá porque con lluvia menos gente camina o espera el bus.
--   Se compara VIAJES_POR_DIA y no VIAJES_TOTALES porque los grupos tienen distinto número de
--   días (48 frente a 43).
--   Qué NO dice: no prueba que la lluvia cause el aumento. No separa lluvia leve de fuerte
--   (cualquier día con más de 0 mm cuenta como "con lluvia") ni controla el día de la semana:
--   si los días lluviosos cayeron más en viernes o sábado, eso solo ya sube el promedio. El reto
--   R3 compara contra el mismo día de la semana para quitar ese efecto.


-- ---------------------------------------------------------------------
-- Pregunta B2: Días con un salto de más de 50 % frente al día anterior.
-- ---------------------------------------------------------------------
-- Armo la serie completa zona × día (0 en los días sin viajes) para que LAG mire el día
-- anterior y no la fila anterior. Solo cuento zonas con al menos 100 viajes el día previo: sin
-- ese piso, pasar de 2 a 4 viajes ya sería "+100 %" y llenaría la lista.

WITH VIAJES_ZONA_DIA AS (
    SELECT
        FECHA,
        ZONA_KEY,
        SUM(VIAJES) AS VIAJES
    FROM FACT_VIAJES_DIA
    GROUP BY FECHA, ZONA_KEY
),
ZONAS_POR_DIA AS (
    -- cada zona del hecho 
    SELECT
        Z.ZONA_KEY,
        D.FECHA
    FROM (SELECT DISTINCT ZONA_KEY FROM FACT_VIAJES_DIA) Z,
         DIM_FECHA D
),
SERIE_COMPLETA AS (
    -- los días sin viajes quedan con 0
    SELECT
        G.ZONA_KEY,
        G.FECHA,
        COALESCE(V.VIAJES, 0) AS VIAJES
    FROM ZONAS_POR_DIA G
    LEFT JOIN VIAJES_ZONA_DIA V
      ON  V.ZONA_KEY = G.ZONA_KEY
      AND V.FECHA    = G.FECHA
)
SELECT
    ZONA_KEY                                                    AS ZONA,
    FECHA,
    VIAJES,
    LAG(VIAJES) OVER (PARTITION BY ZONA_KEY ORDER BY FECHA)     AS VIAJES_DIA_ANTERIOR,
    IFF(VIAJES_DIA_ANTERIOR > 0,
        ROUND((VIAJES - VIAJES_DIA_ANTERIOR) / VIAJES_DIA_ANTERIOR * 100, 1),
        NULL)                                                   AS VARIACION_PCT
FROM SERIE_COMPLETA
QUALIFY VIAJES_DIA_ANTERIOR >= 100
    AND VARIACION_PCT > 50
ORDER BY VARIACION_PCT DESC;

-- Resultado: 394 saltos (zona y día) de más de 50 %, repartidos en 52 fechas.
--   Los más grandes: Rockaway Park el 2024-03-02 (441 -> 1 851, +319.7 %) y Prospect Park el
--   mismo día (312 -> 1 218, +290.4 %).
--   Por día de la semana: miércoles 145, sábado 128, domingo 55, martes 27, lunes 26,
--   jueves 7 y viernes 6.
--
-- Interpretación: los saltos no son al azar; casi todos siguen el calendario.
--   1. Un día fuera de serie: el miércoles 2024-02-14 tiene 143 de los 394 saltos (36 %), en
--      zonas de los cinco distritos. Cuando tantas zonas saltan a la vez es un evento de toda la
--      ciudad. Es San Valentín, pero sobre todo el día anterior (martes 2024-02-13) hubo una
--      tormenta de nieve: unos 3 pulgadas (7.6 cm) en Central Park y las escuelas públicas
--      cerraron sus edificios y pasaron a clases remotas (fuentes: AP News y NYC Public
--      Schools). La demanda se hundió ese día y rebotó al siguiente. El salto dice más del
--      martes 13 (un día muy bajo) que del miércoles 14.
--   2. Los sábados: 128 saltos en zonas de vida nocturna (East Village, Lower East Side,
--      Williamsburg, West Village). La fecha es la de recogida, así que el sábado suma la
--      salida del viernes en la noche y la madrugada.
--   3. Los domingos en LaGuardia: 11 de sus 13 saltos son domingos (gente que vuelve a la
--      ciudad el fin de semana). El otro, el lunes 2024-02-19 (festivo), cierra un fin de
--      semana largo.
--   4. Los domingos en Borough Park, South Williamsburg y Ocean Parkway South: sus 35 saltos
--      caen en domingo. Son barrios judíos ortodoxos; el sábado (Shabat) casi no se usan estas
--      plataformas y el domingo la demanda vuelve. El mayor es el 2024-03-24 (Borough Park
--      +166.4 %), día de Purim.
--   5. Los lunes y martes en Midtown Center y Midtown East: es la vuelta a la oficina después
--      del fin de semana. Los martes 2024-01-16 y 2024-02-20 son el día después de un festivo.
--   Qué NO dice: una variación grande sobre un día anterior muy bajo exagera el cambio (el
--   piso de 100 viajes lo reduce, pero no lo quita). Las causas (la nevada, Shabat, Purim) son
--   hipótesis mía a partir del calendario; los datos no las prueban.


-- ---------------------------------------------------------------------
-- Pregunta B3: Media móvil de 7 días de viajes por zona.
-- ---------------------------------------------------------------------
-- Misma serie completa de B2. ROWS BETWEEN 6 PRECEDING AND CURRENT ROW promedia el día y los 6
-- anteriores; como la serie no tiene huecos, 7 filas = 7 días. Los primeros 6 días de enero
-- promedian menos de 7 (no hay días antes del 1 de enero).

WITH VIAJES_ZONA_DIA AS (
    SELECT
        FECHA,
        ZONA_KEY,
        SUM(VIAJES) AS VIAJES
    FROM FACT_VIAJES_DIA
    GROUP BY FECHA, ZONA_KEY
),
ZONAS_POR_DIA AS (
    -- cada zona del hecho 
    SELECT
        Z.ZONA_KEY,
        D.FECHA
    FROM (SELECT DISTINCT ZONA_KEY FROM FACT_VIAJES_DIA) Z,
         DIM_FECHA D
),
SERIE_COMPLETA AS (
    -- los días sin viajes quedan con 0
    SELECT
        G.ZONA_KEY,
        G.FECHA,
        COALESCE(V.VIAJES, 0) AS VIAJES
    FROM ZONAS_POR_DIA G
    LEFT JOIN VIAJES_ZONA_DIA V
      ON  V.ZONA_KEY = G.ZONA_KEY
      AND V.FECHA    = G.FECHA
)
SELECT
    ZONA_KEY AS ZONA,
    FECHA,
    VIAJES,
    ROUND(AVG(VIAJES) OVER (PARTITION BY ZONA_KEY
                            ORDER BY FECHA
                            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS MEDIA_MOVIL_7D
FROM SERIE_COMPLETA
-- WHERE ZONA_KEY = 'JFK Airport'   -- quita el comentario para ver una sola zona
ORDER BY ZONA, FECHA;

-- Resultado (zona de ejemplo: Allerton/Pelham Gardens, Bronx, los 91 días):
--   ZONA                      FECHA        VIAJES   MEDIA_MOVIL_7D
--   Allerton/Pelham Gardens   2024-01-01     1221           1221.0   <- 1 solo día
--   Allerton/Pelham Gardens   2024-01-07     1022           1290.3   <- primera media de 7 días (la más baja)
--   Allerton/Pelham Gardens   2024-02-13     1124           1390.6   <- día de la nevada
--   Allerton/Pelham Gardens   2024-02-16     1830           1508.3   <- rebote después de la nevada
--   Allerton/Pelham Gardens   2024-03-06     1715           1615.3   <- la media más alta
--   Allerton/Pelham Gardens   2024-03-31     1446           1503.1
--   Promedio diario por mes: enero 1 372, febrero 1 474, marzo 1 522.
--   Promedio por día de la semana: domingo 1 265 (el más bajo) ... viernes 1 670 (el más alto).
--
-- Interpretación: en esta zona la demanda crece de enero a marzo. La media de 7 días sube de
--   1 290 viajes (7 de enero) a un máximo de 1 615 (6 de marzo) y cierra marzo en 1 503; por
--   mes, marzo tiene un 10.9 % más de viajes por día que enero.
--   Los viajes de cada día suben y bajan mucho dentro de la semana: un viernes tiene en
--   promedio un 32 % más viajes que un domingo. La media de 7 días borra ese vaivén: cada
--   valor promedia una semana completa (todos los días de la semana una vez), y por eso deja
--   ver la tendencia.
--   La nevada del 13 de febrero se ve en VIAJES (1 124, uno de los días más bajos) y en el
--   rebote de los días siguientes (1 762, 1 649 y 1 830), pero en la media apenas mueve la
--   curva: un solo día pesa 1/7.
--   Qué NO dice: es una sola zona residencial del Bronx; otras zonas (aeropuertos, Midtown)
--   pueden ir distinto. Los primeros 6 días de enero promedian menos de 7 días. Tres meses son
--   poco para separar una tendencia de fondo del cambio de estación (enero frío, marzo más
--   templado).


-- ---------------------------------------------------------------------
-- Pregunta B4: Las tres zonas con más viajes por día de la semana.
-- ---------------------------------------------------------------------
-- RANK ordena las zonas dentro de cada día de la semana y QUALIFY deja el top 3. Comparación
-- justa: 91 días son 13 semanas exactas, así que cada día de la semana suma 13 días.

SELECT
    D.DIA_SEMANA,
    D.NOMBRE_DIA,
    F.ZONA_KEY                                                          AS ZONA,
    SUM(F.VIAJES)                                                       AS VIAJES,
    RANK() OVER (PARTITION BY D.DIA_SEMANA ORDER BY SUM(F.VIAJES) DESC) AS PUESTO
FROM FACT_VIAJES_DIA F
JOIN DIM_FECHA D
  ON F.FECHA = D.FECHA
GROUP BY D.DIA_SEMANA, D.NOMBRE_DIA, F.ZONA_KEY
QUALIFY PUESTO <= 3
ORDER BY D.DIA_SEMANA, PUESTO;

-- Resultado (21 filas, sin empates; viajes sumados en los 13 días de cada tipo):
--   DIA  PUESTO 1                    PUESTO 2                     PUESTO 3
--   Lun  LaGuardia Airport 183 733   JFK Airport 178 146          Crown Heights North 96 031
--   Mar  LaGuardia Airport 150 700   JFK Airport 143 639          Midtown Center 121 410
--   Mié  LaGuardia Airport 156 236   JFK Airport 135 994          Midtown Center 133 008
--   Jue  LaGuardia Airport 167 246   JFK Airport 139 578          Midtown Center 131 049
--   Vie  LaGuardia Airport 156 405   JFK Airport 150 116          East Village 134 771
--   Sáb  East Village 210 123        Lower East Side 159 360      Williamsburg (North Side) 148 078
--   Dom  JFK Airport 179 050         LaGuardia Airport 166 186    East Village 156 747
--
-- Interpretación: la demanda cambia de lugar según el día de la semana.
--   1. Los aeropuertos mandan seis de los siete días. LaGuardia es el primero de lunes a
--      viernes y JFK el segundo; el domingo se invierten y JFK pasa al primer lugar.
--   2. El sábado es el único día sin aeropuertos en el top 3: lo ocupan tres zonas de vida
--      nocturna. East Village el sábado (210 123 viajes, unos 16 200 por sábado) es la cifra
--      más alta de toda la tabla y tiene un 56 % más viajes que el mismo East Village el
--      viernes (134 771).
--   3. De martes a jueves el tercer puesto es Midtown Center, la zona de oficinas: son los
--      días de trabajo presencial. El viernes ya lo toma East Village (empieza el fin de
--      semana) y el lunes no aparece.
--   4. El lunes es raro: LaGuardia tiene su valor más alto de la semana y Midtown Center sale
--      del top 3 (entra Crown Heights North). Una explicación: 3 de los 13 lunes son festivos
--      (1 y 15 de enero y 19 de febrero). Esos días las oficinas cierran y mucha gente vuelve
--      de un fin de semana largo por el aeropuerto. B5 mira esos 3 lunes por separado.
--   Comparación justa: 91 días son 13 semanas exactas, así que cada día de la semana suma
--   13 días y los totales se pueden comparar entre filas.
--   Qué NO dice: es el total de tres meses; no muestra si el orden cambió de un mes a otro.
--   La explicación del lunes es una hipótesis mía; los datos no la prueban.


-- ---------------------------------------------------------------------
-- Pregunta B5: Viajes en festivos frente al promedio del mismo día de la semana.
-- ---------------------------------------------------------------------
-- Comparo cada festivo contra el promedio de los días NO festivos de su mismo día de la semana.
-- Los 3 festivos son lunes, así que van contra los 10 lunes normales.

WITH VIAJES_DIA AS (
    SELECT
        D.FECHA,
        D.DIA_SEMANA,
        D.NOMBRE_DIA,
        D.ES_FESTIVO,
        D.NOMBRE_FESTIVO,
        SUM(F.VIAJES) AS VIAJES
    FROM FACT_VIAJES_DIA F
    JOIN DIM_FECHA D
      ON F.FECHA = D.FECHA
    GROUP BY D.FECHA, D.DIA_SEMANA, D.NOMBRE_DIA, D.ES_FESTIVO, D.NOMBRE_FESTIVO
),
PROMEDIO_NORMAL AS (
    SELECT
        DIA_SEMANA,
        ROUND(AVG(VIAJES), 0) AS VIAJES_PROMEDIO
    FROM VIAJES_DIA
    WHERE NOT ES_FESTIVO
    GROUP BY DIA_SEMANA
)
SELECT
    V.FECHA,
    V.NOMBRE_FESTIVO,
    V.NOMBRE_DIA,
    V.VIAJES,
    P.VIAJES_PROMEDIO                                                     AS PROMEDIO_MISMO_DIA,
    ROUND((V.VIAJES - P.VIAJES_PROMEDIO) / P.VIAJES_PROMEDIO * 100, 1)    AS DIFERENCIA_PCT
FROM VIAJES_DIA V
JOIN PROMEDIO_NORMAL P
  ON V.DIA_SEMANA = P.DIA_SEMANA
WHERE V.ES_FESTIVO
ORDER BY V.FECHA;

-- Resultado:
--   FECHA        NOMBRE_FESTIVO                        DIA   VIAJES   PROMEDIO_MISMO_DIA   DIFERENCIA_PCT
--   2024-01-01   New Year's Day                        Mon   638 085              567 813             12.4
--   2024-01-15   Birthday of Martin Luther King, Jr.   Mon   559 061              567 813             -1.5
--   2024-02-19   Washington's Birthday                 Mon   552 593              567 813             -2.7
-- Control: 3 filas, las tres en lunes. El promedio de comparación son los 10 lunes que no son
--   festivo.
--
-- Interpretación: un festivo no cambia mucho cuántos viajes se hacen en total.
--   1. Martin Luther King (-1.5 %) y Washington's Birthday (-2.7 %) quedan casi igual que un
--      lunes normal: unos 9 000 y 15 000 viajes menos sobre más de 560 000.
--   2. Año Nuevo es la excepción: +12.4 %, unos 70 000 viajes más. La fecha es la de recogida,
--      así que el 1 de enero suma la madrugada de la fiesta de fin de año (la vuelta a casa
--      después de la medianoche).
--   3. Esto ayuda a leer B4: si los lunes festivos mueven casi los mismos viajes que un lunes
--      normal, lo raro del lunes en B4 (LaGuardia en su máximo y Midtown fuera del top 3) no es
--      que haya menos demanda, sino que la demanda cambia de lugar (de la oficina al
--      aeropuerto). Para comprobarlo habría que repetir B4 separando lunes festivos y normales.
--   Qué NO dice: con solo 3 festivos (n = 3) no se puede generalizar; es una señal, no una
--   regla. Además los 3 son lunes, así que no sabemos cómo se comporta un festivo en otro día
--   de la semana.


-- =====================================================================
-- RETOS OPCIONALES 
-- =====================================================================
-- R2 y R3 están aquí. R4 está en 04_chequeos.sql.


-- ---------------------------------------------------------------------
-- Reto R2: DIM_FECHA con festivos y fin de semana, usada en una consulta.
--   ¿Cuántos viajes hay por día entre semana, en fin de semana y en festivo?

WITH VIAJES_DIA AS (
    SELECT
        FECHA,
        SUM(VIAJES) AS VIAJES
    FROM FACT_VIAJES_DIA
    GROUP BY FECHA
)
SELECT
    CASE
        WHEN D.ES_FESTIVO    THEN '3 · Festivo'
        WHEN D.FIN_DE_SEMANA THEN '2 · Fin de semana'
        ELSE                      '1 · Entre semana'
    END                       AS TIPO_DIA,
    COUNT(*)                  AS DIAS,
    SUM(V.VIAJES)             AS VIAJES_TOTALES,
    ROUND(AVG(V.VIAJES), 0)   AS VIAJES_POR_DIA
FROM VIAJES_DIA V
JOIN DIM_FECHA D
  ON V.FECHA = D.FECHA
GROUP BY TIPO_DIA
ORDER BY TIPO_DIA;

-- Resultado:
--   TIPO_DIA            DIAS   VIAJES_TOTALES   VIAJES_POR_DIA
--   1 · Entre semana      62       39 553 169          637 954
--   2 · Fin de semana     26       18 965 558          729 445
--   3 · Festivo            3        1 749 739          583 246
-- Control: 62 + 26 + 3 = 91 días y 60 268 466 viajes (el total del paquete).
--
-- Interpretación: un día de fin de semana tiene un 14.3 % más viajes que uno entre semana
--   (729 445 frente a 637 954). Un festivo tiene un 8.6 % menos que un día entre semana, así
--   que no se parece a un fin de semana. Pero los 3 festivos son lunes, el día más flojo
--   (567 813 un lunes normal, B5): frente a un lunes normal tienen un 2.7 % más. La diferencia
--   viene más de ser lunes que de ser festivo.
--   Qué NO dice: "Festivo" son solo 3 días (n = 3), todos lunes; es una señal, no una regla.


-- ---------------------------------------------------------------------
-- Reto R3: Lluvia fuerte (más de 10 mm) frente a la línea base del mismo día de la semana.
-- ---------------------------------------------------------------------

WITH VIAJES_ZONA_DIA AS (
    SELECT
        FECHA,
        ZONA_KEY,
        SUM(VIAJES) AS VIAJES
    FROM FACT_VIAJES_DIA
    GROUP BY FECHA, ZONA_KEY
),
ZONAS_POR_DIA AS (
    -- cada zona del hecho × cada uno de los 91 días
    SELECT
        Z.ZONA_KEY,
        D.FECHA,
        D.DIA_SEMANA,
        D.NOMBRE_DIA,
        D.LLUVIA_MM
    FROM (SELECT DISTINCT ZONA_KEY FROM FACT_VIAJES_DIA) Z,
         DIM_FECHA D
),
SERIE_COMPLETA AS (
    -- los días sin viajes quedan con 0
    SELECT
        G.ZONA_KEY,
        G.FECHA,
        G.DIA_SEMANA,
        G.NOMBRE_DIA,
        G.LLUVIA_MM,
        COALESCE(V.VIAJES, 0) AS VIAJES
    FROM ZONAS_POR_DIA G
    LEFT JOIN VIAJES_ZONA_DIA V
      ON  V.ZONA_KEY = G.ZONA_KEY
      AND V.FECHA    = G.FECHA
),
CON_LINEA_BASE AS (
    SELECT
        ZONA_KEY,
        FECHA,
        NOMBRE_DIA,
        LLUVIA_MM,
        VIAJES,
        AVG(IFF(LLUVIA_MM > 10, NULL, VIAJES))
            OVER (PARTITION BY ZONA_KEY, DIA_SEMANA) AS LINEA_BASE
    FROM SERIE_COMPLETA
)
SELECT
    FECHA,
    NOMBRE_DIA,
    LLUVIA_MM,
    SUM(VIAJES)                                                    AS VIAJES,
    ROUND(SUM(LINEA_BASE), 0)                                      AS LINEA_BASE,
    ROUND((SUM(VIAJES) - SUM(LINEA_BASE)) / SUM(LINEA_BASE) * 100, 1) AS DIFERENCIA_PCT
FROM CON_LINEA_BASE
WHERE LLUVIA_MM > 10
GROUP BY FECHA, NOMBRE_DIA, LLUVIA_MM
ORDER BY FECHA;

-- Detalle por zona (opcional): cambia el SELECT final por este para ver qué zonas pierden o
--   ganan más con la lluvia fuerte.
--   SELECT ZONA_KEY AS ZONA, FECHA, LLUVIA_MM, VIAJES, ROUND(LINEA_BASE, 0) AS LINEA_BASE
--   FROM CON_LINEA_BASE
--   WHERE LLUVIA_MM > 10 AND LINEA_BASE >= 100
--   ORDER BY FECHA, ZONA;

-- Resultado (12 días con más de 10 mm):
--   FECHA        DIA   LLUVIA_MM    VIAJES   LINEA_BASE   DIFERENCIA_PCT
--   2024-01-06   Sat        11.8   708 821      779 616             -9.1
--   2024-01-09   Tue        38.0   624 079      583 123              7.0
--   2024-01-10   Wed        21.7   567 042      625 427             -9.3
--   2024-01-13   Sat        19.7   752 459      779 616             -3.5
--   2024-01-28   Sun        21.3   702 625      661 325              6.2
--   2024-02-13   Tue        27.7   507 771      583 123            -12.9
--   2024-02-28   Wed        15.6   665 514      625 427              6.4
--   2024-03-02   Sat        28.1   869 673      779 616             11.6
--   2024-03-05   Tue        20.3   662 016      583 123             13.5
--   2024-03-06   Wed        34.0   719 187      625 427             15.0
--   2024-03-09   Sat        43.5   884 219      779 616             13.4
--   2024-03-23   Sat        63.6   874 938      779 616             12.2
-- Nota: LINEA_BASE es igual para todos los días del mismo día de la semana (por ejemplo
--   779 616 para los sábados), porque es el promedio de los días de ese tipo sin lluvia fuerte.
--
-- Interpretación: la lluvia fuerte no baja la demanda de forma pareja; 8 de los 12 días
--   tuvieron MÁS viajes que su línea base y 4 tuvieron menos. En promedio, un día de lluvia
--   fuerte queda un 4.2 % por encima de un día normal del mismo día de la semana, parecido al
--   +5.2 % de B1 (que no separaba por día de la semana).
--   1. La caída más grande es el martes 2024-02-13 (-12.9 %). Ese día fue nieve, no lluvia: el
--      dato de precipitación no distingue entre las dos, y es la misma nevada que explica el
--      rebote del 14 de febrero en B2. La nieve sí frena los viajes.
--   2. Los días de más lluvia suben: el 23 de marzo (63.6 mm, el más lluvioso) +12.2 % y el
--      9 de marzo (43.5 mm) +13.4 %. Con lluvia, más gente pide un carro en vez de caminar o
--      esperar el bus.
--   3. Hay un patrón por fecha más claro que por milímetros: los días negativos son de enero y
--      febrero, y los cinco de marzo son positivos (+11.6 % a +15.0 %). La línea base mezcla los
--      tres meses, y la demanda crece de enero a marzo (B3). Por eso un día de marzo se compara
--      con una base "baja" y uno de enero con una base "alta": parte de la diferencia es
--      tendencia y no lluvia.
--   Qué NO dice: no prueba que la lluvia cause el cambio; con 12 días y la tendencia mezclada
--   en la base, el efecto de la lluvia queda en "pequeño y positivo, salvo con nieve". Para
--   separar mejor, la línea base podría calcularse también por mes
--   (PARTITION BY ZONA_KEY, DIA_SEMANA, MES); no se hizo para seguir la definición del reto.
