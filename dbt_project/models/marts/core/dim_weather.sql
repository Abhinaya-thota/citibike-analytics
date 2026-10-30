select
    weather_date,
    precip_in,
    snowfall_in,
    snow_depth_in,
    temp_max_f,
    temp_min_f,
    (temp_max_f + temp_min_f) / 2                   as temp_avg_f,
    avg_wind_mph,
    case
        when precip_in is null  then 'unknown'
        when precip_in = 0      then 'dry'
        when precip_in < 0.1    then 'light'
        when precip_in < 0.5    then 'moderate'
        else 'heavy'
    end                                             as precip_category,
    precip_in >= 0.1                                as is_wet_day,
    coalesce(snowfall_in, 0) > 0
        or coalesce(snow_depth_in, 0) >= 1          as is_snow_day,
    case
        when (temp_max_f + temp_min_f) / 2 < 32 then 'freezing'
        when (temp_max_f + temp_min_f) / 2 < 50 then 'cold'
        when (temp_max_f + temp_min_f) / 2 < 65 then 'mild'
        when (temp_max_f + temp_min_f) / 2 < 80 then 'warm'
        else 'hot'
    end                                             as temp_band
from {{ ref('stg_noaa__weather_daily') }}
