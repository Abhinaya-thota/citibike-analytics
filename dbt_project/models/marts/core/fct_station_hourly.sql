-- Station x hour demand, zero-filled. A station appears for every hour between
-- its first and last day of activity, so "no trips" is an explicit 0, which is
-- what forecasting and the empty-station analysis need.
--
-- The grid is clipped to the calendar months actually loaded. Each monthly file
-- also holds rides that *started* on the last day of the previous month (they
-- ended after midnight), which would otherwise show up as a near-empty day.

with flows as (

    select * from {{ ref('int_station_hourly__flows') }}

),

coverage as (

    select
        strptime(min(source_month), '%Y-%m')                          as start_ts,
        strptime(max(source_month), '%Y-%m') + interval 1 month       as end_ts
    from {{ ref('fct_trips') }}

),

stations as (

    select station_id, first_seen_date, last_seen_date from {{ ref('dim_stations') }}

),

hours as (

    select unnest(generate_series(start_ts, end_ts - interval 1 hour, interval 1 hour)) as hour_ts
    from coverage

),

grid as (

    select s.station_id, h.hour_ts
    from stations s
    join hours h
      on h.hour_ts >= s.first_seen_date
     and h.hour_ts <  s.last_seen_date + interval 1 day

)

select
    g.station_id,
    g.hour_ts,
    g.hour_ts::date                                     as date_day,
    hour(g.hour_ts)                                     as hour_of_day,
    coalesce(f.departures, 0)                           as departures,
    coalesce(f.arrivals, 0)                             as arrivals,
    coalesce(f.arrivals, 0) - coalesce(f.departures, 0) as net_flow,
    coalesce(f.member_departures, 0)                    as member_departures,
    coalesce(f.casual_departures, 0)                    as casual_departures,
    coalesce(f.ebike_departures, 0)                     as ebike_departures
from grid g
left join flows f
  on f.station_id = g.station_id and f.hour_ts = g.hour_ts
