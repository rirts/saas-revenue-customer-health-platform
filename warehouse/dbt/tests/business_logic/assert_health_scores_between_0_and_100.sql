{{ config(tags=['business_logic', 'data_contract']) }}

select *
from {{ ref('mart_customer_health') }}
where customer_health_score < 0
   or customer_health_score > 100
   or raw_customer_health_score < 0
   or raw_customer_health_score > 100