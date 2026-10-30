{{ config(materialized='ephemeral') }}

-- Cast every raw VARCHAR to its real type and label (but don't drop) bad rows.
-- stg_citibike__trips keeps the clean rows; audit_trip_rejections counts the rest.

with source as (

    select * from {{ source('citibike', 'trips') }}

),

typed as (

    select
        nullif(trim(ride_id), '')                         as ride_id,
        nullif(lower(trim(rideable_type)), '')            as rideable_type,
        try_cast(started_at as timestamp)                 as started_at,
        try_cast(ended_at as timestamp)                   as ended_at,
        nullif(trim(start_station_id), '')                as start_station_id,
        nullif(trim(start_station_name), '')              as start_station_name,
        nullif(trim(end_station_id), '')                  as end_station_id,
        nullif(trim(end_station_name), '')                as end_station_name,
        try_cast(start_lat as double)                     as start_lat,
        try_cast(start_lng as double)                     as start_lng,
        try_cast(end_lat as double)                       as end_lat,
        try_cast(end_lng as double)                       as end_lng,
        -- Pre-2021 files said Subscriber/Customer; current files say member/casual.
        case lower(trim(member_casual))
            when 'subscriber' then 'member'
            when 'customer'   then 'casual'
            else lower(trim(member_casual))
        end                                               as rider_type,
        _source_month,
        _source_file,
        _ingested_at
    from source

)

select
    *,
    date_diff('second', started_at, ended_at) as duration_seconds,
    case
        when started_at is null or ended_at is null          then 'unparseable_timestamp'
        when ended_at <= started_at                           then 'non_positive_duration'
        when date_diff('second', started_at, ended_at) > 86400 then 'over_24_hours'
        when rider_type not in ('member', 'casual')           then 'unknown_rider_type'
        -- Coordinates outside the NYC/NJ service area are GPS glitches.
        when start_lat not between 40.4 and 41.0
          or start_lng not between -74.3 and -73.6            then 'start_outside_service_area'
        when end_lat not between 40.4 and 41.0
          or end_lng not between -74.3 and -73.6              then 'end_outside_service_area'
    end as dq_issue
from typed
