# Diagrama de la estrella · Taller 1

Equipo: Cristian Camilo Hernandez

Grano (el mismo de la primera línea de `01_estrella.sql`): una fila por FECHA, ZONA y EMPRESA (un día de una zona para una empresa). 46 715 filas, igual que el gold `DAILY_ZONE_METRICS`.

La tabla de hechos `FACT_VIAJES_DIA` va al centro y las tres dimensiones la rodean. Cada línea une la clave de la dimensión con la columna del mismo nombre en el hecho: una fila de la dimensión aparece en muchas filas del hecho.

```mermaid
erDiagram
    DIM_FECHA       ||--o{ FACT_VIAJES_DIA : "FECHA"
    DIM_ZONA        ||--o{ FACT_VIAJES_DIA : "ZONA_KEY"
    FACT_VIAJES_DIA }o--|| DIM_EMPRESA     : "EMPRESA_KEY"

    FACT_VIAJES_DIA {
        date    FECHA          PK, FK "-> DIM_FECHA"
        varchar ZONA_KEY       PK, FK "-> DIM_ZONA"
        varchar EMPRESA_KEY    PK, FK "-> DIM_EMPRESA"
        number  VIAJES                "aditiva"
        float   INGRESO_TOTAL         "aditiva"
        float   SUMA_PROPINA          "PROPINA_PROMEDIO x VIAJES"
        float   SUMA_DISTANCIA        "DISTANCIA_PROMEDIO x VIAJES"
    }
    DIM_FECHA {
        date    FECHA          PK "un dia por fila (91)"
        number  ANIO
        number  MES
        number  DIA_SEMANA        "1=lunes ... 7=domingo"
        varchar NOMBRE_DIA
        boolean FIN_DE_SEMANA
        boolean ES_FESTIVO        "cruce con FESTIVOS_2024"
        varchar NOMBRE_FESTIVO
        float   LLUVIA_MM         "lluvia del dia, una sola vez"
    }
    DIM_ZONA {
        varchar ZONA_KEY       PK "nombre de zona (262)"
        varchar ZONA
        varchar BOROUGH           "distrito"
        varchar SERVICE_ZONE      "tipo de zona"
    }
    DIM_EMPRESA {
        varchar EMPRESA_KEY    PK "SELECT DISTINCT (2)"
        varchar EMPRESA
    }
```

## Claves

| Dimensión | Clave | Por qué es única |
|---|---|---|
| DIM_FECHA | `FECHA` (une con `FACT_VIAJES_DIA.FECHA`) | Se genera un día por fila entre el primer y el último día del gold: 91 días, ninguno repetido. |
| DIM_ZONA | `ZONA_KEY` = nombre de la zona (une con `FACT_VIAJES_DIA.ZONA_KEY`) | El gold identifica la zona por nombre. La DIM_ZONA del Lab 4 repite 2 nombres (Corona; Governor's Island/Ellis Island/Liberty Island), pero cada grupo comparte distrito y tipo de zona, así que `SELECT DISTINCT ZONA, BOROUGH, SERVICE_ZONE` deja una fila por nombre (262). Así la unión no duplica viajes (trampa 4). |
| DIM_EMPRESA | `EMPRESA_KEY` = nombre de la empresa (une con `FACT_VIAJES_DIA.EMPRESA_KEY`) | Se construye con `SELECT DISTINCT EMPRESA` sobre el gold: una fila por empresa (Uber, Lyft), sin escribirlas a mano. |

La lluvia vive solo en `DIM_FECHA` (trampa 1). El hecho guarda medidas aditivas; los promedios ponderados se rehacen con `SUM(SUMA_PROPINA) / SUM(VIAJES)` y `SUM(SUMA_DISTANCIA) / SUM(VIAJES)` (trampa 2).
