# Contrato del Taller 2

Equipo: CrisHzz (un integrante)

Anfitrión (dueño del fork): Cristian Camilo Hernandez

## 1. Integrantes y roles

Trabajo solo, así que asumo los cuatro roles, como permite el enunciado (sección 4). La rotación
no aplica: en el Taller 1 también hice los cuatro roles.

**<ins>Vengo del pregrado , ademas estoy remoto y con las pocas clases que hubo, me fue muy difícil conseguir equipo. Aun así
lo tomo como un reto personal</ins>**

| Integrante | Rol en el Taller 1 | Rol en el Taller 2 |
|---|---|---|
| Cristian Camilo Hernandez | Los cuatro (trabajo individual) | Analista de negocio y cumplimiento |
| Cristian Camilo Hernandez | Los cuatro (trabajo individual) | Modelador SQL |
| Cristian Camilo Hernandez | Los cuatro (trabajo individual) | Ingeniero de datos |
| Cristian Camilo Hernandez | Los cuatro (trabajo individual) | Operador cloud y calidad |

## 2. Pregunta de negocio

> En enero de 2024, ¿la propina promedio por viaje de Uber y Lyft en NYC es mayor en los días de
> lluvia fuerte (más de 10 mm) que en los días secos?

**Para quién es la respuesta y qué decisión apoyaría:** para la autoridad de movilidad y las
plataformas. Si la lluvia fuerte sube la propina, los conductores ganan más en esos días y es más
fácil conseguir oferta de servicio cuando más se necesita; si no la sube, puede hacer falta otro
incentivo para tener conductores en la calle con mal clima.

## 3. Hipótesis

> Con lluvia fuerte la propina promedio por viaje sube frente a los días secos, porque el pasajero
> valora más el servicio cuando la alternativa (caminar, esperar el bus) es peor. En el Taller 1
> vi que la lluvia no baja los viajes (+5,2 % por día); falta saber si cambia lo que se paga.
> Puede resultar falsa: la propina podría no moverse, o bajar si los viajes con lluvia son más
> cortos.

## 4. Cambio elegido

| Campo | Respuesta |
|---|---|
| Capa | gold |
| Archivo y función donde va | `src/pipeline/gold.py`: una función nueva `crishzz_propina_por_lluvia` y un auxiliar `_nivel_lluvia`, siguiendo el patrón de `_franja_del_dia` |
| Qué se agrega o cambia | Columna `nivel_lluvia` y una tabla de gold propia: viajes, suma de propinas y viajes con propina por fecha, barrio y empresa |
| Definición exacta | `nivel_lluvia`: `seca` si `lluvia_mm` = 0; `ligera` si es mayor que 0 y hasta 10 mm (10,0 incluido); `fuerte` si es mayor que 10 mm. Si `lluvia_mm` es nulo o negativo: `sin_dato` (la fila no se descarta). Grano: una fila por `fecha`, `borough` y `empresa`; clave: `fecha`, `borough`, `empresa`, `nivel_lluvia` (`nivel_lluvia` depende solo de la fecha, así que no cambia el grano; ver sección 9). Barrio nulo: `Desconocido`, como en el gold de la casa |
| Por qué lo necesita la pregunta | El gold de la casa no guarda la propina ni la lluvia del día, y la tabla del Taller 1 solo traía la propina como promedio de grupo. Para comparar la propina por nivel de lluvia necesito la suma de propinas y el número de viajes, y así ponderar bien (trampa 2 del Taller 1) |

Además, como pide el entregable 1: escribir `agregar_metadatos` (`bronze.py`) y `deduplicar`
(`silver.py`) para que sus pruebas pasen de `PENDIENTE` a `OK`. No los cuento como el cambio de
la pregunta.

## 5. Cómo se probará

- **Pruebas con pytest:**
  - Caso normal: una fila con 5 mm queda `ligera`; una con 0 mm, `seca`.
  - Caso límite: 10,0 mm queda `ligera` y 10,1 mm queda `fuerte`.
  - Caso con datos malos: `lluvia_mm` nulo queda `sin_dato` y la fila no se pierde; un valor negativo también queda `sin_dato`.
  - La tabla de gold: con tres viajes escritos a mano (dos del mismo grupo), salen dos filas, con `viajes` y `propina_total` bien sumados.
- **Archivo de pruebas:** `tests/test_gold.py`
- **CI:** el PR debe tener los cinco checks en verde antes del merge. Revisor: pendiente de acordar con el instructor, porque trabajo solo y nadie puede aprobar su propio PR.
- **Corrida en Glue:** `computo = glue_small`, `mes = 2024-01`. Primero con `limite = 1000` para probar y después con `limite = todos` para la respuesta.

## 6. Qué cifra responderá la pregunta

- **Tabla de donde sale:** `BIGDATA.DEV.CRISHZZ_PROPINA_POR_LLUVIA`.
- **La cifra o comparación:** la propina promedio por viaje, ponderada (`SUM(propina_total) / SUM(viajes)`), por `nivel_lluvia`, y la diferencia en % entre `fuerte` y `seca`. También el % de viajes con propina. Los días se cuentan con `COUNT(DISTINCT fecha)`, no con filas.
- **Cómo se leerá el resultado:** si la propina por viaje en días `fuerte` es mayor que en días `seca`, la hipótesis se sostiene. Si es igual o menor, se contradice. Siempre se reporta cuántos días hay en cada nivel (en enero son pocos los días de lluvia fuerte).
- **Conciliación prevista:**
  - Bronze a silver: filas de bronze menos los descartes de silver, contados por filtro (distancia, tarifa, duración, fecha fuera del mes), igual a las filas de silver.
  - Silver a gold: filas de viajes en silver igual a `SUM(viajes)` de la tabla de gold.
  - Gold a Snowflake: filas y viajes de la tabla en Snowflake igual a lo que gold escribió, según `BIGDATA.CONTROL_DEV.WATERMARK` (último registro por tabla, capa y mes).

## 7. Riesgos

| Riesgo | Cómo lo manejaré |
|---|---|
| La lluvia se repite en todas las filas del día | Comparar por días con `COUNT(DISTINCT fecha)` y no sumar `lluvia_mm` |
| Promediar promedios de grupos | Guardar la suma de propinas y los viajes; ponderar con `SUM / SUM` |
| Pocos días de lluvia fuerte en un solo mes | Reportar el n de días por nivel y no generalizar más allá de enero de 2024 |
| Reprocesar sin `deduplicar` duplica los viajes | Escribir `deduplicar` antes de correr el mes completo |
| Trabajo solo: no hay otro integrante que revise el PR | Preguntar al instructor antes del 24 de noviembre cómo se maneja la revisión |
| Presupuesto de AWS (50 USD; Glue se bloquea al 60 %) | Un solo mes, probar con `limite = 1000` y apagar todo al terminar cada sesión (`make airflow-off` después de cada merge) |
| La prueba de Snowflake vence el 3 de diciembre | Terminar y entregar antes del 29 de noviembre |

## 8. Acuerdos de trabajo

- **Reunión del equipo:** no aplica; trabajo solo, en sesiones propias.
- **Quién revisa los PR:** pendiente de acordar con el instructor (trabajo individual).
- **Cuándo se hace merge:** solo con el CI en verde.
- **Hitos propios:** 23 de nov.: `pipeline_taxi` corre con `glue_small` desde mi fork y `agregar_metadatos` y `deduplicar` en `OK`; 24 de nov.: mostrar la tabla de gold propia probada en el notebook y con sus pruebas; 29 de nov.: entrega.
- **Quién apaga las cuentas al terminar cada sesión:** yo.
- **Si alguien no responde en 24 horas:** no aplica.

## 9. Cambios al contrato

| Fecha | Qué cambió | Por qué |
|---|---|---|
| 27 nov. 2026 | Se agregó `nivel_lluvia` a la clave de la tabla de gold: pasa de `fecha, borough, empresa` a `fecha, borough, empresa, nivel_lluvia` (`LLAVES_DE_GOLD` en `gold.py`) | `nivel_lluvia` tiene que ir en el `groupBy` para salir como columna, así que la clave queda igual a las columnas por las que se agrupa. Como depende solo de la fecha, no cambia el grano ni el número de filas: es una aclaración, no un cambio de lo que mide la tabla |
| 27 nov. 2026 | Se fijaron las columnas de la tabla de gold: `fecha`, `borough`, `empresa`, `nivel_lluvia`, `viajes`, `propina_total` y `viajes_con_propina`. No guarda promedios ni `lluvia_mm` | Las sumas permiten ponderar en Snowflake con `SUM / SUM` (trampa 2 del Taller 1). Guardar `lluvia_mm` la repetiría en cada fila de barrio y empresa (trampa 1); los días por nivel salen con `COUNT(DISTINCT fecha)` |
| 27 nov. 2026 | Se ajustaron pruebas de la casa que asumían una sola tabla de gold: dos que exigían que la de la casa fuera la única (`test_gold.py` y `test_carga.py`), y ocho que contaban un resultado por paso (`test_carga.py` y `test_pasos.py`). Estas ocho ahora corren solo con la tabla de la casa, con el fixture `solo_la_tabla_de_la_casa` | Al sumar la tabla propia esas pruebas fallaban y el CI saldría en rojo, aunque el pipeline funcionaba. Miden la mecánica del pipeline con una tabla y siguen midiendo lo mismo. La tabla del equipo tiene sus propias pruebas, y una nueva en `test_pasos.py` corre el pipeline con las dos tablas y comprueba que la del equipo suma los mismos viajes válidos de silver |
