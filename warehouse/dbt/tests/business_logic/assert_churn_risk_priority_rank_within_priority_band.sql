{{ config(tags=['business_logic', 'data_contract']) }}

select
    account_id,
    account_name,
    risk_priority,
    risk_priority_rank,
    current_mrr_usd,
    mrr_at_risk_usd,
    primary_risk_reason
from {{ ref('mart_churn_risk') }}
where (
    risk_priority = 'P1'
    and risk_priority_rank not in (1)
)
or (
    risk_priority = 'P2'
    and risk_priority_rank not in (1, 2)
)
or (
    risk_priority = 'P3'
    and risk_priority_rank not in (3, 4)
)
or (
    risk_priority = 'P4'
    and risk_priority_rank not in (5)
)
or (
    risk_priority = 'P5'
    and risk_priority_rank not in (6)
)
or risk_priority_rank is null
