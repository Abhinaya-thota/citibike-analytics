with locations as (

    select * from {{ ref('int_stations__locations') }}

),

boroughs as (

    select * from {{ ref('int_stations__boroughs') }}

),

data_end as (

    select max(last_seen_date) as max_date from locations

)

select
    l.station_id,
    l.station_name,
    l.latitude,
    l.longitude,
    b.borough,
    b.borough_snapped,
    l.name_variants,
    l.first_seen_date,
    l.last_seen_date,
    -- "Active" relative to the end of the data, not today, so the flag is
    -- stable when the warehouse is rebuilt from history.
    l.last_seen_date >= d.max_date - interval 30 day as is_active,
    l.total_trip_endpoints
from locations l
left join boroughs b using (station_id)
cross join data_end d
