---
title: Does rain keep riders home?
---

```sql rain
select * from citibike.rain_effect order by day_type, sort_order
```

```sql daily
select * from citibike.daily_ridership where precip_in is not null
```

{#if rain.length > 0}

Daily trips by rainfall at Central Park (NOAA), compared with dry days **of the
same day type and season** so that winter doesn't masquerade as a rain effect.

<BarChart
    data={rain}
    x=precip_category
    y=change_vs_dry
    series=day_type
    type=grouped
    yFmt=pct0
    yAxisTitle="Change in daily trips vs. a dry day"
    sort=false
/>

<DataTable data={rain}>
    <Column id=day_type />
    <Column id=precip_category title="Rain" />
    <Column id=days />
    <Column id=avg_trips title="Avg trips / day" fmt=num0 />
    <Column id=change_vs_dry title="vs. dry" fmt=pct0 contentType=delta />
</DataTable>

Bands: light < 0.1 in, moderate 0.1–0.5 in, heavy ≥ 0.5 in.

<ScatterPlot
    data={daily}
    x=temp_avg_f
    y=trips
    series=precip_category
    xAxisTitle="Average temperature (°F)"
    yAxisTitle="Trips"
/>

{:else}

**No weather data loaded.** Run `python -m ingestion.run` with network access to
`www.ncei.noaa.gov`, then `dbt build`, then `npm run sources`.

{/if}
