-- Average trips started per hour of day, by rider type and day type.
with days as (
    select is_workday, count(*) as n_days
    from marts.dim_date
    where year_month >= (select min(source_month) from marts.fct_trips)
    group by 1
)
select
    t.start_hour                                                    as hour_of_day,
    t.rider_type,
    case when d.is_workday then 'Workday' else 'Weekend / holiday' end as day_type,
    count(*) / max(days.n_days)                                     as avg_trips
from marts.fct_trips t
join marts.dim_date d on d.date_day = t.start_date
join days using (is_workday)
where d.year_month >= (select min(source_month) from marts.fct_trips)
group by all
order by hour_of_day
