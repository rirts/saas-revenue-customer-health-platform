with account_base as (

    select *
    from {{ ref('int_customer__account_base') }}

),

subscriptions as (

    select *
    from {{ ref('int_revenue__subscriptions_enriched') }}

),

product_usage as (

    select *
    from {{ ref('int_product__account_usage') }}

),

support_summary as (

    select *
    from {{ ref('int_support__account_ticket_summary') }}

),

subscription_aggregated as (

    select
        account_id,

        count(*) as subscription_count,
        count(*) filter (where is_active) as active_subscription_count,
        count(*) filter (where is_past_due) as past_due_subscription_count,
        count(*) filter (where is_canceled) as canceled_subscription_count,

        sum(current_mrr_usd)::numeric(18, 2) as current_mrr_usd,
        sum(total_invoiced_usd)::numeric(18, 2) as total_invoiced_usd,
        sum(total_paid_usd)::numeric(18, 2) as total_paid_usd,
        sum(total_outstanding_usd)::numeric(18, 2) as total_outstanding_usd,

        max(latest_invoice_date) as latest_invoice_date,
        max(latest_payment_date) as latest_payment_date,

        max(case when has_overdue_invoice then 1 else 0 end) = 1 as has_overdue_invoice,

        round(avg(collection_rate)::numeric, 4) as avg_collection_rate,
        round(avg(avg_days_to_payment)::numeric, 2) as avg_days_to_payment

    from subscriptions
    group by account_id

),

signals as (

    select
        account_base.account_id,
        account_base.account_name,
        account_base.industry,
        account_base.segment,
        account_base.employee_band,
        account_base.country,
        account_base.account_owner,
        account_base.account_lifecycle_stage,

        account_base.contact_count,
        account_base.executive_sponsor_count,
        account_base.admin_contact_count,

        coalesce(subscription_aggregated.subscription_count, 0) as subscription_count,
        coalesce(subscription_aggregated.active_subscription_count, 0) as active_subscription_count,
        coalesce(subscription_aggregated.past_due_subscription_count, 0) as past_due_subscription_count,
        coalesce(subscription_aggregated.canceled_subscription_count, 0) as canceled_subscription_count,

        coalesce(subscription_aggregated.current_mrr_usd, 0)::numeric(18, 2) as current_mrr_usd,
        coalesce(subscription_aggregated.total_invoiced_usd, 0)::numeric(18, 2) as total_invoiced_usd,
        coalesce(subscription_aggregated.total_paid_usd, 0)::numeric(18, 2) as total_paid_usd,
        coalesce(subscription_aggregated.total_outstanding_usd, 0)::numeric(18, 2) as total_outstanding_usd,

        subscription_aggregated.latest_invoice_date,
        subscription_aggregated.latest_payment_date,
        coalesce(subscription_aggregated.has_overdue_invoice, false) as has_overdue_invoice,
        coalesce(subscription_aggregated.avg_collection_rate, 0) as avg_collection_rate,
        subscription_aggregated.avg_days_to_payment,

        coalesce(product_usage.total_events, 0) as total_events,
        coalesce(product_usage.active_users, 0) as active_users,
        coalesce(product_usage.active_days, 0) as active_days,
        product_usage.first_event_date,
        product_usage.latest_event_date,
        coalesce(product_usage.adopted_feature_count, 0) as adopted_feature_count,
        coalesce(product_usage.usage_intensity, 'no_usage') as usage_intensity,
        coalesce(product_usage.has_connected_integration, false) as has_connected_integration,
        coalesce(product_usage.has_created_report, false) as has_created_report,

        coalesce(support_summary.total_tickets, 0) as total_tickets,
        coalesce(support_summary.open_tickets, 0) as open_tickets,
        coalesce(support_summary.resolved_tickets, 0) as resolved_tickets,
        coalesce(support_summary.high_priority_tickets, 0) as high_priority_tickets,
        coalesce(support_summary.critical_tickets, 0) as critical_tickets,
        support_summary.latest_ticket_date,
        support_summary.avg_resolution_days,
        coalesce(support_summary.support_burden_level, 'no_burden') as support_burden_level,
        coalesce(support_summary.has_open_tickets, false) as has_open_tickets,
        coalesce(support_summary.has_critical_ticket, false) as has_critical_ticket,

        case
            when
                coalesce(subscription_aggregated.current_mrr_usd, 0) > 0
                or coalesce(subscription_aggregated.active_subscription_count, 0) > 0
                or coalesce(subscription_aggregated.past_due_subscription_count, 0) > 0
                then true
            else false
        end as is_current_customer

    from account_base
    left join subscription_aggregated
        on account_base.account_id = subscription_aggregated.account_id
    left join product_usage
        on account_base.account_id = product_usage.account_id
    left join support_summary
        on account_base.account_id = support_summary.account_id

),

risk_flags as (

    select
        *,

        case
            when
                is_current_customer
                and usage_intensity in ('no_usage', 'low_usage')
                then true
            else false
        end as low_usage_paid_account,

        case
            when has_overdue_invoice then true
            when past_due_subscription_count > 0 then true
            when total_invoiced_usd > 0 and avg_collection_rate < 0.90 then true
            else false
        end as payment_risk_flag,

        case
            when has_critical_ticket then true
            when high_priority_tickets >= 3 then true
            when open_tickets >= 3 then true
            else false
        end as support_risk_flag

    from signals

),

component_scores as (

    select
        *,

        case
            when usage_intensity = 'high_usage' then 35
            when usage_intensity = 'medium_usage' then 25
            when usage_intensity = 'low_usage' then 8
            else 0
        end as usage_score,

        case
            when adopted_feature_count >= 5 then 20
            when adopted_feature_count >= 3 then 12
            when adopted_feature_count >= 1 then 5
            else 0
        end as adoption_score,

        case
            when not is_current_customer then 0
            when has_overdue_invoice then 0
            when past_due_subscription_count > 0 then 5
            when total_invoiced_usd = 0 then 18
            when avg_collection_rate >= 0.98 then 25
            when avg_collection_rate >= 0.90 then 18
            when avg_collection_rate >= 0.75 then 10
            when avg_collection_rate > 0 then 5
            else 0
        end as payment_score,

        case
            when has_critical_ticket then 0
            when high_priority_tickets >= 3 then 3
            when open_tickets >= 3 then 6
            when support_burden_level = 'high_burden' then 8
            when support_burden_level = 'medium_burden' then 11
            else 15
        end as support_score,

        case
            when executive_sponsor_count > 0 and admin_contact_count > 0 then 5
            when executive_sponsor_count > 0 or admin_contact_count > 0 then 3
            when contact_count > 0 then 1
            else 0
        end as relationship_score

    from risk_flags

),

raw_scored as (

    select
        *,

        (
            usage_score
            + adoption_score
            + payment_score
            + support_score
            + relationship_score
        ) as raw_customer_health_score

    from component_scores

),

risk_adjusted as (

    select
        *,

        case
            when
                not is_current_customer
                and account_lifecycle_stage in ('prospect', 'won_not_subscribed')
                then raw_customer_health_score

            when account_lifecycle_stage = 'churned_customer'
                then least(raw_customer_health_score, 20)

            when has_critical_ticket or has_overdue_invoice
                then least(raw_customer_health_score, 49)

            when payment_risk_flag or support_risk_flag or low_usage_paid_account
                then least(raw_customer_health_score, 64)

            else raw_customer_health_score
        end as customer_health_score

    from raw_scored

),

segmented as (

    select
        *,

        case
            when
                not is_current_customer
                and account_lifecycle_stage in ('prospect', 'won_not_subscribed')
                then 'not_customer'

            when account_lifecycle_stage = 'churned_customer'
                then 'critical'

            when customer_health_score >= 80
                then 'healthy'

            when customer_health_score >= 60
                then 'watch'

            when customer_health_score >= 35
                then 'at_risk'

            else 'critical'
        end as customer_health_segment,

        case
            when
                not is_current_customer
                and account_lifecycle_stage in ('prospect', 'won_not_subscribed')
                then false

            when account_lifecycle_stage = 'churned_customer'
                then true

            when payment_risk_flag then true
            when support_risk_flag then true
            when low_usage_paid_account then true

            else false
        end as is_churn_risk

    from risk_adjusted

)

select *
from segmented
