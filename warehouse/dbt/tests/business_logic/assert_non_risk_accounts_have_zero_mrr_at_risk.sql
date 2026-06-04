{{ config(tags=['business_logic']) }}

select
    account_id,
    account_name,
    customer_health_segment,
    is_churn_risk,
    mrr_at_risk_usd
from {{ ref('mart_account_360') }}
where
    not is_churn_risk
    and mrr_at_risk_usd <> 0
