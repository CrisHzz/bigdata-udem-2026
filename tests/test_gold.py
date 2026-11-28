from __future__ import annotations

from datetime import date

from pyspark.sql import functions as F

from pipeline import quality
from pipeline.gold import (
    COLUMNAS_PROPINA_POR_LLUVIA,
    COLUMNAS_TARIFA_POR_MILLA,
    LLAVES_DE_GOLD,
    TABLAS_GOLD,
    crishzz_propina_por_lluvia,
    tarifa_por_milla_por_barrio,
)
from pipeline.silver import clima_diario, enriquecer, limpiar_viajes

MESES = ["2024-01"]


# --- el ejemplo de la casa: tarifa por milla por barrio y franja del día -----------------------

ESQUEMA_ENRIQUECIDO = (
    "pickup_date date, pickup_datetime string, borough string, distancia_mi double, "
    "total_pagado double"
)


def _enriquecido(spark, filas):
    """La hora llega como texto y se convierte con Spark: así hora y franja usan la misma zona."""
    df = spark.createDataFrame(filas, ESQUEMA_ENRIQUECIDO)
    return df.withColumn("pickup_datetime", F.to_timestamp("pickup_datetime"))


def test_tabla_de_la_casa_esta_en_tablas_gold():
    # Ya no es la única: el equipo sumó la suya (ver las pruebas del final).
    assert "tarifa_por_milla_barrio" in TABLAS_GOLD
    assert TABLAS_GOLD["tarifa_por_milla_barrio"] is tarifa_por_milla_por_barrio


def test_tarifa_por_milla_valores_conocidos(spark):
    dia = date(2024, 1, 1)
    enriquecido = _enriquecido(
        spark,
        [
            (dia, "2024-01-01 08:00:00", "Manhattan", 2.0, 10.0),
            (dia, "2024-01-01 09:30:00", "Manhattan", 3.0, 20.0),
            (dia, "2024-01-01 08:05:00", "Queens", 10.0, 25.0),
        ],
    )

    gold = tarifa_por_milla_por_barrio(enriquecido)

    assert gold.columns == COLUMNAS_TARIFA_POR_MILLA
    filas = {(r["borough"], r["franja"]): r for r in gold.collect()}
    manhattan = filas[("Manhattan", "mañana")]
    assert manhattan["viajes"] == 2
    assert manhattan["distancia_total_mi"] == 5.0
    assert manhattan["ingreso_total"] == 30.0
    assert manhattan["tarifa_por_milla"] == 6.0  # 30 / 5
    assert filas[("Queens", "mañana")]["tarifa_por_milla"] == 2.5


def test_las_franjas_del_dia_cortan_a_las_6_12_y_18(spark):
    dia = date(2024, 1, 1)
    horas = {0: "madrugada", 5: "madrugada", 6: "mañana", 11: "mañana", 12: "tarde"}
    horas.update({17: "tarde", 18: "noche", 23: "noche"})
    enriquecido = _enriquecido(
        spark,
        [(dia, f"2024-01-01 {h:02d}:30:00", f"B{h}", 1.0, 5.0) for h in horas],
    )
    franjas = {
        r["borough"]: r["franja"] for r in tarifa_por_milla_por_barrio(enriquecido).collect()
    }
    assert franjas == {f"B{h}": franja for h, franja in horas.items()}


def test_un_viaje_sin_barrio_cuenta_como_desconocido(spark):
    enriquecido = _enriquecido(spark, [(date(2024, 1, 1), "2024-01-01 08:00:00", None, 1.0, 5.0)])
    gold = tarifa_por_milla_por_barrio(enriquecido)
    assert gold.first()["borough"] == "Desconocido"


def test_tarifa_por_milla_pasa_calidad_con_la_muestra(muestra_viajes, muestra_zonas, muestra_clima):
    enriquecido = enriquecer(
        limpiar_viajes(muestra_viajes, MESES), muestra_zonas, clima_diario(muestra_clima)
    )
    gold = tarifa_por_milla_por_barrio(enriquecido)
    llaves = ("fecha", "borough", "franja")

    assert gold.agg({"viajes": "sum"}).first()[0] == 90
    quality.validar(gold, nombre="gold", llaves=llaves, clave_unica=llaves)
    assert gold.where("tarifa_por_milla <= 0").count() == 0


# --- tabla del equipo CrisHzz: propina por nivel de lluvia -------------------------------------

ESQUEMA_PROPINA = (
    "pickup_date date, borough string, empresa string, lluvia_mm double, propina double"
)


def _niveles(spark, lluvias):
    """Un viaje por día, cada día con su lluvia; devuelve {lluvia: nivel_lluvia}."""
    filas = [(date(2024, 1, i + 1), "Manhattan", "Uber", mm, 1.0) for i, mm in enumerate(lluvias)]
    gold = crishzz_propina_por_lluvia(spark.createDataFrame(filas, ESQUEMA_PROPINA))
    por_dia = {r["fecha"].day: r["nivel_lluvia"] for r in gold.collect()}
    return {mm: por_dia[i + 1] for i, mm in enumerate(lluvias)}


def test_tabla_del_equipo_esta_en_tablas_gold_con_su_clave():
    assert TABLAS_GOLD["crishzz_propina_por_lluvia"] is crishzz_propina_por_lluvia
    assert LLAVES_DE_GOLD["crishzz_propina_por_lluvia"] == (
        "fecha",
        "borough",
        "empresa",
        "nivel_lluvia",
    )


def test_propina_por_lluvia_suma_viajes_y_propinas(spark):
    """Caso normal: dos viajes del mismo grupo se juntan; propina 0 no es «con propina»."""
    dia = date(2024, 1, 1)
    enriquecido = spark.createDataFrame(
        [
            (dia, "Manhattan", "Uber", 5.0, 2.0),
            (dia, "Manhattan", "Uber", 5.0, 0.0),
            (dia, "Queens", "Lyft", 5.0, 3.5),
        ],
        ESQUEMA_PROPINA,
    )

    gold = crishzz_propina_por_lluvia(enriquecido)

    assert gold.columns == COLUMNAS_PROPINA_POR_LLUVIA
    filas = {(r["borough"], r["empresa"]): r for r in gold.collect()}
    assert len(filas) == 2
    manhattan = filas[("Manhattan", "Uber")]
    assert manhattan["nivel_lluvia"] == "ligera"
    assert manhattan["viajes"] == 2
    assert manhattan["propina_total"] == 2.0
    assert manhattan["viajes_con_propina"] == 1
    assert filas[("Queens", "Lyft")]["propina_total"] == 3.5


def test_nivel_lluvia_seca_ligera_y_fuerte(spark):
    """Caso normal: 0 mm es seca, 5 mm ligera y 25 mm fuerte."""
    assert _niveles(spark, [0.0, 5.0, 25.0]) == {0.0: "seca", 5.0: "ligera", 25.0: "fuerte"}


def test_nivel_lluvia_en_el_umbral_de_10_mm(spark):
    """Caso límite: 10.0 mm exacto es ligera; apenas por encima ya es fuerte."""
    assert _niveles(spark, [10.0, 10.1]) == {10.0: "ligera", 10.1: "fuerte"}


def test_lluvia_nula_o_negativa_queda_sin_dato_y_no_se_pierde(spark):
    """Datos malos: sin clima (nulo) o un valor imposible (negativo) quedan como sin_dato."""
    enriquecido = spark.createDataFrame(
        [
            (date(2024, 1, 1), "Bronx", "Uber", None, 1.0),
            (date(2024, 1, 2), "Bronx", "Uber", -3.0, 1.0),
        ],
        ESQUEMA_PROPINA,
    )

    gold = crishzz_propina_por_lluvia(enriquecido)

    assert {r["nivel_lluvia"] for r in gold.collect()} == {"sin_dato"}
    assert gold.agg({"viajes": "sum"}).first()[0] == 2  # ninguna fila se descarta


def test_propina_por_lluvia_barrio_nulo_cuenta_como_desconocido(spark):
    enriquecido = spark.createDataFrame(
        [(date(2024, 1, 1), None, "Lyft", 0.0, 1.0)], ESQUEMA_PROPINA
    )
    assert crishzz_propina_por_lluvia(enriquecido).first()["borough"] == "Desconocido"


def test_propina_por_lluvia_pasa_calidad_con_la_muestra(
    muestra_viajes, muestra_zonas, muestra_clima
):
    enriquecido = enriquecer(
        limpiar_viajes(muestra_viajes, MESES), muestra_zonas, clima_diario(muestra_clima)
    )
    gold = crishzz_propina_por_lluvia(enriquecido)
    llaves = LLAVES_DE_GOLD["crishzz_propina_por_lluvia"]

    # Los mismos 90 viajes que la tabla de la casa: agrupar no pierde ni duplica viajes.
    assert gold.agg({"viajes": "sum"}).first()[0] == 90
    quality.validar(gold, nombre="gold", llaves=llaves, clave_unica=llaves)
    assert gold.where("viajes_con_propina > viajes").count() == 0
