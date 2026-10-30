{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='source_month'
    )
}}

-- One row per valid trip. Bad rows are excluded here and counted in
-- audit_trip_rejections, so nothing disappears silently.
--
-- Materialized (not a view) because every downstream model and test would
-- otherwise re-parse ~4M raw rows per month. Incremental by source month:
-- a monthly run only types and cleans the newly landed file.

with typed as (

    select * from {{ ref('base_citibike__trips_typed') }}
    {% if is_incremental() %}
    where _source_month >= (select max(source_month) from {{ this }})
       or _source_month not in (select distinct source_month from {{ this }})
    {% endif %}

),

clean as (

    select
        -- Legacy files have no ride_id; derive a stable surrogate for those rows.
        coalesce(
            ride_id,
            md5(concat_ws('|', started_at, ended_at, start_station_id, end_station_id, start_lat, start_lng))
        )                                       as trip_id,
        rideable_type,
        rider_type,
        started_at,
        ended_at,
        duration_seconds,
        start_station_id,
        start_station_name,
        end_station_id,
        end_station_name,
        start_lat,
        start_lng,
        end_lat,
        end_lng,
        _source_month                           as source_month,
        _ingested_at                            as ingested_at
    from typed
    where dq_issue is null

),

-- A ride can appear in two monthly files when it spans midnight on the 1st.
-- Only a few hundred ids repeat, so find them with a cheap hash aggregate and
-- run the row_number() dedup on just those, instead of windowing every row.
repeated_ids as (

    select trip_id from clean group by trip_id having count(*) > 1

),

deduped as (

    select * from clean
    where trip_id not in (select trip_id from repeated_ids)

    union all

    select * from clean
    where trip_id in (select trip_id from repeated_ids)
    qualify row_number() over (partition by trip_id order by source_month, ingested_at desc) = 1

)

select * from deduped
{% if is_incremental() %}
-- Skip ids already loaded from an earlier month.
where trip_id not in (
    select trip_id from {{ this }}
    where source_month < (select min(source_month) from clean)
)
{% endif %}
