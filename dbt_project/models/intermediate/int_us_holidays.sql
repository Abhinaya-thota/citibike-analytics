-- US federal holidays computed from their rules, with weekend observance
-- shifts, so dim_date works for any year without a hand-maintained seed.

with years as (

    select unnest(generate_series(
        (select year(min(started_at)) from {{ ref('stg_citibike__trips') }}),
        (select year(max(started_at)) from {{ ref('stg_citibike__trips') }}) + 1
    )) as yr

),

-- n-th <weekday> of a month; isodow: Mon=1 .. Sun=7. n = -1 means "last".
rules(holiday_name, month_num, day_num, weekday, nth) as (
    values
        ('New Year''s Day',            1,  1,    null, null),
        ('Martin Luther King Jr. Day', 1,  null, 1,    3),
        ('Presidents'' Day',           2,  null, 1,    3),
        ('Memorial Day',               5,  null, 1,    -1),
        ('Juneteenth',                 6,  19,   null, null),
        ('Independence Day',           7,  4,    null, null),
        ('Labor Day',                  9,  null, 1,    1),
        ('Columbus Day',               10, null, 1,    2),
        ('Veterans Day',               11, 11,   null, null),
        ('Thanksgiving',               11, null, 4,    4),
        ('Christmas Day',              12, 25,   null, null)
),

actual as (

    select
        holiday_name,
        day_num is not null as is_fixed_date,
        case
            when day_num is not null then make_date(yr, month_num, day_num)
            when nth > 0 then
                make_date(yr, month_num, 1)
                + cast(((weekday - isodow(make_date(yr, month_num, 1)) + 7) % 7) + 7 * (nth - 1) as integer)
            else
                last_day(make_date(yr, month_num, 1))
                - cast((isodow(last_day(make_date(yr, month_num, 1))) - weekday + 7) % 7 as integer)
        end as holiday_date
    from years cross join rules
    where not (holiday_name = 'Juneteenth' and yr < 2021)

)

select
    holiday_name,
    holiday_date,
    -- Saturday holidays are observed Friday, Sunday holidays Monday.
    case
        when is_fixed_date and isodow(holiday_date) = 6 then holiday_date - 1
        when is_fixed_date and isodow(holiday_date) = 7 then holiday_date + 1
        else holiday_date
    end as observed_date
from actual
