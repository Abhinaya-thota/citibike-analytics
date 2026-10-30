select
    count(*)                                                 as trips,
    count(distinct start_station_id)                         as stations,
    min(start_date)                                          as first_day,
    max(start_date)                                          as last_day,
    avg(case when rider_type = 'member' then 1.0 else 0 end) as member_share,
    median(duration_minutes)                                 as median_minutes,
    avg(case when rideable_type = 'electric_bike' then 1.0 else 0 end) as ebike_share
from marts.fct_trips
