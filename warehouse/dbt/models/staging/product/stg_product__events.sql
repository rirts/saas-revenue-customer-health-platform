with source as (

    select *
    from {{ source('raw', 'product_events') }}

),

renamed as (

    select
        event_id::text as event_id,
        account_id::text as account_id,
        subscription_id::text as subscription_id,
        user_id::text as user_id,
        event_type::text as event_type,
        occurred_at::timestamp as occurred_at,
        occurred_at::date as event_date
    from source

)

select *
from renamed
