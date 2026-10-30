# Forecast results

Day-ahead hourly departures for the 200 busiest stations. Test period 2026-09-01 to 2026-09-30 (141,936 station-hours), trained on 1,405,632 station-hours.

| model | MAE | RMSE | WAPE % | MAE vs seasonal naive |
|---|---:|---:|---:|---:|
| lightgbm | 4.297 | 6.611 | 36.0 | -20.7% |
| seasonal_naive_lag_168h | 5.417 | 8.456 | 45.3 | +0.0% |
| same_hour_7d_mean | 5.214 | 7.985 | 43.6 | -3.7% |

Top features by gain:

- `same_hour_7d_mean`: 66.9%
- `lag_24h`: 11.4%
- `lag_336h`: 7.2%
- `lag_168h`: 5.7%
- `hour_of_day`: 3.1%
- `day_of_week`: 1.5%
- `prev_day_total`: 1.3%
- `month`: 1.2%

_Weather features were unavailable for this run (dim_weather empty) and were excluded._
