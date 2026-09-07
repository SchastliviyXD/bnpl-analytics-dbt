-- Reconciliation: every plan's payment schedule must sum to the amount financed.
-- Returns one row per plan that fails. Zero rows = pass.

with schedule_per_plan as (

    -- aggregate the instalments up to plan grain
    select
        plan_id,
        sum(amount_gbp) as scheduled_total_gbp
    from {{ ref('stg_bnpl__installments') }}
    group by plan_id
)

select
    p.plan_id,
    p.financed_amount_gbp,
    s.scheduled_total_gbp,
    p.financed_amount_gbp - s.scheduled_total_gbp as difference_gbp
from {{ ref('stg_bnpl__plans') }} p
join schedule_per_plan s using (plan_id)
where p.financed_amount_gbp <> s.scheduled_total_gbp