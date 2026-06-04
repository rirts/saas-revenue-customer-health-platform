{{ config(tags=['business_logic']) }}

select
    churn_risk.account_id,
    churn_risk.account_name,
    account_360.is_churn_risk
from {{ ref('mart_churn_risk') }} as churn_risk
left join {{ ref('mart_account_360') }} as account_360
    on churn_risk.account_id = account_360.account_id
where
    account_360.account_id is null
    or not account_360.is_churn_risk
