-- Departures and arrivals per station per hour, only for hours with activity.
-- fct_station_hourly zero-fills this onto a complete station x hour grid.

with departures as (

    select
        start_station_id                                   as station_id,
        date_trunc('hour', started_at)                     as hour_ts,
        count(*)                                           as departures,
        count(*) filter (where rider_type = 'member')      as member_departures,
        count(*) filter (where rider_type = 'casual')      as casual_departures,
        count(*) filter (where rideable_type = 'electric_bike') as ebike_departures
    from {{ ref('stg_citibike__trips') }}
    where start_station_id is not null
    group by all

),

arrivals as (

    select
        end_station_id                                     as station_id,
        date_trunc('hour', ended_at)                       as hour_ts,
        count(*)                                           as arrivals
    from {{ ref('stg_citibike__trips') }}
    where end_station_id is not null
    group by all

)

select
    coalesce(d.station_id, a.station_id)                   as station_id,
    coalesce(d.hour_ts, a.hour_ts)                         as hour_ts,
    coalesce(d.departures, 0)                              as departures,
    coalesce(a.arrivals, 0)                                as arrivals,
    coalesce(d.member_departures, 0)                       as member_departures,
    coalesce(d.casual_departures, 0)                       as casual_departures,
    coalesce(d.ebike_departures, 0)                        as ebike_departures
from departures d
full outer join arrivals a
    on d.station_id = a.station_id and d.hour_ts = a.hour_ts
