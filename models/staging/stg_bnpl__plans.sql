-- One row per BNPL plan/credit. Grain: plan_id.
-- Staging: rename, case, per-row derivation only. No joins, no aggregation.

with source as (
    select * from {{ source('bnpl', 'raw_plans') }}
),

renamed as (
    select
        plan_id,
        customer_id,
        merchant_id,

        -- Basket and deposit amounts converted to GBP
        (basket_amount_pence / 100)::decimal(12, 2) as basket_amount_gbp,
        (deposit_amount_pence / 100)::decimal(12, 2) as deposit_amount_gbp,

        -- Financed amount = basket - deposit. It's the amount actually at risk.
        -- Confusing it with basket amount overstates the book
        ((basket_amount_pence - deposit_amount_pence) / 100)::decimal(12, 2) as financed_amount_gbp,

        term_months,
        created_at,

        -- Cohort month extracted from created_at cased specifically as date
        date_trunc('month', created_at)::date as cohort_month
    from source
)

select * from renamed