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
        account_priority_action,

        count(*) as customer_count,
        count(*) filter (where is_churn_risk) as churn_risk_customer_count,

        sum(current_mrr_usd)::numeric(18, 2) as current_mrr_usd,
        sum(mrr_at_risk_usd)::numeric(18, 2) as mrr_at_risk_usd,
        sum(healthy_mrr_usd)::numeric(18, 2) as healthy_mrr_usd,
        sum(non_healthy_mrr_usd)::numeric(18, 2) as non_healthy_mrr_usd,

        round(avg(customer_health_score)::numeric, 2) as avg_customer_health_score,
        round(avg(raw_customer_health_score)::numeric, 2) as avg_raw_customer_health_score,

        case
            when sum(current_mrr_usd) = 0 then 0
            else round(
                (
                    sum(mrr_at_risk_usd)
                    / nullif(sum(current_mrr_usd), 0)
                )::numeric,
                4
            )
        end as mrr_at_risk_rate,

        case
            when count(*) = 0 then 0
            else round(
                (
                    count(*) filter (where is_churn_risk)::numeric
                    / nullif(count(*), 0)
                ),
                4
            )
        end as customer_risk_rate

    from customer_accounts
    group by
        customer_health_segment,
        revenue_tier,
        account_priority_action

)

select *
from final