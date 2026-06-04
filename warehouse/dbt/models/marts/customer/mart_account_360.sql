with customer_health as (

    select *
    from {{ ref('mart_customer_health') }}

),

final as (

    select
        account_id,
        account_name,
        industry,
        segment,
        employee_band,
        country,
        account_owner,
        account_lifecycle_stage,

        case
            when is_current_customer then 'Customer'
            when account_lifecycle_stage = 'won_not_subscribed' then 'Won - Not Subscribed'
            when account_lifecycle_stage = 'prospect' then 'Prospect'
            when account_lifecycle_stage = 'churned_customer' then 'Churned Customer'
            else 'Other'
        end as account_status_group,

        is_current_customer,
        customer_health_segment,
        recommended_action,
        health_priority_rank,
        is_churn_risk,

        customer_health_score,
        raw_customer_health_score,

        current_mrr_usd,
        total_invoiced_usd,
        total_paid_usd,
        total_outstanding_usd,
        avg_collection_rate,
        avg_days_to_payment,
        has_overdue_invoice,
        payment_risk_flag,

        total_events,
        active_users,
        active_days,
        adopted_feature_count,
        usage_intensity,
        has_connected_integration,
        has_created_report,
        low_usage_paid_account,

        total_tickets,
        open_tickets,
        high_priority_tickets,
        critical_tickets,
        support_burden_level,
        has_open_tickets,
        has_critical_ticket,
        support_risk_flag,

        contact_count,
        executive_sponsor_count,
        admin_contact_count,

        case
            when is_current_customer and is_churn_risk then current_mrr_usd
            else 0
        end as mrr_at_risk_usd,

        case
            when is_current_customer and customer_health_segment = 'healthy' then current_mrr_usd
            else 0
        end as healthy_mrr_usd,

        case
            when is_current_customer and customer_health_segment in ('watch', 'at_risk', 'critical') then current_mrr_usd
            else 0
        end as non_healthy_mrr_usd,

        case
            when is_current_customer and current_mrr_usd >= 10000 then 'high_value'
            when is_current_customer and current_mrr_usd >= 5000 then 'mid_value'
            when is_current_customer and current_mrr_usd > 0 then 'low_value'
            when not is_current_customer then 'non_customer'
            else 'unknown'
        end as revenue_tier,

        case
            when not is_current_customer and account_lifecycle_stage = 'churned_customer'
                then 'Churned - winback review'
            when not is_current_customer
                then 'No customer action'

            when customer_health_segment = 'critical' and current_mrr_usd >= 5000
                then 'P1 - Executive escalation'
            when customer_health_segment = 'critical'
                then 'P2 - Immediate CS escalation'
            when customer_health_segment = 'at_risk' and current_mrr_usd >= 5000
                then 'P2 - High-value rescue plan'
            when customer_health_segment = 'at_risk'
                then 'P3 - CS intervention'
            when customer_health_segment = 'watch'
                then 'P4 - Adoption playbook'
            when customer_health_segment = 'healthy' and current_mrr_usd >= 5000
                then 'Expansion candidate'
            when customer_health_segment = 'healthy'
                then 'Maintain'
            else 'Review'
        end as account_priority_action

    from customer_health

)

select *
from final
