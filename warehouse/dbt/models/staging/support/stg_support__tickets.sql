with source as (

    select *
    from {{ source('raw', 'support_tickets') }}

),

renamed as (

    select
        ticket_id::text as ticket_id,
        account_id::text as account_id,
        subscription_id::text as subscription_id,
        created_at::timestamp as created_at,
        created_at::date as created_date,
        nullif(resolved_at::text, '')::timestamp as resolved_at,
        nullif(resolved_at::text, '')::date as resolved_date,
        status::text as ticket_status,
        severity::text as severity,
        category::text as category,

        case
            when status in ('resolved', 'closed') then true
            else false
        end as is_resolved,

        case
            when status in ('open', 'pending') then true
            else false
        end as is_open,

        case
            when severity in ('high', 'critical') then true
            else false
        end as is_high_priority,

        case
            when nullif(resolved_at::text, '') is not null
                then extract(day from nullif(resolved_at::text, '')::timestamp - created_at::timestamp)::integer
            else null
        end as resolution_days
    from source

)

select *
from renamed