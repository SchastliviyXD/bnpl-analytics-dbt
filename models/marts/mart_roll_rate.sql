-- One row per month per bucket transition. Grain: (snapshot_date, from_bucket, to_bucket).
-- Logic: roll rate is the flow between delinquency buckets month over month -
-- the leading indicator NPL lags by roughly 90 days.

-- 'Settled' is a terminal bucket: plans that fully repay appear as a destination
-- (a cure), never as an origin.

with transitions as (
    -- Each plan-month paired with the bucket it was in the PREVIOUS month.
    -- lag() partitioned by plan means the comparison is always same-plan,
    -- consecutive months.
    select
        snapshot_date,
        plan_id, 
        outstanding_gbp,
        lag(dpd_bucket) over (
            partition by plan_id
            order by snapshot_date
        ) as from_bucket,
        dpd_bucket as to_bucket
    from {{ref('int_plan_bucket_monthly')}}
),

counted as (
    select
        snapshot_date,
        from_bucket,
        to_bucket,
        count(*) as plans,
        sum(outstanding_gbp) as outstanding_gbp
    from transitions
    where from_bucket is not null
    group by snapshot_date, from_bucket, to_bucket
)

select
    snapshot_date,
    from_bucket,
    to_bucket,
    plans,
    outstanding_gbp,
    plans / sum(plans) over (partition by snapshot_date, from_bucket) as roll_rate
from counted