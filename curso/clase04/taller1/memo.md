# Memo · ¿La lluvia cambia los viajes en NYC? (Taller 1)

Equipo: Cristian Camilo Hernandez · Anfitrión: Cristian Camilo Hernandez · Caso: B · Fecha: 15 de noviembre del 2026

## Pregunta y decisión

¿Cuándo sube o baja la demanda de Uber y Lyft en la ciudad de Nueva York?

Con esta información es posible gestionar y planear los servicios de transporte: aumentar la capacidad de taxis, habilitar más zonas de recogida, subir la frecuencia de trenes y preparar la red para los días de nieve, cuando la demanda cae y luego rebota.

## Hallazgos

1. **La nieve sí frena la demanda.** El 13 de febrero, día de nieve, tuvo un 12,9 % menos viajes que un martes normal, y al día siguiente rebotó en 143 zonas a la vez. El dato de precipitación no separa lluvia de nieve: es la nieve, no la lluvia, la que baja los viajes.

2. **El fin de semana toma la delantera.** Un día de fin de semana tiene un 14,3 % más viajes que uno entre semana (729.445 frente a 637.954). Los sábados se llenan las zonas de vida nocturna (East Village, 210.123 viajes) y los domingos los aeropuertos.

3. **Los festivos no son determinísticos.** Días festivos como el de Martin Luther King y Washington's Birthday quedaron a menos del 3 % de un lunes normal. La excepción es Año Nuevo, con un 12,4 % más, porque incluye la madrugada de la fiesta de fin de año.

## Supuestos y definiciones

Tomé estas decisiones yo, ya que hice el trabajo en solitario.

- **Día con lluvia:** cualquier día con más de 0 mm de precipitación. **Lluvia fuerte:** más de 10 mm.
- **Nombre de zona repetido:** dejé una sola fila por nombre de zona (262), uniendo por nombre, para evitar inflar los viajes.
- **Base de comparación:** cada día lo comparo contra el promedio de su mismo día de la semana, porque la demanda cambia mucho entre semana y fin de semana.
- **Festivos:** tomé solo los 3 festivos federales de enero a marzo (1 y 15 de enero, 19 de febrero), los tres lunes, comparados contra los 10 lunes normales.

## Trampa evitada

**Trampa 1: la lluvia que se repite.** La lluvia del día viene repetida en cada fila del gold (unas 514 por día). Si se llega a sumar, ocurre un error: por ejemplo, el 10 de enero daría 11.153 mm en vez de los 21,7 mm reales. La evité guardando la lluvia una sola vez por día en `DIM_FECHA` (`MAX(LLUVIA_MM)` por fecha) y contando días con `COUNT(DISTINCT FECHA)`, no filas.

## Límites

El conjunto de datos solo abarca 3 meses, así que no sirve para un ejercicio de proyección como una regresión ni para encontrar tendencias a largo plazo: es una serie temporal, pero muy corta. Otras variables (frío, eventos, precios) no se tuvieron en cuenta, por lo que las relaciones son señales, no causas probadas. Los festivos son solo 3 casos y los tres lunes, muy poco para generalizar. Aparte, el dato de precipitación mezcla lluvia y nieve.

## Nota personal

Realicé el trabajo solo: vengo del pregrado y no conozco mucha gente, y al asistir de forma remota fue difícil conseguir equipo. Aun así me gustó mucho, porque me ayudó a aprender más de la ingeniería de datos. Es algo que quiero, para hacer poco a poco el cambio de científico de datos a ese rol.
