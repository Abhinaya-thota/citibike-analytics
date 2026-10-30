"""Download NYC borough boundaries (static reference data, fetched once)."""

from pathlib import Path

from . import config
from .http import download

BOROUGHS_PATH = config.GEO_DIR / "nyc_boroughs.geojson"


def load(force: bool = False) -> Path:
    if BOROUGHS_PATH.exists() and not force:
        return BOROUGHS_PATH
    download(config.BOROUGHS_GEOJSON_URL, BOROUGHS_PATH)
    print(f"  boroughs -> {BOROUGHS_PATH.name}")
    return BOROUGHS_PATH
