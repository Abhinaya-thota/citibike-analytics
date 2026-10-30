-- One row per station_id. Stations are never published as a table in the trip
-- files, so we reconstruct them from every trip start and end.

with observations as (

    select start_station_id as station_id, start_station_name as station_name,
           start_lat as lat, start_lng as lng, started_at as observed_at,
           rideable_type
    from {{ ref('stg_citibike__trips') }}
    where start_station_id is not null

    union all

    select end_station_id, end_station_name, end_lat, end_lng, ended_at, rideable_type
    from {{ ref('stg_citibike__trips') }}
    where end_station_id is not null

)

select
    station_id,
    -- Stations get renamed; report the most recent name.
    arg_max(station_name, observed_at)          as station_name,
    count(distinct station_name)                as name_variants,
    -- Classic bikes report the dock's coordinates; e-bikes report noisy GPS.
    -- Prefer the classic-bike median, fall back to all trips.
    coalesce(median(lat) filter (where rideable_type = 'classic_bike'), median(lat)) as latitude,
    coalesce(median(lng) filter (where rideable_type = 'classic_bike'), median(lng)) as longitude,
    min(observed_at)::date                      as first_seen_date,
    max(observed_at)::date                      as last_seen_date,
    count(*)                                    as total_trip_endpoints
from observations
group by station_id
