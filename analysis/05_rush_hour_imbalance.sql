-- Q: Which stations are chronically imbalanced at rush hour, i.e. drained
--    every morning or flooded every evening, and therefore need rebalancing?
--
-- Technique: conditional aggregation, plus a consistency score (share of
-- workdays where the station's net flow had the same sign) so we surface
-- chronic imbalance rather than one bad day.

with peak_daily as (

    select
        h.station_id,
        h.date_day,
        tm.day_part,
        sum(h.net_flow) as net_flow
    from {{ ref('fct_station_hourly') }} h
    join {{ ref('dim_date') }} d using (date_day)
    join {{ ref('dim_time') }} tm on tm.hour_of_day = h.hour_of_day
    where d.is_workday and tm.day_part in ('am_peak', 'pm_peak')
    group by all

),

with_station_avg as (

    select *, avg(net_flow) over (partition by station_id, day_part) as station_avg_net_flow
    from peak_daily

)

select
    s.station_name,
    s.borough,
    p.day_part,
    round(avg(p.net_flow), 1)                                         as avg_net_flow,
    -- Share of workdays the flow went the same way as the station's average.
    round(100.0 * avg(case when sign(p.net_flow) = sign(p.station_avg_net_flow) then 1 else 0 end), 0) as same_direction_pct,
    case when avg(p.net_flow) < 0 then 'drains (needs bikes)' else 'floods (needs docks)' end as problem
from with_station_avg p
join {{ ref('dim_stations') }} s using (station_id)
group by s.station_name, s.borough, p.day_part
having count(*) >= 20
qualify row_number() over (partition by p.day_part order by abs(avg(p.net_flow)) desc) <= 10
order by p.day_part, abs(avg_net_flow) desc
