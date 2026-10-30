select
    strptime(source_month, '%Y-%m')::date                           as month,
    rider_type,
    count(*)                                                        as trips,
    count(*) / max(count(*)) over (partition by rider_type)         as pct_of_peak
from marts.fct_trips
group by 1, 2
order by month
