with source as (

    select *
    from {{ source('raw', 'billing_customers') }}

),

renamed as (

    select
        billing_customer_id::text as billing_customer_id,
        account_id::text as account_id,
        customer_name::text as customer_name,
        created_at::date as created_at,
        country::text as country
    from source

)

select *
from renamed
