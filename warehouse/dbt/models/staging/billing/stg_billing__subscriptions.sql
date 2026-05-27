with source as (

    select *
    from {{ source('raw', 'billing_subscriptions') }}

),

renamed as (

    select
        subscription_id::text as subscription_id,
        billing_customer_id::text as billing_customer_id,
        account_id::text as account_id,
        plan::text as plan,
        status::text as subscription_status,
        billing_cycle::text as billing_cycle,
        mrr_usd::numeric(18, 2) as mrr_usd,
        arr_usd::numeric(18, 2) as arr_usd,
        start_date::date as start_date,
        nullif(canceled_at::text, '')::date as canceled_at,

        case
            when status = 'active' then true
            else false
        end as is_active,

        case
            when status = 'canceled' then true
            else false
        end as is_canceled,

        case
            when status = 'past_due' then true
            else false
        end as is_past_due
    from source

)

select *
from renamed