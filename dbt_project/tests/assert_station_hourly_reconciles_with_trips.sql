-- Every docked trip inside the loaded months must be counted exactly once as a
-- departure and once as an arrival in fct_station_hourly. Returns rows only if
-- the totals disagree.

with coverage as (
    select strptime(min(source_month), '%Y-%m') as start_ts,
           strptime(max(source_month), '%Y-%m') + interval 1 month as end_ts
    from {{ ref('fct_trips') }}
),

trips as (
    select
        count(*) filter (where start_station_id is not null
                           and started_at >= start_ts and started_at < end_ts) as trip_departures,
        count(*) filter (where end_station_id is not null
                           and ended_at >= start_ts and ended_at < end_ts)     as trip_arrivals
    from {{ ref('fct_trips') }}, coverage
),

hourly as (
    select sum(departures) as hourly_departures, sum(arrivals) as hourly_arrivals
    from {{ ref('fct_station_hourly') }}
)

select *
from trips cross join hourly
where trip_departures <> hourly_departures
   or trip_arrivals   <> hourly_arrivals
