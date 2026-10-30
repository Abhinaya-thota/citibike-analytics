"""Download Citi Bike monthly trip files and land them as conformed Parquet.

Each month becomes one file, data/raw/trips/trips_YYYY-MM.parquet, with every
column kept as VARCHAR. Typing and cleaning happen in dbt staging, so the raw
layer is a faithful, replayable copy of what Citi Bike published.
"""

import re
import shutil
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import duckdb

from . import config
from .http import download, session

# Monthly NYC files, e.g. "202602-citibike-tripdata.zip" or "...csv.zip".
# Jersey City files ("JC-...") and the yearly archives are deliberately skipped.
MONTHLY_KEY = re.compile(r"^(\d{4})(\d{2})-citibike-tripdata(?:\.csv)?\.zip$")


def list_available_months() -> dict[str, str]:
    """Return {"YYYY-MM": s3_key} for every monthly NYC file in the bucket."""
    resp = session().get(config.TRIPDATA_BUCKET_URL, params={"list-type": 2}, timeout=60)
    resp.raise_for_status()
    ns = {"s3": "http://s3.amazonaws.com/doc/2006-03-01/"}
    root = ET.fromstring(resp.content)
    if root.findtext("s3:IsTruncated", namespaces=ns) == "true":
        # 1000+ keys would need continuation tokens; the bucket has ~200 today.
        raise RuntimeError("S3 listing truncated; add pagination")

    months = {}
    for key in root.iterfind("s3:Contents/s3:Key", ns):
        m = MONTHLY_KEY.match(key.text)
        if m:
            months[f"{m.group(1)}-{m.group(2)}"] = key.text
    return dict(sorted(months.items()))


def trips_path(month: str) -> Path:
    return config.TRIPS_DIR / f"trips_{month}.parquet"


def _extract_csvs(zip_path: Path, dest: Path) -> list[Path]:
    """Extract every CSV in the archive, recursing into nested zips and skipping
    macOS resource forks that appear in some older archives."""
    csvs = []
    with zipfile.ZipFile(zip_path) as zf:
        for name in zf.namelist():
            if name.startswith("__MACOSX") or name.endswith("/"):
                continue
            if name.lower().endswith(".csv"):
                csvs.append(Path(zf.extract(name, dest)))
            elif name.lower().endswith(".zip"):
                inner = Path(zf.extract(name, dest))
                csvs += _extract_csvs(inner, inner.parent / inner.stem)
    return sorted(csvs)


def _conform_select(con: duckdb.DuckDBPyConnection, relation: str, month: str, source_file: str) -> str:
    """Build a SELECT mapping whatever columns this month has onto TRIP_COLUMNS."""
    present = {
        row[0]: config.LEGACY_COLUMN_MAP.get(row[0], row[0])
        for row in con.sql(f"describe {relation}").fetchall()
    }
    canonical_to_source = {v: k for k, v in present.items()}

    cols = []
    for col in config.TRIP_COLUMNS:
        src = canonical_to_source.get(col)
        cols.append(f'"{src}" as {col}' if src else f"null::varchar as {col}")
    ingested_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    cols += [
        f"'{source_file}' as _source_file",
        f"'{month}' as _source_month",
        f"timestamp '{ingested_at}' as _ingested_at",
    ]
    return "select " + ",\n       ".join(cols) + f"\nfrom {relation}"


def load_month(month: str, key: str, sample_rows: int | None = None, keep_zip: bool = False) -> Path:
    """Download one month and write data/raw/trips/trips_<month>.parquet."""
    out = trips_path(month)
    out.parent.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix=f"citibike_{month}_"))
    try:
        zip_path = download(f"{config.TRIPDATA_BUCKET_URL}/{key}", work / key)
        csvs = _extract_csvs(zip_path, work / "csv")
        if not csvs:
            raise RuntimeError(f"{key} contained no CSV files")
        if not keep_zip:
            zip_path.unlink()

        con = duckdb.connect()
        files = ", ".join(f"'{p}'" for p in csvs)
        # all_varchar: never let type sniffing silently mangle IDs like "4404.10".
        con.sql(
            f"""
            create view src as
            select * from read_csv([{files}], header = true, all_varchar = true,
                                   union_by_name = true, normalize_names = true)
            """
        )
        relation = "src"
        if sample_rows:
            con.sql(f"create view sampled as select * from src using sample reservoir({sample_rows} rows) repeatable (42)")
            relation = "sampled"

        tmp_out = out.with_suffix(".parquet.part")
        con.sql(
            f"copy ({_conform_select(con, relation, month, key)}) "
            f"to '{tmp_out}' (format parquet, compression zstd)"
        )
        tmp_out.replace(out)
        rows = con.execute(f"select count(*) from '{out}'").fetchone()[0]
        print(f"  {month}: {rows:,} rows -> {out.relative_to(config.REPO_ROOT) if out.is_relative_to(config.REPO_ROOT) else out}")
        return out
    finally:
        shutil.rmtree(work, ignore_errors=True)
