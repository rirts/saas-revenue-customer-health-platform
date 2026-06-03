{{ config(tags=['business_logic', 'data_contract']) }}

select
    customer_health_segment,
    revenue_tier,
    account_priority_action,
    customer_risk_rate,
    mrr_at_risk_rate
from {{ ref('mart_revenue_retention') }}
where customer_risk_rate < 0
   or customer_risk_rate > 1
   or mrr_at_risk_rate < 0
   or mrr_at_risk_rate > 1