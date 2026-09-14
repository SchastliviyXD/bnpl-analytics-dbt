-- One row per plan per month-end. Grain: (plan_id, snapshot_date).
-- Intermediate: reconstructs the delinquency history that no snapshot table captured,
-- by asking "what was true as at date D" for each month-end.

with month_ends as (
    -- Every month-end from the first origination to the reporting date.
    select unnest(generate_series(
        date_trunc('month', (select min(contract_date) from {{ ref('stg_bnpl__plans')}})),
        {{ reporting_date() }},
        interval 1 month
    ))::date as snapshot_date
),

plan_months as (
    -- Each plan paired with every month-end on or after its origination.
    -- A plan does not exist before it was written.
    select
        p.plan_id,
        m.snapshot_date
    from {{ ref('stg_bnpl__plans') }} p
    cross join month_ends m
    where m.snapshot_date >= p.contract_date
),

as_at as (
    -- Point-in-time: what was true at snapshot_date, using only information
    -- available then. `paid_date > snapshot_date` is essential - an instalment
    -- settled later was still unpaid back then. Using `paid_date is null` alone
    -- would leak today's knowledge into the past.
    select
        pm.plan_id,
        pm.snapshot_date,
        max(case
                when i.due_date <= pm.snapshot_date
                and (i.paid_date is null or i.paid_date > pm.snapshot_date)
                then pm.snapshot_date - i.due_date
            end) as dpd,
        coalesce(sum(case
                when i.paid_date is null or i.paid_date > pm.snapshot_date
                then i.amount_gbp
            end), 0) as outstanding_gbp
    from plan_months pm
    join {{ ref('stg_bnpl__installments') }} i using (plan_id)
    group by pm.plan_id, pm.snapshot_date
)

select
    plan_id,
    snapshot_date,
    dpd,
    outstanding_gbp,
    case    
        when outstanding_gbp = 0 then 'Settled'
        when dpd <= 0 or dpd is null then 'Current'
        when dpd between 1 and 29 then '1-29'
        when dpd between 30 and 59 then '30-59'
        when dpd between 60 and 89 then '60-89'
        when dpd >= 90 then '90+'
    end as dpd_bucket
from as_at
qualify outstanding_gbp > 0
    or lag(outstanding_gbp) over (partition by plan_id order by snapshot_date) > 0