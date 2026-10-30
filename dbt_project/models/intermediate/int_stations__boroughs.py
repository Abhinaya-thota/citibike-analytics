"""Assign each station to a borough with a point-in-polygon lookup.

A Python model because DuckDB's spatial extension isn't always installable
(e.g. offline CI). Stations on piers and waterfront esplanades can sit just
outside shoreline-clipped polygons, so anything within 300 m of a borough is
snapped to it; Jersey City / Hoboken stations end up as 'New Jersey'.
"""

import json
from pathlib import Path

import pandas as pd
import shapely
from shapely.geometry import shape

SNAP_DEGREES = 0.003  # ~300 m at NYC's latitude


def model(dbt, session):
    dbt.config(materialized="table")

    stations = dbt.ref("int_stations__locations").df()
    geojson_path = Path(dbt.config.get("raw_dir", "../data/raw")) / "geo" / "nyc_boroughs.geojson"
    features = json.loads(geojson_path.read_text())["features"]

    names = [f["properties"]["BoroName"] for f in features]
    polygons = [shape(f["geometry"]) for f in features]
    points = shapely.points(stations["longitude"].to_numpy(), stations["latitude"].to_numpy())

    borough = pd.Series([None] * len(stations), dtype="object")
    snapped = pd.Series(False, index=stations.index)
    for name, poly in zip(names, polygons):
        inside = shapely.contains_xy(poly, stations["longitude"], stations["latitude"])
        borough[inside & borough.isna()] = name
    for name, poly in zip(names, polygons):
        near = (shapely.distance(poly, points) <= SNAP_DEGREES) & borough.isna().to_numpy()
        borough[near] = name
        snapped[near] = True

    # West of the Hudson and not in a borough polygon -> the NJ part of the system.
    nj = borough.isna() & (stations["longitude"] < -74.02)
    borough[nj] = "New Jersey"
    borough = borough.fillna("Unknown")

    return pd.DataFrame(
        {"station_id": stations["station_id"], "borough": borough, "borough_snapped": snapped}
    )
