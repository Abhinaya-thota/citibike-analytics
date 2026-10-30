"""Train a LightGBM day-ahead hourly demand model on warehouse features.

    python forecasting/train.py                 # top 200 stations, test = last month
    python forecasting/train.py --top-n 500

Time-based split: everything before the last loaded month trains (with the
final 4 weeks of that used for early stopping); the last month is held out.
The model is compared with two baselines a planner would actually use:
  * seasonal naive: same hour last week (lag_168h)
  * 7-day same-hour mean

Outputs forecasting/artifacts/{model.txt, metrics.json, feature_importance.csv},
forecasting/results.md, and the warehouse table forecast.test_predictions.
and forecasting/results.md.

Note: weather features are actuals, standing in for a day-ahead weather
forecast. That flatters the model slightly versus production.
"""

import argparse
import json
import os
from pathlib import Path

import duckdb
import lightgbm as lgb
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DB = os.environ.get("DUCKDB_PATH", ROOT / "data" / "warehouse" / "citibike.duckdb")
ART = Path(__file__).with_name("artifacts")

FEATURES = [
    "hour_of_day", "day_of_week", "month", "is_workday", "is_holiday",
    "latitude", "longitude", "borough",
    "temp_avg_f", "temp_max_f", "precip_in", "snowfall_in", "snow_depth_in", "avg_wind_mph",
    "lag_24h", "lag_48h", "lag_168h", "lag_336h", "same_hour_7d_mean", "prev_day_total",
]
CATEGORICAL = ["borough"]


def metrics(y: np.ndarray, pred: np.ndarray) -> dict:
    err = y - pred
    return {
        "mae": float(np.mean(np.abs(err))),
        "rmse": float(np.sqrt(np.mean(err**2))),
        # Weighted absolute % error: robust to the many zero-demand hours.
        "wape_pct": float(100 * np.sum(np.abs(err)) / np.sum(y)),
    }


def load_features(top_n: int) -> pd.DataFrame:
    sql = Path(__file__).with_name("features.sql").read_text()
    con = duckdb.connect(str(DB), read_only=True)
    df = con.execute(sql, {"top_n": top_n}).df()
    df["borough"] = df["borough"].astype("category")
    return df


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--top-n", type=int, default=200)
    args = p.parse_args()

    df = load_features(args.top_n)
    weather_available = df["temp_avg_f"].notna().any()
    features = FEATURES if weather_available else [f for f in FEATURES if not f.startswith(("temp", "precip", "snow", "avg_wind"))]

    test_start = df["hour_ts"].max().to_period("M").start_time
    valid_start = test_start - pd.Timedelta(weeks=4)
    train = df[df["hour_ts"] < valid_start]
    valid = df[(df["hour_ts"] >= valid_start) & (df["hour_ts"] < test_start)]
    test = df[df["hour_ts"] >= test_start]

    model = lgb.LGBMRegressor(
        objective="poisson",       # counts: non-negative, variance grows with mean
        n_estimators=2000,
        learning_rate=0.05,
        num_leaves=63,
        min_child_samples=50,
        subsample=0.8,
        subsample_freq=1,
        colsample_bytree=0.8,
        verbose=-1,
    )
    model.fit(
        train[features], train["target"],
        eval_X=(valid[features],),
        eval_y=(valid["target"],),
        eval_metric="l1",
        categorical_feature=[c for c in CATEGORICAL if c in features],
        callbacks=[lgb.early_stopping(100, verbose=False)],
    )

    y = test["target"].to_numpy()
    pred = model.predict(test[features])
    results = {
        "lightgbm": metrics(y, pred),
        "seasonal_naive_lag_168h": metrics(y, test["lag_168h"].to_numpy()),
        "same_hour_7d_mean": metrics(y, test["same_hour_7d_mean"].to_numpy()),
    }
    meta = {
        "stations": int(df["station_id"].nunique()),
        "train_rows": len(train), "valid_rows": len(valid), "test_rows": len(test),
        "train_period": [str(train["hour_ts"].min()), str(train["hour_ts"].max())],
        "test_period": [str(test["hour_ts"].min()), str(test["hour_ts"].max())],
        "best_iteration": int(model.best_iteration_),
        "weather_features_used": bool(weather_available),
    }

    ART.mkdir(exist_ok=True)
    model.booster_.save_model(ART / "model.txt")
    # Held-out predictions go back into the warehouse for the dashboard.
    predictions = test[["station_id", "hour_ts"]].assign(
        actual=y, predicted=pred.round(2), seasonal_naive=test["lag_168h"].to_numpy()
    )
    with duckdb.connect(str(DB)) as con:
        con.execute("create schema if not exists forecast")
        con.register("predictions", predictions)
        con.execute("create or replace table forecast.test_predictions as select * from predictions")
    (ART / "metrics.json").write_text(json.dumps({"meta": meta, "metrics": results}, indent=2))
    importance = (
        pd.DataFrame({"feature": features, "gain": model.booster_.feature_importance("gain")})
        .sort_values("gain", ascending=False)
    )
    importance["gain_pct"] = (100 * importance["gain"] / importance["gain"].sum()).round(1)
    importance.to_csv(ART / "feature_importance.csv", index=False)

    base = results["seasonal_naive_lag_168h"]["mae"]
    lines = [
        "# Forecast results",
        "",
        f"Day-ahead hourly departures for the {meta['stations']} busiest stations. "
        f"Test period {meta['test_period'][0][:10]} to {meta['test_period'][1][:10]} "
        f"({meta['test_rows']:,} station-hours), trained on {meta['train_rows']:,} station-hours.",
        "",
        "| model | MAE | RMSE | WAPE % | MAE vs seasonal naive |",
        "|---|---:|---:|---:|---:|",
    ]
    for name, m in results.items():
        lines.append(f"| {name} | {m['mae']:.3f} | {m['rmse']:.3f} | {m['wape_pct']:.1f} | {100 * (m['mae'] / base - 1):+.1f}% |")
    lines += ["", "Top features by gain:", ""]
    lines += [f"- `{r.feature}`: {r.gain_pct}%" for r in importance.head(8).itertuples()]
    if not weather_available:
        lines += ["", "_Weather features were unavailable for this run (dim_weather empty) and were excluded._"]
    Path(__file__).with_name("results.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
