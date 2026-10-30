-- Q: Which stations are busiest, how does each rank inside its borough, and
--    is its demand trending up or down?
--
-- Techniques: DENSE_RANK / PERCENT_RANK partitioned by borough, a 7-day
-- rolling average with a RANGE frame (robust to missing days), and LAG for
-- week-over-week change.

with daily as (

    select
        s.station_id,
        s.station_name,
        s.borough,
        h.date_day,
        sum(h.departures) as departures
    from {{ ref('fct_station_hourly') }} h
    join {{ ref('dim_stations') }} s using (station_id)
    where s.is_active
    group by all

),

rolling as (

    select
        *,
        avg(departures) over (
            partition by station_id
            order by date_day
            range between interval 6 day preceding and current row
        ) as departures_7d_avg
    from daily

),

latest as (

    -- The rolling average as of the last day of data, and one week earlier.
    select
        station_id, station_name, borough,
        departures_7d_avg,
        lag(departures_7d_avg, 7) over (partition by station_id order by date_day) as departures_7d_avg_prev_week,
        date_day
    from rolling
    qualify date_day = max(date_day) over ()

),

totals as (

    select station_id, sum(departures) as total_departures
    from daily
    group by station_id

)

select
    l.borough,
    dense_rank() over (partition by l.borough order by t.total_departures desc)  as borough_rank,
    round(100 * percent_rank() over (order by t.total_departures), 1)            as system_percentile,
    l.station_name,
    t.total_departures,
    round(l.departures_7d_avg, 1)                                                as departures_7d_avg,
    round(100.0 * (l.departures_7d_avg - l.departures_7d_avg_prev_week)
          / nullif(l.departures_7d_avg_prev_week, 0), 1)                         as wow_change_pct
from latest l
join totals t using (station_id)
-- NJ stations only ever appear as destinations in the NYC files.
where t.total_departures > 0
qualify borough_rank <= 5
order by l.borough, borough_rank
