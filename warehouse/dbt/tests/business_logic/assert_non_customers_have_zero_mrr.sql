{{ config(tags=['business_logic']) }}

select
    account_id,
    account_name,
    account_status_group,
    is_current_customer,
    current_mrr_usd
from {{ ref('mart_account_360') }}
where
    not is_current_customer
    and current_mrr_usd <> 0
