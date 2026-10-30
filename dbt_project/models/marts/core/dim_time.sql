-- Hour-of-day dimension. Peak windows follow common NYC transit definitions.

select
    hour_of_day,
    lpad(hour_of_day::varchar, 2, '0') || ':00'     as hour_label,
    case
        when hour_of_day between 7 and 9   then 'am_peak'
        when hour_of_day between 10 and 15 then 'midday'
        when hour_of_day between 16 and 19 then 'pm_peak'
        when hour_of_day between 20 and 23 then 'evening'
        else 'overnight'
    end                                             as day_part,
    hour_of_day between 7 and 9
        or hour_of_day between 16 and 19            as is_peak
from (select unnest(range(24)) as hour_of_day)
