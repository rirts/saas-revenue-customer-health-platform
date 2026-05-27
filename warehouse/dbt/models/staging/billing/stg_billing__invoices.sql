with source as (

    select *
    from {{ source('raw', 'billing_invoices') }}

),

renamed as (

    select
        invoice_id::text as invoice_id,
        subscription_id::text as subscription_id,
        billing_customer_id::text as billing_customer_id,
        account_id::text as account_id,
        invoice_date::date as invoice_date,
        due_date::date as due_date,
        amount_due_usd::numeric(18, 2) as amount_due_usd,
        status::text as invoice_status,

        case
            when status = 'paid' then true
            else false
        end as is_paid,

        case
            when status = 'open' then true
            else false
        end as is_open
    from source

)

select *
from renamed