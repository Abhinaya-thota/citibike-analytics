-- Days when system-wide volume collapsed: under 25% of the median of the same
-- day type (workday vs. not) in the surrounding four weeks. The rolling window
-- keeps ordinary winter days from looking like outages.
with daily as (
    select d.date_day, d.day_name, d.is_workday, count(t.trip_id) as trips
    from marts.dim_date d
    left join marts.fct_trips t on t.start_date = d.date_day
    where d.year_month >= (select min(source_month) from marts.fct_trips)
    group by all
),
scored as (
    select *,
        median(trips) over (
            partition by is_workday order by date_day
            range between interval 14 day preceding and interval 14 day following
        ) as typical_trips
    from daily
)
select date_day, day_name, trips, typical_trips, trips / typical_trips as share_of_typical
from scored
where trips < 0.25 * typical_trips
order by date_day
