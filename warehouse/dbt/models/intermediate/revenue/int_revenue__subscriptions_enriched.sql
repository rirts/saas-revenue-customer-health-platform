with subscriptions as (

    select *
    from {{ ref('stg_billing__subscriptions') }}

),

accounts as (

    select *
    from {{ ref('stg_crm__accounts') }}

),

invoice_payment_summary as (

    select *
    from {{ ref('int_revenue__invoice_payment_summary') }}

),

invoice_aggregated as (

    select
        subscription_id,
        count(*) as invoice_count,
        count(*) filter (where is_fully_paid) as paid_invoice_count,
        count(*) filter (where is_open) as open_invoice_count,
        count(*) filter (where is_overdue) as overdue_invoice_count,
        sum(amount_due_usd) as total_invoiced_usd,
        sum(total_paid_usd) as total_paid_usd,
        sum(outstanding_amount_usd) as total_outstanding_usd,
        min(invoice_date) as first_invoice_date,
        max(invoice_date) as latest_invoice_date,
        max(latest_payment_date) as latest_payment_date,
        avg(days_to_payment) filter (where days_to_payment is not null) as avg_days_to_payment
    from invoice_payment_summary
    group by subscription_id

),

final as (

    select
        subscriptions.subscription_id,
        subscriptions.billing_customer_id,
        subscriptions.account_id,

        accounts.account_name,
        accounts.industry,
        accounts.segment,
        accounts.country,

        subscriptions.plan,
        subscriptions.subscription_status,
        subscriptions.billing_cycle,
        subscriptions.mrr_usd,
        subscriptions.arr_usd,
        subscriptions.start_date,
        subscriptions.canceled_at,
        subscriptions.is_active,
        subscriptions.is_canceled,
        subscriptions.is_past_due,

        coalesce(invoice_aggregated.invoice_count, 0) as invoice_count,
        coalesce(invoice_aggregated.paid_invoice_count, 0) as paid_invoice_count,
        coalesce(invoice_aggregated.open_invoice_count, 0) as open_invoice_count,
        coalesce(invoice_aggregated.overdue_invoice_count, 0) as overdue_invoice_count,
        coalesce(invoice_aggregated.total_invoiced_usd, 0)::numeric(18, 2) as total_invoiced_usd,
        coalesce(invoice_aggregated.total_paid_usd, 0)::numeric(18, 2) as total_paid_usd,
        coalesce(invoice_aggregated.total_outstanding_usd, 0)::numeric(18, 2) as total_outstanding_usd,
        invoice_aggregated.first_invoice_date,
        invoice_aggregated.latest_invoice_date,
        invoice_aggregated.latest_payment_date,
        round(invoice_aggregated.avg_days_to_payment::numeric, 2) as avg_days_to_payment,

        case
            when coalesce(invoice_aggregated.total_invoiced_usd, 0) = 0 then 0
            else round(
                (
                    coalesce(invoice_aggregated.total_paid_usd, 0)
                    / nullif(invoice_aggregated.total_invoiced_usd, 0)
                )::numeric,
                4
            )
        end as collection_rate,

        case
            when subscriptions.is_active then subscriptions.mrr_usd
            when subscriptions.is_past_due then subscriptions.mrr_usd
            else 0
        end as current_mrr_usd,

        case
            when subscriptions.canceled_at is not null
                then subscriptions.canceled_at - subscriptions.start_date
            else current_date - subscriptions.start_date
        end as subscription_age_days,

        case
            when coalesce(invoice_aggregated.overdue_invoice_count, 0) > 0 then true
            else false
        end as has_overdue_invoice

    from subscriptions
    left join accounts
        on subscriptions.account_id = accounts.account_id
    left join invoice_aggregated
        on subscriptions.subscription_id = invoice_aggregated.subscription_id

)

select *
from final
