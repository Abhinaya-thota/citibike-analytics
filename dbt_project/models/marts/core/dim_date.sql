with bounds as (

    select min(started_at)::date as start_date, max(ended_at)::date as end_date
    from {{ ref('stg_citibike__trips') }}

),

spine as (

    select unnest(generate_series(start_date, end_date, interval 1 day))::date as date_day
    from bounds

),

holidays as (

    select observed_date, holiday_name from {{ ref('int_us_holidays') }}

)

select
    s.date_day,
    year(s.date_day)                            as year,
    quarter(s.date_day)                         as quarter,
    month(s.date_day)                           as month,
    strftime(s.date_day, '%b')                  as month_name,
    strftime(s.date_day, '%Y-%m')               as year_month,
    day(s.date_day)                             as day_of_month,
    isodow(s.date_day)                          as day_of_week,     -- Mon=1 .. Sun=7
    strftime(s.date_day, '%a')                  as day_name,
    weekofyear(s.date_day)                      as iso_week,
    isodow(s.date_day) in (6, 7)                as is_weekend,
    h.holiday_name is not null                  as is_holiday,
    h.holiday_name,
    isodow(s.date_day) between 1 and 5
        and h.holiday_name is null              as is_workday,
    case
        when month(s.date_day) in (12, 1, 2) then 'winter'
        when month(s.date_day) in (3, 4, 5)  then 'spring'
        when month(s.date_day) in (6, 7, 8)  then 'summer'
        else 'fall'
    end                                         as season
from spine s
left join holidays h on h.observed_date = s.date_day
