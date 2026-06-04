{{ config(tags=['business_logic']) }}

with account_360_totals as (

    select
        round(sum(current_mrr_usd)::numeric, 2) as current_mrr_usd,
        round(sum(mrr_at_risk_usd)::numeric, 2) as mrr_at_risk_usd,
        count(*) as customer_count
    from {{ ref('mart_account_360') }}
    where is_current_customer

),

revenue_retention_totals as (

    select
        round(sum(current_mrr_usd)::numeric, 2) as current_mrr_usd,
        round(sum(mrr_at_risk_usd)::numeric, 2) as mrr_at_risk_usd,
        sum(customer_count) as customer_count
    from {{ ref('mart_revenue_retention') }}

),

validation as (

    select
        account_360_totals.current_mrr_usd as account_360_current_mrr_usd,
        revenue_retention_totals.current_mrr_usd as revenue_retention_current_mrr_usd,

        account_360_totals.mrr_at_risk_usd as account_360_mrr_at_risk_usd,
        revenue_retention_totals.mrr_at_risk_usd as revenue_retention_mrr_at_risk_usd,

        account_360_totals.customer_count as account_360_customer_count,
        revenue_retention_totals.customer_count as revenue_retention_customer_count

    from account_360_totals
    cross join revenue_retention_totals

)

select *
from validation
where
    account_360_current_mrr_usd <> revenue_retention_current_mrr_usd
    or account_360_mrr_at_risk_usd <> revenue_retention_mrr_at_risk_usd
    or account_360_customer_count <> revenue_retention_customer_count
