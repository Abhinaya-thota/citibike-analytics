# Forecast results

Day-ahead hourly departures for the 200 busiest stations. Test period 2026-09-01 to 2026-09-30 (141,936 station-hours), trained on 1,405,632 station-hours.

| model | MAE | RMSE | WAPE % | MAE vs seasonal naive |
|---|---:|---:|---:|---:|
| lightgbm | 3.955 | 6.042 | 33.1 | -27.0% |
| seasonal_naive_lag_168h | 5.417 | 8.456 | 45.3 | +0.0% |
| same_hour_7d_mean | 5.214 | 7.985 | 43.6 | -3.7% |

Top features by gain:

- `same_hour_7d_mean`: 54.6%
- `lag_24h`: 16.1%
- `lag_168h`: 9.2%
- `lag_336h`: 6.1%
- `hour_of_day`: 3.0%
- `precip_in`: 2.9%
- `temp_max_f`: 1.6%
- `temp_avg_f`: 1.0%
