-- Q: How do members and casual riders behave differently, and how well does
--    each segment "retain" its riding from the summer peak into winter?
--
-- Trips are anonymous (no rider id), so classic cohort retention is not
-- possible. The segment-level analogue: index each segment's monthly volume
-- to its own peak month, and track month-over-month retention with LAG.
-- Plus a behaviour profile per segment.

with profile as (

    select
        rider_type,
        count(*)                                                       as trips,
        round(median(duration_minutes), 1)                             as median_minutes,
        round(quantile_cont(duration_minutes, 0.9), 1)                 as p90_minutes,
        round(100.0 * avg(case when t.is_round_trip then 1 else 0 end), 2)  as round_trip_pct,
        round(100.0 * avg(case when d.is_weekend then 1 else 0 end), 1)     as weekend_pct,
        round(100.0 * avg(case when tm.is_peak and d.is_workday then 1 else 0 end), 1) as weekday_peak_pct,
        round(100.0 * avg(case when rideable_type = 'electric_bike' then 1 else 0 end), 1) as ebike_pct,
        round(median(distance_km) filter (where not is_round_trip), 2) as median_km
    from {{ ref('fct_trips') }} t
    join {{ ref('dim_date') }} d on d.date_day = t.start_date
    join {{ ref('dim_time') }} tm on tm.hour_of_day = t.start_hour
    group by rider_type

),

monthly as (

    select rider_type, source_month, count(*) as trips
    from {{ ref('fct_trips') }}
    group by rider_type, source_month

),

retention as (

    select
        rider_type,
        source_month,
        trips,
        round(100.0 * trips / max(trips) over (partition by rider_type), 1)        as pct_of_peak_month,
        round(100.0 * trips / lag(trips) over (partition by rider_type order by source_month), 1) as pct_of_prior_month,
        round(100.0 * trips / sum(trips) over (partition by source_month), 1)     as share_of_month
    from monthly

)

select 'profile' as section, p.rider_type, null::varchar as source_month, p.* exclude (rider_type)
from profile p

union all by name

select 'monthly_retention' as section, *
from retention

order by section desc, rider_type, source_month
