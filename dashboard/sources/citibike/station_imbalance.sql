-- Rush-hour net flow per station (arrivals - departures), workdays only.
-- Same logic as analysis/05_rush_hour_imbalance.sql, kept for every station
-- so the dashboard can filter and map it.
with peak_daily as (
    select h.station_id, h.date_day, tm.day_part, sum(h.net_flow) as net_flow
    from marts.fct_station_hourly h
    join marts.dim_date d using (date_day)
    join marts.dim_time tm on tm.hour_of_day = h.hour_of_day
    where d.is_workday and tm.day_part in ('am_peak', 'pm_peak')
    group by all
),
with_avg as (
    select *, avg(net_flow) over (partition by station_id, day_part) as station_avg
    from peak_daily
)
select
    s.station_name,
    s.borough,
    s.latitude,
    s.longitude,
    case p.day_part when 'am_peak' then 'AM peak (7-10)' else 'PM peak (16-20)' end as rush_hour,
    avg(p.net_flow)                                                          as avg_net_flow,
    abs(avg(p.net_flow))                                                     as abs_net_flow,
    avg(case when sign(p.net_flow) = sign(p.station_avg) then 1.0 else 0 end) as consistency,
    case when avg(p.net_flow) < 0 then 'Drains: needs bikes' else 'Floods: needs docks' end as problem
from with_avg p
join marts.dim_stations s using (station_id)
group by s.station_name, s.borough, s.latitude, s.longitude, p.day_part
having count(*) >= 20 and abs(avg(p.net_flow)) >= 5
