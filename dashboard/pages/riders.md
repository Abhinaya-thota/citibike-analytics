---
title: Members vs. casual riders
---

```sql profile
select * from citibike.rider_profile
```

```sql hourly
select * from citibike.hourly_profile
```

```sql monthly
select * from citibike.monthly_by_segment
```

<DataTable data={profile}>
    <Column id=rider_type title="Rider" />
    <Column id=trips fmt=num0 />
    <Column id=median_minutes title="Median minutes" fmt=num1 />
    <Column id=median_km title="Median km (A→B)" fmt=num2 />
    <Column id=round_trip_share title="Round trips" fmt=pct1 />
    <Column id=weekend_share title="On weekends" fmt=pct0 />
    <Column id=ebike_share title="E-bike" fmt=pct0 />
</DataTable>

## When they ride

Members show the classic two-peak commuter curve on workdays; casual riders
ride in the afternoon and on weekends.

<LineChart
    data={hourly.filter(d => d.day_type === 'Workday')}
    x=hour_of_day
    y=avg_trips
    series=rider_type
    title="Workdays"
    yAxisTitle="Avg trips started per hour"
    yFmt=num0
/>

<LineChart
    data={hourly.filter(d => d.day_type !== 'Workday')}
    x=hour_of_day
    y=avg_trips
    series=rider_type
    title="Weekends and holidays"
    yAxisTitle="Avg trips started per hour"
    yFmt=num0
/>

## Who keeps riding through winter

Each segment's monthly trips as a share of its own peak month. Trips are
anonymous, so this is segment-level retention rather than per-rider cohorts.

<LineChart
    data={monthly}
    x=month
    y=pct_of_peak
    series=rider_type
    yFmt=pct0
    yAxisTitle="Share of peak month"
/>
