-- One row per merchant. Grain: merchant_id.
-- Staging: rename, case, per-row derivation only. No joins, no aggregation.

with source as (
    select * from {{ source('bnpl', 'raw_merchants') }}
),

renamed as (
    select
        merchant_id,
        merchant_name,
        category,
        city
    from source
)

select * from renamed