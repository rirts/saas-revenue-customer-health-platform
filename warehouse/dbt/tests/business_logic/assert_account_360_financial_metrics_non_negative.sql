{{ config(tags=['business_logic', 'data_contract']) }}

select
    account_id,
    account_name,
    current_mrr_usd,
    healthy_mrr_usd,
    non_healthy_mrr_usd,
    mrr_at_risk_usd
from {{ ref('mart_account_360') }}
where
    current_mrr_usd < 0
    or healthy_mrr_usd < 0
    or non_healthy_mrr_usd < 0
    or mrr_at_risk_usd < 0
