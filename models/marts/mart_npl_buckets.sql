-- One row per delinquency bucket. Grain: dpd_bucket
-- ENTIRE remaining balance is at risk, not just its overdue instalment

with latest_snapshot as (
    -- The intermediate already answers "what was true as at dote D", and already
    -- exludes settled plans. 
    select
        dpd_bucket,
        outstanding_gbp
    from {{ ref('int_plan_bucket_monthly')}}
    where snapshot_date = {{ reporting_date()}}
),

by_bucket as (
    select
        dpd_bucket,
        count(*) as plans,
        sum(outstanding_gbp) as outstanding_gbp
    from latest_snapshot
    group by dpd_bucket
)

select
    dpd_bucket,
    plans,
    outstanding_gbp,
    plans / sum(plans) over() as pct_of_plans,
    outstanding_gbp / sum(outstanding_gbp) over() as pct_of_outstanding
from by_bucket