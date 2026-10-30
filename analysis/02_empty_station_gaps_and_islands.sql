-- Q: When was a station likely empty (or broken)?
--
-- We don't have dock-level inventory, but a normally busy station that records
-- zero departures for several consecutive daytime hours, while still receiving
-- arrivals, is almost certainly out of bikes.
--
-- Technique: gaps-and-islands. Within each station, row_number() over all
-- hours minus row_number() over just the "dry" hours is constant across a
-- consecutive run, so it becomes the island id.
--
-- Hours where the whole system was down (e.g. 2026-02-23 had zero trips
-- city-wide) are excluded first; otherwise every station looks "empty".

with baseline as (

    -- Typical departures for this station at this hour of day on workdays.
    select station_id, hour_of_day, avg(departures) as typical_departures
    from {{ ref('fct_station_hourly') }} h
    join {{ ref('dim_date') }} d using (date_day)
    where d.is_workday
    group by all

),

system_hours as (

    -- Hours with under 25% of the usual system-wide volume for that hour of day
    -- (median over the surrounding four weeks, so winter isn't flagged).
    select hour_ts
    from (
        select hour_ts, hour_of_day, sum(departures) as system_departures
        from {{ ref('fct_station_hourly') }}
        group by hour_ts, hour_of_day
    )
    qualify system_departures < 0.25 * median(system_departures) over (
        partition by hour_of_day order by hour_ts
        range between interval 14 day preceding and interval 14 day following
    )

),

hours as (

    select
        h.station_id,
        h.hour_ts,
        h.departures,
        h.arrivals,
        -- "Dry" = we'd expect 3+ departures, saw none.
        h.departures = 0 and b.typical_departures >= 3 as is_dry
    from {{ ref('fct_station_hourly') }} h
    join {{ ref('dim_date') }} d using (date_day)
    join baseline b using (station_id, hour_of_day)
    where d.is_workday
      and h.hour_of_day between 6 and 22
      and h.hour_ts not in (select hour_ts from system_hours)

),

islands as (

    select
        *,
        row_number() over (partition by station_id order by hour_ts)
        - row_number() over (partition by station_id, is_dry order by hour_ts) as island_id
    from hours

),

dry_spells as (

    select
        station_id,
        min(hour_ts)                     as spell_start,
        max(hour_ts) + interval 1 hour   as spell_end,
        count(*)                         as hours_without_departures,
        sum(arrivals)                    as arrivals_during_spell
    from islands
    where is_dry
    group by station_id, island_id
    -- Runs only count if contiguous in clock time, not just in row order
    -- (rows for 23:00-05:00 are filtered out above).
    having date_diff('hour', min(hour_ts), max(hour_ts)) + 1 = count(*)
       and count(*) >= 3

)

select
    s.station_name,
    s.borough,
    d.spell_start,
    d.spell_end,
    d.hours_without_departures,
    d.arrivals_during_spell,
    -- Arrivals still landing = bikes are being docked, so the station isn't
    -- closed; it's being drained the moment bikes arrive (or docks are broken).
    case when d.arrivals_during_spell > 0 then 'likely empty' else 'possibly closed' end as interpretation
from dry_spells d
join {{ ref('dim_stations') }} s using (station_id)
order by d.hours_without_departures desc, d.spell_start
limit 50
