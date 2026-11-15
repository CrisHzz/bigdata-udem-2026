# Retos opcionales · Taller 1

Equipo: Cristian Camilo Hernandez. Los retos suman hasta +15 puntos (los puntos de los seis suman 17; el máximo que se acredita es 15).
Marca los que hicieron y di dónde está cada uno.

| Id | Reto | Pts | ¿Hecho? | Dónde está (archivo y línea o sección) |
|---|---|---|---|---|
| R1 | Un segundo caso completo (cinco preguntas más) | 3 | no | — |
| R2 | `DIM_FECHA` con festivos y fin de semana, usada en una consulta | 2 | sí | `01_estrella.sql` (DDL de `DIM_FECHA`: `FIN_DE_SEMANA`, `ES_FESTIVO`, `NOMBRE_FESTIVO`), `02_carga.sql` (carga de `DIM_FECHA` con `FESTIVOS_2024`) y `03_preguntas.sql`, sección RETOS, «Reto R2» (viajes por día entre semana, fin de semana y festivo). También la usa la pregunta B5. |
| R3 | Lluvia fuerte (más de 10 mm) frente a la línea base del mismo día de la semana (`AVG() OVER (PARTITION BY ZONA, DIA_SEMANA)`) | 3 | sí | `03_preguntas.sql`, sección RETOS, «Reto R3». La línea base promedia solo días sin lluvia fuerte. |
| R4 | Suite de chequeos (grano, huérfanos, reconciliación con el conteo del paquete) en un solo archivo ejecutable | 3 | sí | `04_chequeos.sql` completo (Run All): parte 1, los cuatro controles del enunciado; parte 2, huérfanos de fecha y empresa, claves únicas, reconciliación de viajes e ingreso contra `CURSO.LAB4` y lluvia fuera del hecho; parte 3, filas y viajes por mes contra el paquete. |
| R5 | Rachas de alta demanda (días consecutivos sobre un umbral; el problema de «huecos e islas») | 3 | no | — |
| R6 | Tabla externa de Athena sobre el paquete (la del Lab 4, E7) y reconciliación de conteos con Snowflake: filas por mes y viajes totales, con captura de `Data scanned` | 3 | no | — |

Total de retos hechos: R2 + R3 + R4 = 8 puntos.

Para R6, si lo hacen: pega aquí la reconciliación (filas por mes y viajes totales en Athena y en Snowflake) y guarda la captura de `Data scanned` en esta carpeta.
