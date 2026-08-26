-- One row per registered customer. Grain: customer_id.
-- Staging: rename, case, per-row derivation only. No joins, no aggregation.

with source as (
    select * from {{ source('bnpl', 'raw_customers')}}
),

renamed as (
    select
        customer_id,
        full_name,

        -- Phone is kept as text with "+" inside it
        phone,
        city,
        registered_at,
        
        -- Status is lowercased for convenience and unification
        lower(status) as status
    from source
)

select * from renamed