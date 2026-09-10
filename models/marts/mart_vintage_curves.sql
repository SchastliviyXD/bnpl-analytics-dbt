-- One row per cohort-month x months-on-book. Grain: (cohort_month, months_on_book).
-- Logic: Cumulative 90+ default rate by loan age, so cohorts of
-- different ages are compared at the same point in their life.

with first_defaults as (
    -- The earliest date each plan hit 90+ DPD. An instalment is 90+ at date D
    -- if it is still unpaid and D is 90+ days past its due date — so the plan's
    -- first default date is (earliest unpaid due_date) + 90 days.
    select
        plan_id,
        min(due_date) + 90 as first_default_date
    from {{ ref('stg_bnpl__installments')}}
    where not is_paid and days_past_due >= 90
    group by plan_id
),

plan_base as (
    -- One row per plan: it's cohor, its principal, and how many months into its
    -- life it defaulted (null if it never did)
    select
        p.plan_id,
        p.cohort_month,
        p.financed_amount_gbp,
        date_diff('month', fd.first_default_date, p.cohort_month) as default_mob
    from {{ ref('stg_bnpl__plans')}} p
    left join first_defaults fd using (plan_id)
),

cohort_maturity as (
    -- How many months each cohort has actually been observable. This is the
    -- maturity filter: a cohort cannot report an MOB it has not lived through.
    select
        cohort_month,
        count(*) as plans,
        sum(financed_amount_gbp) as cohort_principal_gbp,
        date_diff('month', cohort_month, {{ reporting_date() }}) as max_observable_mob
    from plan_base
    group by cohort_month
),

mob_spine as (
    select
        cm.cohort_month,
        cm.cohort_principal_gbp,
        s.mob
    from cohort_maturity cm
    cross join generate_series(0, 24) as s(mob)
    where s.mob <= cm.max_observable_mob
)

select
    sp.cohort_month,
    sp.mob as months_on_book,
    sp.cohort_principal_gbp,
    coalesce(sum(pb.financed_amount_gbp), 0) as defaulted_principal_gbp,
    coalesce(sum(pb.financed_amount_gbp), 0) / sp.cohort_principal_gbp as cum_default_rate
from mob_spine as sp
left join plan_base pb
    on pb.cohort_month = sp.cohort_month
    and pb.default_mob <= sp.mob
group by sp.cohort_month, sp.mob, sp.cohort_principal_gbp
order by sp.cohort_month, sp.mob
    