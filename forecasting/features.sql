-- Feature table for day-ahead hourly demand forecasting, built entirely in the
-- warehouse. One row per (station, hour). Every lag is >= 24h so all features
-- are known at midnight before the day being forecast.
--
-- Parameter: $top_n (number of busiest stations to model).

with top_stations as (

    select station_id
    from marts.dim_stations
    where is_active and total_trip_endpoints > 0
    order by total_trip_endpoints desc
    limit $top_n

),

base as (

    select
        h.station_id,
        h.hour_ts,
        h.date_day,
        h.hour_of_day,
        h.departures
    from marts.fct_station_hourly h
    join top_stations using (station_id)

),

lagged as (

    select
        *,
        lag(departures, 24)  over w as lag_24h,
        lag(departures, 48)  over w as lag_48h,
        lag(departures, 168) over w as lag_168h,
        lag(departures, 336) over w as lag_336h,
        -- Mean of the same hour over the previous 7 days (rows 24h apart).
        (lag(departures, 24) over w + lag(departures, 48) over w + lag(departures, 72) over w
         + lag(departures, 96) over w + lag(departures, 120) over w + lag(departures, 144) over w
         + lag(departures, 168) over w) / 7.0 as same_hour_7d_mean,
        -- Yesterday's total volume at the station.
        sum(departures) over (partition by station_id order by hour_ts
                              rows between 47 preceding and 24 preceding) as prev_day_total
    from base
    window w as (partition by station_id order by hour_ts)

)

select
    l.station_id,
    l.hour_ts,
    l.date_day,
    l.departures                                as target,
    l.hour_of_day,
    d.day_of_week,
    d.month,
    d.is_workday::int                           as is_workday,
    d.is_holiday::int                           as is_holiday,
    s.latitude,
    s.longitude,
    s.borough,
    w.temp_avg_f,
    w.temp_max_f,
    w.precip_in,
    w.snowfall_in,
    w.snow_depth_in,
    w.avg_wind_mph,
    l.lag_24h,
    l.lag_48h,
    l.lag_168h,
    l.lag_336h,
    l.same_hour_7d_mean,
    l.prev_day_total
from lagged l
join marts.dim_date d using (date_day)
join marts.dim_stations s using (station_id)
left join marts.dim_weather w on w.weather_date = l.date_day
-- Drop the first two weeks per station, where the longest lag is undefined.
where l.lag_336h is not null
