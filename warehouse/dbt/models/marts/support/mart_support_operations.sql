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
        support_burden_level,

        count(*) as customer_count,
        count(*) filter (where is_churn_risk) as churn_risk_customer_count,

        sum(current_mrr_usd)::numeric(18, 2) as current_mrr_usd,
        sum(mrr_at_risk_usd)::numeric(18, 2) as mrr_at_risk_usd,

        sum(total_tickets) as total_tickets,
        sum(open_tickets) as open_tickets,
        sum(high_priority_tickets) as high_priority_tickets,
        sum(critical_tickets) as critical_tickets,

        count(*) filter (where has_open_tickets) as accounts_with_open_tickets,
        count(*) filter (where has_critical_ticket) as accounts_with_critical_ticket,
        count(*) filter (where support_risk_flag) as support_risk_accounts,

        round(avg(total_tickets)::numeric, 2) as avg_tickets_per_account,
        round(avg(open_tickets)::numeric, 2) as avg_open_tickets_per_account,
        round(avg(high_priority_tickets)::numeric, 2) as avg_high_priority_tickets_per_account,
        round(avg(critical_tickets)::numeric, 2) as avg_critical_tickets_per_account,
        round(avg(customer_health_score)::numeric, 2) as avg_customer_health_score,

        case
            when count(*) = 0 then 0
            else round(
                (
                    count(*) filter (where has_open_tickets)::numeric
                    / nullif(count(*), 0)
                ),
                4
            )
        end as open_ticket_account_rate,

        case
            when count(*) = 0 then 0
            else round(
                (
                    count(*) filter (where has_critical_ticket)::numeric
                    / nullif(count(*), 0)
                ),
                4
            )
        end as critical_ticket_account_rate,

        case
            when count(*) = 0 then 0
            else round(
                (
                    count(*) filter (where support_risk_flag)::numeric
                    / nullif(count(*), 0)
                ),
                4
            )
        end as support_risk_account_rate

    from customer_accounts
    group by
        customer_health_segment,
        revenue_tier,
        support_burden_level

)

select *
from final
