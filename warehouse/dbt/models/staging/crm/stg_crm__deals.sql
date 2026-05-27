with source as (

    select *
    from {{ source('raw', 'crm_deals') }}

),

renamed as (

    select
        deal_id::text as deal_id,
        account_id::text as account_id,
        deal_name::text as deal_name,
        pipeline::text as pipeline,
        deal_stage::text as deal_stage,
        deal_amount_usd::numeric(18, 2) as deal_amount_usd,
        expected_mrr_usd::numeric(18, 2) as expected_mrr_usd,
        plan::text as plan,
        created_at::date as created_at,
        nullif(close_date::text, '')::date as close_date
    from source

)

select *
from renamed