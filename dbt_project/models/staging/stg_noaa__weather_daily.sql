with source as (

    select * from {{ source('noaa', 'weather_daily') }}

)

select
    cast("date" as date)                as weather_date,
    station                             as noaa_station_id,
    "name"                              as noaa_station_name,
    try_cast(prcp as double)            as precip_in,
    try_cast(snow as double)            as snowfall_in,
    try_cast(snwd as double)            as snow_depth_in,
    try_cast(tmax as double)            as temp_max_f,
    try_cast(tmin as double)            as temp_min_f,
    try_cast(awnd as double)            as avg_wind_mph,
    _ingested_at                        as ingested_at
from source
