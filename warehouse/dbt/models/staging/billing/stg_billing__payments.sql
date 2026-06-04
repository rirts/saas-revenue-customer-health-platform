with source as (

    select *
    from {{ source('raw', 'billing_payments') }}

),

renamed as (

    select
        payment_id::text as payment_id,
        invoice_id::text as invoice_id,
        billing_customer_id::text as billing_customer_id,
        account_id::text as account_id,
        payment_date::date as payment_date,
        amount_paid_usd::numeric(18, 2) as amount_paid_usd,
        payment_method::text as payment_method
    from source

)

select *
from renamed
