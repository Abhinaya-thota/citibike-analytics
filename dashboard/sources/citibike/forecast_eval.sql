-- Held-out September predictions written by forecasting/train.py.
select
    p.hour_ts,
    p.hour_ts::date                 as date_day,
    s.station_name,
    p.actual,
    p.predicted,
    p.seasonal_naive
from forecast.test_predictions p
join marts.dim_stations s using (station_id)
