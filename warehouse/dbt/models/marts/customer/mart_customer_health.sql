with health_signals as (

    select *
    from {{ ref('int_customer__health_signals') }}

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

        is_current_customer,
        customer_health_segment,
        is_churn_risk,

        raw_customer_health_score,
        customer_health_score,

        usage_score,
        adoption_score,
        payment_score,
        support_score,
        relationship_score,

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
            when customer_health_segment = 'healthy' then 'Maintain and expand'
            when customer_health_segment = 'watch' then 'Monitor and drive adoption'
            when customer_health_segment = 'at_risk' then 'Prioritize intervention'
            when customer_health_segment = 'critical' then 'Escalate immediately'
            when customer_health_segment = 'not_customer' then 'Exclude from customer health motion'
            else 'Review'
        end as recommended_action,

        case
            when customer_health_segment = 'critical' then 1
            when customer_health_segment = 'at_risk' then 2
            when customer_health_segment = 'watch' then 3
            when customer_health_segment = 'healthy' then 4
            else 5
        end as health_priority_rank

    from health_signals

)

select *
from final
