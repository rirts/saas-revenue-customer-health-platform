with account_360 as (

    select *
    from {{ ref('mart_account_360') }}

),

customer_accounts as (

    select *
    from account_360
    where is_current_customer

),

final as (

    select
        customer_health_segment,
        revenue_tier,
        usage_intensity,

        count(*) as customer_count,
        count(*) filter (where is_churn_risk) as churn_risk_customer_count,

        sum(current_mrr_usd)::numeric(18, 2) as current_mrr_usd,
        sum(mrr_at_risk_usd)::numeric(18, 2) as mrr_at_risk_usd,

        sum(total_events) as total_events,
        sum(active_users) as active_users,
        sum(active_days) as active_days,

        round(avg(total_events)::numeric, 2) as avg_events_per_account,
        round(avg(active_users)::numeric, 2) as avg_active_users,
        round(avg(active_days)::numeric, 2) as avg_active_days,
        round(avg(adopted_feature_count)::numeric, 2) as avg_adopted_feature_count,
        round(avg(customer_health_score)::numeric, 2) as avg_customer_health_score,

        count(*) filter (where has_connected_integration) as accounts_with_integration,
        count(*) filter (where has_created_report) as accounts_with_created_report,
        count(*) filter (where low_usage_paid_account) as low_usage_paid_accounts,

        case
            when count(*) = 0 then 0
            else round(
                (
                    count(*) filter (where has_connected_integration)::numeric
                    / nullif(count(*), 0)
                ),
                4
            )
        end as integration_adoption_rate,

        case
            when count(*) = 0 then 0
            else round(
                (
                    count(*) filter (where has_created_report)::numeric
                    / nullif(count(*), 0)
                ),
                4
            )
        end as report_creation_rate,

        case
            when count(*) = 0 then 0
            else round(
                (
                    count(*) filter (where low_usage_paid_account)::numeric
                    / nullif(count(*), 0)
                ),
                4
            )
        end as low_usage_paid_account_rate

    from customer_accounts
    group by
        customer_health_segment,
        revenue_tier,
        usage_intensity

)

select *
from final