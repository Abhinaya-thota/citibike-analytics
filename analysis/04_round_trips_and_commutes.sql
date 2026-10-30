-- Q: Where are the leisure loops and where are the commutes?
--
-- Round trips (start = end) are leisure. A commute shows up as a station pair
-- with strong A->B flow on weekday mornings and a matching B->A flow on
-- weekday evenings. Technique: self-join of directional flows, and
-- LEAST/GREATEST to build an order-independent pair key.

with weekday_trips as (

    select t.*, tm.day_part
    from {{ ref('fct_trips') }} t
    join {{ ref('dim_date') }} d on d.date_day = t.start_date
    join {{ ref('dim_time') }} tm on tm.hour_of_day = t.start_hour
    where d.is_workday
      and t.start_station_id is not null
      and t.end_station_id is not null
      and not t.is_round_trip

),

flows as (

    select start_station_id, end_station_id, day_part, count(*) as trips,
           count(*) filter (where rider_type = 'member') as member_trips
    from weekday_trips
    where day_part in ('am_peak', 'pm_peak')
    group by all

),

commute_pairs as (

    -- Morning A->B matched with evening B->A.
    select
        am.start_station_id         as home_station_id,
        am.end_station_id           as work_station_id,
        am.trips                    as am_trips,
        pm.trips                    as pm_return_trips,
        round(100.0 * (am.member_trips + pm.member_trips) / (am.trips + pm.trips), 1) as member_pct,
        -- Symmetry near 1.0 = the same people going and coming back.
        round(least(am.trips, pm.trips)::double / greatest(am.trips, pm.trips), 2) as symmetry
    from flows am
    join flows pm
      on pm.start_station_id = am.end_station_id
     and pm.end_station_id   = am.start_station_id
     and am.day_part = 'am_peak'
     and pm.day_part = 'pm_peak'
    where am.trips >= 30 and pm.trips >= 30

),

round_trip_hotspots as (

    select start_station_id as station_id,
           count(*) as round_trips,
           round(100.0 * avg(case when rider_type = 'casual' then 1 else 0 end), 1) as casual_pct,
           round(median(duration_minutes), 1) as median_minutes
    from {{ ref('fct_trips') }}
    where is_round_trip and duration_minutes >= 2   -- under 2 min = re-docked, not a ride
    group by 1
    order by round_trips desc
    limit 15

)

select 'commute' as kind,
       h.station_name || '  ->  ' || w.station_name as route,
       c.am_trips + c.pm_return_trips as trips, c.member_pct, c.symmetry,
       null::double as median_minutes
from commute_pairs c
join {{ ref('dim_stations') }} h on h.station_id = c.home_station_id
join {{ ref('dim_stations') }} w on w.station_id = c.work_station_id
qualify row_number() over (order by c.am_trips + c.pm_return_trips desc) <= 15

union all

select 'round_trip', s.station_name, r.round_trips, round(100 - r.casual_pct, 1), null, r.median_minutes
from round_trip_hotspots r
join {{ ref('dim_stations') }} s using (station_id)
order by kind, trips desc
