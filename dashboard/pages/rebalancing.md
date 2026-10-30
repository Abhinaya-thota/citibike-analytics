---
title: Where does rebalancing hurt?
---

```sql imbalance
select * from citibike.station_imbalance
where rush_hour = '${inputs.rush_hour.value}'
order by abs_net_flow desc
```

```sql rush_hours
select distinct rush_hour from citibike.station_imbalance order by 1
```

Net flow = bikes arriving minus bikes leaving during the rush-hour window on an
average workday. A station at **−60** loses 60 bikes every morning and needs a
truck to refill it; one at **+60** fills up and turns riders away.
**Consistency** is the share of workdays the flow went the same direction,
which separates chronic problems from one-off bad days.

<Dropdown data={rush_hours} name=rush_hour value=rush_hour defaultValue="AM peak (7-10)" />

<PointMap
    data={imbalance}
    lat=latitude
    long=longitude
    value=avg_net_flow
    pointName=station_name
    colorPalette={['#c2410c', '#f5f5f4', '#1d4ed8']}
    legendType=scalar
    height=520
    tooltip={[
        {id: 'station_name', showColumnName: false, valueClass: 'font-bold'},
        {id: 'avg_net_flow', fmt: 'num1', fieldClass: 'text-[grey]'},
        {id: 'consistency', fmt: 'pct0'}
    ]}
/>

<DataTable data={imbalance} rows=20 search=true>
    <Column id=station_name title="Station" />
    <Column id=borough />
    <Column id=avg_net_flow title="Avg net flow" fmt=num1 contentType=delta />
    <Column id=consistency fmt=pct0 />
    <Column id=problem />
</DataTable>

The morning flood stations are the evening drain stations: the same commuters
ride in and back out. Midtown and Hudson Yards absorb bikes from residential
Brooklyn, Queens and upper Manhattan every morning.
