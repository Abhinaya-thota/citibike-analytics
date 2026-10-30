"""Shared paths and source URLs for ingestion."""

import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = Path(os.environ.get("CITIBIKE_RAW_DIR", REPO_ROOT / "data" / "raw"))

TRIPS_DIR = RAW_DIR / "trips"
WEATHER_DIR = RAW_DIR / "weather"
GEO_DIR = RAW_DIR / "geo"

# Citi Bike system data: https://citibikenyc.com/system-data
TRIPDATA_BUCKET_URL = "https://s3.amazonaws.com/tripdata"

# NOAA NCEI Access Data Service, GHCN-Daily summaries.
# USW00094728 = NY City Central Park, the standard station for "NYC weather".
NOAA_DATA_URL = "https://www.ncei.noaa.gov/access/services/data/v1"
NOAA_STATION = os.environ.get("NOAA_STATION", "USW00094728")
NOAA_DATATYPES = ["PRCP", "SNOW", "SNWD", "TMAX", "TMIN", "AWND"]

# NYC borough boundaries (NYC Dept. of City Planning, clipped to shoreline), WGS84.
BOROUGHS_GEOJSON_URL = (
    "https://raw.githubusercontent.com/dwillis/nyc-maps/master/boroughs.geojson"
)

# The canonical raw trip schema. Every monthly file is conformed to exactly these
# columns (all VARCHAR) so the raw layer can be read with a single glob.
TRIP_COLUMNS = [
    "ride_id",
    "rideable_type",
    "started_at",
    "ended_at",
    "start_station_name",
    "start_station_id",
    "end_station_name",
    "end_station_id",
    "start_lat",
    "start_lng",
    "end_lat",
    "end_lng",
    "member_casual",
]

# Pre-2021 files use a different header ("starttime", "start station id", ...).
# After DuckDB's normalize_names these become the keys below.
LEGACY_COLUMN_MAP = {
    "starttime": "started_at",
    "stoptime": "ended_at",
    "start_station_latitude": "start_lat",
    "start_station_longitude": "start_lng",
    "end_station_latitude": "end_lat",
    "end_station_longitude": "end_lng",
    "usertype": "member_casual",
}
