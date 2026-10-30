"""Ingestion entrypoint.

    python -m ingestion.run                  # latest 12 months + weather + boroughs
    python -m ingestion.run --latest 6
    python -m ingestion.run --months 2026-01 2026-02
    python -m ingestion.run --latest 1 --sample-rows 200000   # fast CI run

Months already on disk are skipped unless --force, so the monthly scheduled
run only downloads what is new.
"""

import argparse
import calendar
import json
import sys
from datetime import date
from pathlib import Path

from . import citibike, config, geo, weather


def month_bounds(months: list[str]) -> tuple[date, date]:
    first_y, first_m = map(int, min(months).split("-"))
    last_y, last_m = map(int, max(months).split("-"))
    return date(first_y, first_m, 1), date(last_y, last_m, calendar.monthrange(last_y, last_m)[1])


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    which = p.add_mutually_exclusive_group()
    which.add_argument("--latest", type=int, default=12, help="load the N most recent months (default 12)")
    which.add_argument("--months", nargs="+", metavar="YYYY-MM", help="load specific months")
    p.add_argument("--sample-rows", type=int, help="keep a reproducible random sample of N rows per month")
    p.add_argument("--force", action="store_true", help="re-download months that already exist")
    p.add_argument("--skip-weather", action="store_true")
    p.add_argument(
        "--weather-optional",
        action="store_true",
        help="if NOAA is unreachable, warn and (only if no weather file exists yet) write an "
        "empty, correctly typed one so dbt can still build; weather-based outputs will be empty",
    )
    p.add_argument("--prune", action="store_true", help="delete local trip files outside the target months")
    p.add_argument("--manifest", type=Path, help="write a JSON list of files created this run")
    args = p.parse_args(argv)

    available = citibike.list_available_months()
    if args.months:
        missing = [m for m in args.months if m not in available]
        if missing:
            p.error(f"not published: {', '.join(missing)} (latest is {max(available)})")
        targets = sorted(args.months)
    else:
        targets = list(available)[-args.latest:]

    print(f"Trips: {targets[0]}..{targets[-1]} ({len(targets)} months)")
    written = []
    for month in targets:
        if citibike.trips_path(month).exists() and not args.force:
            print(f"  {month}: already loaded, skipping")
            continue
        written.append(citibike.load_month(month, available[month], sample_rows=args.sample_rows))

    if args.prune:
        for path in sorted(config.TRIPS_DIR.glob("trips_*.parquet")):
            if path.stem.removeprefix("trips_") not in targets:
                path.unlink()
                print(f"  pruned {path.name}")

    geo.load()

    # Weather covers every month present on disk, not just this run's targets,
    # so the weather table never has a hole under older trip data.
    if not args.skip_weather:
        on_disk = sorted(p.stem.removeprefix("trips_") for p in config.TRIPS_DIR.glob("trips_*.parquet"))
        try:
            written.append(weather.load(*month_bounds(on_disk)))
        except Exception as exc:  # network / NOAA outage
            if not args.weather_optional:
                raise
            print(f"  WARNING: weather download failed ({exc.__class__.__name__}: {exc})", file=sys.stderr)
            if not weather.WEATHER_PATH.exists():
                weather.write_parquet(weather.parse_ncei_csv("STATION,NAME,DATE\n"), weather.WEATHER_PATH)
                print("  WARNING: wrote an EMPTY weather file; weather analysis will have no rows", file=sys.stderr)

    if args.manifest:
        args.manifest.write_text(json.dumps([str(p) for p in written], indent=2))
    print(f"Done. {len(written)} file(s) written.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
