{{ config(tags=['business_logic']) }}

select
    account_id,
    account_name,
    customer_health_segment,
    is_churn_risk,
    customer_health_score
from {{ ref('mart_account_360') }}
where
    customer_health_segment = 'healthy'
    and is_churn_risk
