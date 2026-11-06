# Forecast results

Day-ahead hourly departures for the 200 busiest stations. Test period 2026-10-01 to 2026-10-31 (147,360 station-hours), trained on 1,396,536 station-hours.

| model | MAE | RMSE | WAPE % | MAE vs seasonal naive |
|---|---:|---:|---:|---:|
| lightgbm | 3.506 | 5.459 | 30.0 | -26.2% |
| seasonal_naive_lag_168h | 4.748 | 7.446 | 40.7 | +0.0% |
| same_hour_7d_mean | 4.778 | 7.472 | 40.9 | +0.6% |

Top features by gain:

- `same_hour_7d_mean`: 52.9%
- `lag_24h`: 12.3%
- `lag_168h`: 12.1%
- `lag_336h`: 5.4%
- `hour_of_day`: 3.7%
- `precip_in`: 3.2%
- `temp_max_f`: 1.8%
- `temp_avg_f`: 1.4%
