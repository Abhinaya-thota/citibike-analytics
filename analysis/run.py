"""Run a compiled showcase query against the warehouse and print the result.

    cd dbt_project && dbt compile --select "resource_type:analysis" && cd ..
    python analysis/run.py 02            # matches 02_empty_station_gaps_and_islands.sql
"""

import os
import sys
import time
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
COMPILED = ROOT / "dbt_project" / "target" / "compiled" / "analysis"
DB = os.environ.get("DUCKDB_PATH", ROOT / "data" / "warehouse" / "citibike.duckdb")

con = duckdb.connect(str(DB), read_only=True)
for prefix in sys.argv[1:] or ["0"]:
    for path in sorted(COMPILED.glob(f"{prefix}*.sql")):
        start = time.perf_counter()
        result = con.sql(path.read_text())
        print(f"\n=== {path.name} ===")
        result.show(max_rows=60, max_width=250)
        print(f"({time.perf_counter() - start:.2f}s)")
