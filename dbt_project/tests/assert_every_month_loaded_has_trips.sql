-- A month that is in the raw layer but produced almost no clean trips means the
-- file format changed under us. Citi Bike's quietest month is ~1M+ trips.

select source_month, count(*) as trips
from {{ ref('fct_trips') }}
group by source_month
having count(*) < {{ var('min_trips_per_month', 500000) }}
