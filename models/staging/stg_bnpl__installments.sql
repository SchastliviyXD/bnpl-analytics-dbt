-- One row per scheduled instalment. Grain: installment_id.
-- Staging: rename, case, per-row derivation only. No joins, no aggregation.

with source as (
    select * from {{ source('bnpl', 'raw_installments') }}
),

renamed as (
    select
        installment_id,
        plan_id,

        -- Sequence within the plan. Plan term determines if #1 is a deposit
        -- or a real instalment
        payment_number,
        due_date,
        paid_date,

        -- amounts: the source holds integer pence. Here - converted to gbp,
        -- so no downstream model ever has to remember the unit.
        -- decimal, not float - money must not accumulate binary rounding error.
        (amount_pence / 100.0)::decimal(12, 2) as amount_gbp,

        -- Settled or not. Cheap boolean so downstream models read as English.
        (paid_date is not null) as is_paid,

        -- Days past due, as at the reporting date.
        -- if settled -> how late it actually was (negative = paid early)
        -- if unpaid -> how late it is right now, still accruing
        -- Anything not yet due comes out negative and must be excluded from
        -- delinquency metrics - a not-yet-due instalment is not a missed one.
        case
            when paid_date is not null then paid_date - due_date
            else {{ reporting_date() }} - due_date
        end as days_past_due,

        -- Has this instalment actually fallen due yet? The single most
        -- important flag in the model: NULL paid_date means either MISSED or
        -- NOT YET DUE, and only the first is a risk signal.
        (due_date <= {{ reporting_date() }}) as is_due
    from source
)

select * from renamed