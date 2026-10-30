---
title: Citi Bike NYC — a year of trips
---

```sql kpis
select * from citibike.kpis
```

```sql daily
select * from citibike.daily_ridership
```

```sql outages
select * from citibike.system_outages
```

<BigValue data={kpis} value=trips title="Trips" fmt=num0 />
<BigValue data={kpis} value=stations title="Stations" fmt=num0 />
<BigValue data={kpis} value=member_share title="Member share" fmt=pct0 />
<BigValue data={kpis} value=median_minutes title="Median ride (min)" fmt=num1 />
<BigValue data={kpis} value=ebike_share title="E-bike share" fmt=pct0 />

Every Citi Bike trip from <Value data={kpis} column=first_day fmt="mmm yyyy" /> to
<Value data={kpis} column=last_day fmt="mmm yyyy" />, refreshed monthly by an automated
pipeline (Python → Parquet → dbt on DuckDB). Each page answers one question:

- **[Does rain keep riders home?](/rain)** How much each band of rainfall cuts ridership.
- **[Where does rebalancing hurt?](/rebalancing)** Stations that run empty or full every rush hour.
- **[Members vs. casual riders](/riders)** Two very different customer bases.
- **[Forecasting demand](/forecast)** A day-ahead station-level model built on warehouse features.

## Daily trips

<LineChart
    data={daily}
    x=date_day
    y={['member_trips', 'casual_trips']}
    yAxisTitle="Trips per day"
    yFmt=num0
/>

## Days the system effectively shut down

Days with under a quarter of the volume typical for that time of year. These are excluded from the
empty-station analysis so a city-wide shutdown doesn't look like empty docks.

<DataTable data={outages}>
    <Column id=date_day title="Date" />
    <Column id=day_name title="Day" />
    <Column id=trips fmt=num0 />
    <Column id=share_of_typical title="Share of a typical day" fmt=pct0 />
</DataTable>
