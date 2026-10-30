-- Average daily trips by precipitation band, workdays and weekends separately,
-- indexed to dry days of the same day type and season so seasonality doesn't
-- masquerade as a rain effect.
with daily as (
    select d.date_day, d.is_workday, d.season, w.precip_category, count(*) as trips
    from marts.fct_trips t
    join marts.dim_date d on d.date_day = t.start_date
    join marts.dim_weather w on w.weather_date = d.date_day
    where d.year_month >= (select min(source_month) from marts.fct_trips)
    group by all
),
dry as (
    select is_workday, season, avg(trips) as dry_avg
    from daily where precip_category = 'dry' group by all
)
select
    case when d.is_workday then 'Workday' else 'Weekend / holiday' end as day_type,
    d.precip_category,
    case d.precip_category when 'dry' then 1 when 'light' then 2 when 'moderate' then 3 else 4 end as sort_order,
    count(*)                                         as days,
    avg(d.trips)                                     as avg_trips,
    avg(d.trips / dry.dry_avg) - 1                   as change_vs_dry
from daily d
join dry using (is_workday, season)
group by all
order by day_type, sort_order
