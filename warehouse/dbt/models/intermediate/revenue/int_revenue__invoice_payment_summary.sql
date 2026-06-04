with invoices as (

    select *
    from {{ ref('stg_billing__invoices') }}

),

payments as (

    select *
    from {{ ref('stg_billing__payments') }}

),

payments_aggregated as (

    select
        invoice_id,
        count(*) as payment_count,
        sum(amount_paid_usd) as total_paid_usd,
        min(payment_date) as first_payment_date,
        max(payment_date) as latest_payment_date
    from payments
    group by invoice_id

),

final as (

    select
        invoices.invoice_id,
        invoices.subscription_id,
        invoices.billing_customer_id,
        invoices.account_id,
        invoices.invoice_date,
        invoices.due_date,
        invoices.amount_due_usd,
        invoices.invoice_status,
        invoices.is_paid,
        invoices.is_open,

        coalesce(payments_aggregated.payment_count, 0) as payment_count,
        coalesce(payments_aggregated.total_paid_usd, 0)::numeric(18, 2) as total_paid_usd,
        payments_aggregated.first_payment_date,
        payments_aggregated.latest_payment_date,

        (invoices.amount_due_usd - coalesce(payments_aggregated.total_paid_usd, 0))::numeric(18, 2) as outstanding_amount_usd,

        case
            when coalesce(payments_aggregated.total_paid_usd, 0) >= invoices.amount_due_usd then true
            else false
        end as is_fully_paid,

        case
            when payments_aggregated.first_payment_date is not null
                then payments_aggregated.first_payment_date - invoices.invoice_date
            else null
        end as days_to_payment,

        case
            when invoices.is_open and invoices.due_date < current_date then true
            else false
        end as is_overdue

    from invoices
    left join payments_aggregated
        on invoices.invoice_id = payments_aggregated.invoice_id

)

select *
from final
