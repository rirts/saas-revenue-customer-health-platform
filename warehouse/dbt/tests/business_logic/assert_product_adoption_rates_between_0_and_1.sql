{{ config(tags=['business_logic', 'data_contract']) }}

select
    customer_health_segment,
    revenue_tier,
    usage_intensity,
    integration_adoption_rate,
    low_usage_paid_account_rate,
    report_creation_rate
from {{ ref('mart_product_adoption') }}
where
    integration_adoption_rate < 0
    or integration_adoption_rate > 1
    or low_usage_paid_account_rate < 0
    or low_usage_paid_account_rate > 1
    or report_creation_rate < 0
    or report_creation_rate > 1
