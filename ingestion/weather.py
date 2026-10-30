"""Fetch NOAA GHCN-Daily weather for Central Park and land it as Parquet.

The NCEI Access Data Service needs no API token. Weather is small (one row per
day), so each run rewrites the full date range rather than appending.
"""

import io
from datetime import date, datetime, timezone
from pathlib import Path

import duckdb
import pandas as pd

from . import config
from .http import session

WEATHER_PATH = config.WEATHER_DIR / "weather_daily.parquet"


def fetch_daily(start: date, end: date) -> pd.DataFrame:
    resp = session().get(
        config.NOAA_DATA_URL,
        params={
            "dataset": "daily-summaries",
            "stations": config.NOAA_STATION,
            "startDate": start.isoformat(),
            "endDate": end.isoformat(),
            "dataTypes": ",".join(config.NOAA_DATATYPES),
            "units": "standard",  # inches, °F, mph
            "format": "csv",
            "includeStationName": "true",
        },
        timeout=120,
    )
    resp.raise_for_status()
    return parse_ncei_csv(resp.text)


def parse_ncei_csv(text: str) -> pd.DataFrame:
    """Normalise an NCEI CSV response to the raw weather schema (all strings).

    NCEI omits a column entirely when no day in the range has that element, so
    missing columns are added as nulls to keep the schema stable."""
    df = pd.read_csv(io.StringIO(text), dtype=str)
    df.columns = [c.strip().lower() for c in df.columns]
    if "date" not in df.columns:
        raise ValueError(f"Unexpected NCEI response: {text[:200]!r}")
    for col in ["station", "name"] + [d.lower() for d in config.NOAA_DATATYPES]:
        if col not in df.columns:
            df[col] = None
    df = df[["station", "name", "date"] + [d.lower() for d in config.NOAA_DATATYPES]]
    df["_ingested_at"] = datetime.now(timezone.utc).replace(tzinfo=None)
    return df


def write_parquet(df: pd.DataFrame, path: Path) -> None:
    """Write via DuckDB with explicit types, so all-null columns stay VARCHAR."""
    path.parent.mkdir(parents=True, exist_ok=True)
    cols = ", ".join(f'"{c}"::varchar as "{c}"' for c in df.columns if c != "_ingested_at")
    con = duckdb.connect()
    con.register("weather_df", df)
    con.execute(
        f"copy (select {cols}, _ingested_at::timestamp as _ingested_at from weather_df) "
        f"to '{path}' (format parquet)"
    )


def load(start: date, end: date) -> Path:
    df = fetch_daily(start, end)
    if df.empty:
        raise RuntimeError(f"NOAA returned no rows for {start}..{end}")
    write_parquet(df, WEATHER_PATH)
    print(f"  weather: {len(df):,} days ({df['date'].min()}..{df['date'].max()}) -> {WEATHER_PATH.name}")
    return WEATHER_PATH
