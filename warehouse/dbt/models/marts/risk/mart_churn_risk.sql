with account_360 as (

    select *
    from {{ ref('mart_account_360') }}

),

risk_accounts as (

    select *
    from account_360
    where is_churn_risk

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
        account_status_group,
        customer_health_segment,
        account_priority_action,
        revenue_tier,

        customer_health_score,
        raw_customer_health_score,

        current_mrr_usd,
        mrr_at_risk_usd,

        usage_intensity,
        total_events,
        active_users,
        active_days,
        adopted_feature_count,
        low_usage_paid_account,

        support_burden_level,
        total_tickets,
        open_tickets,
        high_priority_tickets,
        critical_tickets,
        has_open_tickets,
        has_critical_ticket,
        support_risk_flag,

        has_overdue_invoice,
        total_outstanding_usd,
        avg_collection_rate,
        avg_days_to_payment,
        payment_risk_flag,

        case
            when account_lifecycle_stage = 'churned_customer'
                then 'churned_customer'
            when has_overdue_invoice
                then 'overdue_invoice'
            when has_critical_ticket
                then 'critical_support_ticket'
            when payment_risk_flag
                then 'payment_risk'
            when support_risk_flag
                then 'support_risk'
            when low_usage_paid_account
                then 'low_product_usage'
            else 'general_risk'
        end as primary_risk_reason,

        case
            when account_lifecycle_stage = 'churned_customer'
                then 'closed_loss_or_churn_review'
            when has_overdue_invoice
                then 'finance_collection_and_cs_outreach'
            when has_critical_ticket
                then 'support_escalation'
            when payment_risk_flag
                then 'payment_follow_up'
            when support_risk_flag
                then 'support_follow_up'
            when low_usage_paid_account
                then 'adoption_intervention'
            else 'manual_review'
        end as recommended_risk_playbook,

        case
            when not is_current_customer and account_lifecycle_stage = 'churned_customer' then 'P5'
            when customer_health_segment = 'critical' and current_mrr_usd >= 5000 then 'P1'
            when customer_health_segment = 'critical' then 'P2'
            when customer_health_segment = 'at_risk' and current_mrr_usd >= 5000 then 'P2'
            when customer_health_segment = 'at_risk' then 'P3'
            when customer_health_segment = 'watch' and current_mrr_usd >= 10000 then 'P3'
            when customer_health_segment = 'watch' then 'P4'
            else 'P5'
        end as risk_priority,

        case
            when customer_health_segment = 'critical' and is_current_customer then 1
            when customer_health_segment = 'at_risk' and current_mrr_usd >= 5000 then 2
            when customer_health_segment = 'at_risk' then 3
            when customer_health_segment = 'watch' and current_mrr_usd >= 10000 then 4
            when customer_health_segment = 'watch' then 5
            when not is_current_customer and account_lifecycle_stage = 'churned_customer' then 6
            else 7
        end as risk_priority_rank

    from risk_accounts

)

select *
from final
