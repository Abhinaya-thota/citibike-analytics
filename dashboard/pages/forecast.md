---
title: Forecasting station demand
---

```sql daily_eval
select
    date_day,
    sum(actual)          as actual,
    sum(predicted)       as lightgbm,
    sum(seasonal_naive)  as seasonal_naive
from citibike.forecast_eval
group by 1 order by 1
```

```sql accuracy
select
    'LightGBM' as model,
    avg(abs(actual - predicted)) as mae,
    sum(abs(actual - predicted)) / sum(actual) as wape
from citibike.forecast_eval
union all
select
    'Same hour last week',
    avg(abs(actual - seasonal_naive)),
    sum(abs(actual - seasonal_naive)) / sum(actual)
from citibike.forecast_eval
```

```sql stations
select distinct station_name from citibike.forecast_eval order by 1
```

```sql one_station
select hour_ts, actual, predicted as lightgbm, seasonal_naive
from citibike.forecast_eval
where station_name = '${inputs.station.value}'
order by hour_ts
```

A LightGBM model predicts **next-day hourly departures** for the 200 busiest
stations. Every feature (lags, rolling means, calendar, weather) is computed in
SQL in the warehouse (`forecasting/features.sql`); results below are on a
held-out final month the model never saw.

<DataTable data={accuracy}>
    <Column id=model />
    <Column id=mae title="MAE (trips / station-hour)" fmt=num2 />
    <Column id=wape title="WAPE" fmt=pct1 />
</DataTable>

<LineChart
    data={daily_eval}
    x=date_day
    y={['actual', 'lightgbm', 'seasonal_naive']}
    title="Daily departures, 200 stations"
    yFmt=num0
/>

<Dropdown data={stations} name=station value=station_name defaultValue="W 21 St & 6 Ave" />

<LineChart
    data={one_station}
    x=hour_ts
    y={['actual', 'lightgbm']}
    title="Hourly departures at {inputs.station.value}"
/>
