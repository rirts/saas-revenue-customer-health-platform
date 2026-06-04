with source as (

    select *
    from {{ source('raw', 'crm_accounts') }}

),

renamed as (

    select
        account_id::text as account_id,
        account_name::text as account_name,
        industry::text as industry,
        segment::text as segment,
        employee_band::text as employee_band,
        country::text as country,
        created_at::date as created_at,
        account_owner::text as account_owner
    from source

)

select *
from renamed
