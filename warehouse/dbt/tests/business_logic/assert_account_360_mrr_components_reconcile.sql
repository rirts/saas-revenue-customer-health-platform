{{ config(tags=['business_logic', 'data_contract']) }}

select
    account_id,
    account_name,
    current_mrr_usd,
    healthy_mrr_usd,
    non_healthy_mrr_usd,
    current_mrr_usd - (healthy_mrr_usd + non_healthy_mrr_usd) as reconciliation_difference
from {{ ref('mart_account_360') }}
where abs(current_mrr_usd - (healthy_mrr_usd + non_healthy_mrr_usd)) > 0.01
