-- One row per delinquency bucket. Grain: dpd_bucket
-- ENTIRE remaining balance is at risk, not just its overdue instalment

with plan_delinquency as (
    select
        plan_id,
        max(case when is_due and not is_paid then days_past_due end) as dpd,
        coalesce(sum(case when not is_paid then amount_gbp end), 0) as outstanding_gbp
    from {{ ref('stg_bnpl__installments') }}
    group by plan_id
),

bucketed as (
    select
        plan_id,
        outstanding_gbp,
        case
            when dpd <= 0 or dpd is null then 'Current'
            when dpd between 1 and 29 then '1-29'
            when dpd between 30 and 59 then '30-59'
            when dpd between 60 and 89 then '60-89'
            when dpd >= 90 then '90+'
        end as dpd_bucket
    from plan_delinquency
)

select
    dpd_bucket,
    plans,
    outstanding_gbp,
    plans / sum(plans) over() as pct_of_plans,
    coalesce(outstanding_gbp, 0) / sum(coalesce(outstanding_gbp, 0)) over() as pct_of_outstanding
from (
    select
        dpd_bucket,
        count(*) as plans,
        sum(outstanding_gbp) as outstanding_gbp
    from bucketed
    group by dpd_bucket
) t