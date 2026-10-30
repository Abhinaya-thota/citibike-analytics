select
    rider_type,
    count(*)                                                            as trips,
    median(duration_minutes)                                            as median_minutes,
    avg(case when is_round_trip then 1.0 else 0 end)                    as round_trip_share,
    avg(case when d.is_weekend then 1.0 else 0 end)                     as weekend_share,
    avg(case when rideable_type = 'electric_bike' then 1.0 else 0 end)  as ebike_share,
    median(distance_km) filter (where not is_round_trip)                as median_km
from marts.fct_trips t
join marts.dim_date d on d.date_day = t.start_date
group by rider_type
