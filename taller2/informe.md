# Informe · Taller 2

Equipo: CrisHzz · Anfitrión: Cristian Camilo Hernandez · Fecha: 28 de noviembre de 2026

## La pregunta y la respuesta

**¿En enero de 2024, la propina por viaje de Uber y Lyft en NYC es mayor en los días de lluvia fuerte (más de 10 mm) que en los días secos?**

A primera vista, no. Con lluvia fuerte la propina por viaje fue de 1,005 USD y en días secos de 1,033 USD: un 2,7 % menos. Mi hipótesis decía lo contrario.

Pero al separar entre semana y fin de semana, el resultado cambia:

| | Lluvia fuerte | Día seco | Diferencia |
|---|---|---|---|
| Entre semana | 1,075 USD (2 días) | 1,071 USD (10 días) | +0,4 % |
| Fin de semana | 0,967 USD (3 días) | 0,936 USD (3 días) | +3,3 % |

El fin de semana se deja menos propina, llueva o no. De los 5 días de lluvia fuerte, 3 fueron fin de semana, mientras que 10 de los 13 días secos fueron entre semana. Al mezclarlo todo, la lluvia fuerte parece bajar la propina, pero lo que baja el promedio es que llovió sobre todo en fin de semana. Esto se llama paradoja de Simpson.

**Mi conclusión:** la lluvia fuerte no baja la propina. Si tiene algún efecto, es pequeño y hacia arriba. Con solo 5 días de lluvia fuerte en un mes no lo puedo afirmar: mi hipótesis ni se confirma ni se descarta.

Otros dos datos de la misma tabla: con lluvia fuerte hay más viajes por día (unos 671 000 frente a 620 000 en días secos, un 8,3 % más), y la lluvia ligera es la que más sube la propina (+6,8 % frente a los días secos).

Para la autoridad de movilidad: no conviene contar con que la propina compense a los conductores en los días de lluvia fuerte. Si se quiere más oferta esos días, hace falta otro incentivo.

## Conciliación

Las cifras cuadran en las cuatro capas (consultas en `conciliacion.sql`):

| Cruce | Origen | Destino | ¿Cuadra? |
|---|---|---|---|
| Bronze a silver | 19 663 930 filas - 13 907 descartes | 19 650 023 en silver | Sí |
| Silver a gold | 19 650 023 viajes | 19 650 023 en cada tabla de gold | Sí |
| Gold a Snowflake | 373 y 744 filas | 373 y 744 en Snowflake | Sí |

Los 13 907 descartes se explican uno por uno con los filtros de silver. Además, 19 650 023 es el mismo total de viajes de enero del Taller 1.

## Costo

Todo con `glue_small` (2 workers G.1X), `limite = todos`, un mes (`2024-01`):

| Paso | Ejecución | DPU-horas | Costo |
|---|---|---|---|
| bronze | 3 min 44 s | 0,1247 | 0,055 USD |
| silver | 4 min 13 s | 0,1406 | 0,062 USD |
| gold | 1 min 53 s | 0,0628 | 0,028 USD |
| **Total** | **9 min 50 s** | **0,3281** | **0,14 USD** |

El costo sale de 0,44 USD por DPU-hora ([precios de AWS Glue](https://aws.amazon.com/glue/pricing/)). La corrida completa, de bronze a la carga en Snowflake, duró 11 minutos.

- **Snowflake:** 0,7916 créditos en `BIGDATA_WH` desde el 27 de noviembre, con las cargas y todas mis consultas.
- **Athena:** 185,81 MB analizados en la consulta de descartes, una fracción de centavo.

**Configuración:** no corrí `glue_medium`, así que no comparé configuraciones con datos míos. Para correrlo cada mes elegiría `glue_small`: procesa el mes en 11 minutos por unos 14 centavos, y el paso más caro (silver) tarda 4 minutos. Con 4 workers no esperaría que el tiempo bajara a la mitad, porque cada job tiene un arranque fijo y gold ya es corto.

## Calidad

Reglas que aplicó el pipeline:

1. **Filtros de silver:** distancia mayor que 0 y menor que 100 millas, tarifa mayor que 0, duración entre 1 y 180 minutos, fecha y zona de recogida no nulas, y recogida dentro del mes.
2. **Deduplicación por `_hash_fila`** (`deduplicar`, la escribí yo).
3. **Validación de calidad** en silver y gold: llaves no nulas, rangos y clave única en cada tabla.
4. **Regla propia:** si un día no tiene lluvia registrada o el valor es negativo, queda como `sin_dato` y no se descarta.

Lo que detectaron:

| Regla | Filas | Decisión |
|---|---|---|
| Tarifa 0 o negativa | 7 331 | Descartar: no es un viaje cobrado |
| Distancia 0 o nula | 3 286 | Descartar |
| Distancia de 100 millas o más | 1 660 | Descartar: casi seguro un error de registro |
| Duración fuera de 1 a 180 minutos | 1 630 | Descartar |
| Sin fecha, sin zona o fuera de enero | 0 | El dato venía bien |
| Duplicados | 0 | El mes entró en un solo lote |
| Días `sin_dato` | 0 | Los 31 días tienen clima |

Los descartes son el 0,07 % de los viajes, demasiado poco para mover la respuesta.

Los duplicados sí los vi durante las pruebas: cuando reprocesé un mes, silver falló porque mezclaba un lote viejo sin `_hash_fila` con uno nuevo. Por eso reseteé dev antes de la corrida final.

## Límites

- Un solo mes y solo 5 días de lluvia fuerte.
- El dato de precipitación mezcla lluvia y nieve.
- No controlé otras variables, como la temperatura, los eventos o el precio del viaje.
- El PR no tiene revisión de otro integrante porque trabajé solo (contrato, sección 1).

## Nota personal

**<ins>Vengo del pregrado</ins>** y, al asistir de forma remota y con pocas clases, no logré armar equipo. Hice los cuatro roles. Lo tomé como un reto personal, y me sirvió para entender el pipeline de punta a punta.
