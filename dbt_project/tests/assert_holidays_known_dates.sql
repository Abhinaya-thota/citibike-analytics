-- Spot-check the rule-based holiday calendar against published OPM dates
-- (only for years the calendar covers, which depends on the data loaded).

with expected(observed_date, holiday_name) as (
    values
        (date '2025-11-27', 'Thanksgiving'),
        (date '2026-01-19', 'Martin Luther King Jr. Day'),
        (date '2026-05-25', 'Memorial Day'),
        (date '2026-07-03', 'Independence Day'),   -- Jul 4 2026 is a Saturday
        (date '2026-09-07', 'Labor Day')
)

select e.*
from expected e
left join {{ ref('int_us_holidays') }} h using (observed_date, holiday_name)
where h.observed_date is null
  and year(e.observed_date) in (select distinct year(holiday_date) from {{ ref('int_us_holidays') }})
