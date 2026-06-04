with source as (

    select *
    from {{ source('raw', 'crm_contacts') }}

),

renamed as (

    select
        contact_id::text as contact_id,
        account_id::text as account_id,
        email::text as email,
        full_name::text as full_name,
        role::text as contact_role,
        created_at::date as created_at
    from source

)

select *
from renamed
