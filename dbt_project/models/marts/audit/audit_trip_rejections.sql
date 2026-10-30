-- Data-quality ledger: how many raw rows each rule rejected, per month.

select
    _source_month                                       as source_month,
    coalesce(dq_issue, 'accepted')                      as outcome,
    count(*)                                            as row_count,
    round(100.0 * count(*) / sum(count(*)) over (partition by _source_month), 3) as pct_of_month
from {{ ref('base_citibike__trips_typed') }}
group by 1, 2
order by source_month, row_count desc
