-- One row per day, clipped to the fully loaded months.
select
    d.date_day,
    d.day_name,
    d.is_workday,
    d.holiday_name,
    count(*)                                            as trips,
    count(*) filter (where t.rider_type = 'member')     as member_trips,
    count(*) filter (where t.rider_type = 'casual')     as casual_trips,
    w.precip_in,
    w.precip_category,
    w.temp_avg_f,
    w.temp_band,
    w.is_snow_day
from marts.fct_trips t
join marts.dim_date d on d.date_day = t.start_date
left join marts.dim_weather w on w.weather_date = d.date_day
where d.year_month >= (select min(source_month) from marts.fct_trips)
group by all
order by d.date_day
