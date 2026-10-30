{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='source_month',
        on_schema_change='append_new_columns'
    )
}}

-- One row per trip. Incremental by source month: each run replaces only the
-- months that are new (or the latest month, in case it was republished).

with trips as (

    select * from {{ ref('stg_citibike__trips') }}
    {% if is_incremental() %}
    where source_month >= (select max(source_month) from {{ this }})
       or source_month not in (select distinct source_month from {{ this }})
    {% endif %}

)

select
    trip_id,
    start_station_id,
    end_station_id,
    started_at::date                                    as start_date,
    hour(started_at)                                    as start_hour,
    started_at,
    ended_at,
    duration_seconds,
    round(duration_seconds / 60.0, 2)                   as duration_minutes,
    rider_type,
    rideable_type,
    start_station_id = end_station_id                   as is_round_trip,
    end_station_id is null                              as is_undocked_end,
    round({{ haversine_km('start_lat', 'start_lng', 'end_lat', 'end_lng') }}, 3) as distance_km,
    source_month
from trips
-- Physically sorting by start time lets DuckDB's row-group min/max zone maps
-- skip most of the table for date-range filters (see analysis/06_*).
order by started_at
