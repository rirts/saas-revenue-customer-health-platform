{{ config(tags=['business_logic', 'data_contract']) }}

select
    customer_health_segment,
    revenue_tier,
    support_burden_level,
    open_ticket_account_rate,
    critical_ticket_account_rate,
    support_risk_account_rate
from {{ ref('mart_support_operations') }}
where open_ticket_account_rate < 0
   or open_ticket_account_rate > 1
   or critical_ticket_account_rate < 0
   or critical_ticket_account_rate > 1
   or support_risk_account_rate < 0
   or support_risk_account_rate > 1