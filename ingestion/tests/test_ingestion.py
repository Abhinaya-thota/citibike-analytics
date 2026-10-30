"""Offline unit tests for the ingestion layer (no network)."""

import tempfile
import unittest
from datetime import date
from pathlib import Path

import duckdb

from ingestion import citibike, weather
from ingestion.run import month_bounds

NCEI_SAMPLE = """\
"STATION","NAME","DATE","AWND","PRCP","SNOW","SNWD","TMAX","TMIN"
"USW00094728","NY CITY CENTRAL PARK, NY US","2026-02-01","5.4","0.00","0.0","2.0","31","19"
"USW00094728","NY CITY CENTRAL PARK, NY US","2026-02-02","8.1","0.62","4.1","5.9","33","27"
"""


class MonthlyKeyTest(unittest.TestCase):
    def test_matches_monthly_files_only(self):
        ok = ["202602-citibike-tripdata.zip", "202306-citibike-tripdata.csv.zip"]
        skip = ["JC-202602-citibike-tripdata.csv.zip", "2023-citibike-tripdata.zip", "index.html"]
        for key in ok:
            self.assertIsNotNone(citibike.MONTHLY_KEY.match(key), key)
        for key in skip:
            self.assertIsNone(citibike.MONTHLY_KEY.match(key), key)


class ConformTest(unittest.TestCase):
    def _conform(self, header: str, row: str) -> dict:
        with tempfile.TemporaryDirectory() as tmp:
            csv = Path(tmp) / "t.csv"
            csv.write_text(header + "\n" + row + "\n")
            con = duckdb.connect()
            con.execute(
                f"create view src as select * from read_csv('{csv}', header=true, "
                "all_varchar=true, normalize_names=true)"
            )
            rel = con.sql(citibike._conform_select(con, "src", "2019-06", "x.zip"))
            return dict(zip(rel.columns, rel.fetchall()[0]))

    def test_modern_schema_passes_through(self):
        row = self._conform(
            "ride_id,rideable_type,started_at,ended_at,start_station_name,start_station_id,"
            "end_station_name,end_station_id,start_lat,start_lng,end_lat,end_lng,member_casual",
            "ABC,classic_bike,2026-02-01 08:00:00,2026-02-01 08:10:00,A,4404.10,B,4488.10,"
            "40.68,-73.98,40.69,-73.99,member",
        )
        self.assertEqual(row["start_station_id"], "4404.10")  # kept as text, not 4404.1
        self.assertEqual(row["member_casual"], "member")
        self.assertEqual(row["_source_month"], "2019-06")

    def test_legacy_schema_is_renamed(self):
        row = self._conform(
            '"tripduration","starttime","stoptime","start station id","start station name",'
            '"start station latitude","start station longitude","end station id","end station name",'
            '"end station latitude","end station longitude","bikeid","usertype","birth year","gender"',
            '600,"2019-06-01 08:00:00","2019-06-01 08:10:00",72,"A",40.76,-73.99,79,"B",40.71,-74.00,1,"Subscriber",1980,1',
        )
        self.assertEqual(row["started_at"], "2019-06-01 08:00:00")
        self.assertEqual(row["start_station_id"], "72")
        self.assertEqual(row["start_lat"], "40.76")
        self.assertEqual(row["member_casual"], "Subscriber")  # mapped to 'member' in dbt staging
        self.assertIsNone(row["ride_id"])                     # surrogate key built in dbt staging
        self.assertEqual(set(row) - {"_source_file", "_source_month", "_ingested_at"},
                         set(citibike.config.TRIP_COLUMNS))


class WeatherTest(unittest.TestCase):
    def test_parse_and_roundtrip(self):
        df = weather.parse_ncei_csv(NCEI_SAMPLE)
        self.assertEqual(list(df["prcp"]), ["0.00", "0.62"])
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "w.parquet"
            weather.write_parquet(df, path)
            types = dict(duckdb.sql(f"select column_name, column_type from (describe select * from '{path}')").fetchall())
        self.assertEqual(types["prcp"], "VARCHAR")
        self.assertEqual(types["_ingested_at"], "TIMESTAMP")

    def test_missing_elements_become_null_columns(self):
        df = weather.parse_ncei_csv('"STATION","DATE","PRCP"\n"X","2026-02-01","0.1"\n')
        self.assertIn("awnd", df.columns)
        self.assertTrue(df["awnd"].isna().all())


class MonthBoundsTest(unittest.TestCase):
    def test_bounds_cover_whole_months(self):
        self.assertEqual(month_bounds(["2026-02", "2025-10"]), (date(2025, 10, 1), date(2026, 2, 28)))


if __name__ == "__main__":
    unittest.main()
