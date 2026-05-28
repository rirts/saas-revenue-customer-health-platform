with tickets as (

    select *
    from {{ ref('stg_support__tickets') }}

),

ticket_aggregated as (

    select
        account_id,

        count(*) as total_tickets,
        count(*) filter (where is_open) as open_tickets,
        count(*) filter (where is_resolved) as resolved_tickets,
        count(*) filter (where is_high_priority) as high_priority_tickets,

        count(*) filter (where severity = 'critical') as critical_tickets,
        count(*) filter (where severity = 'high') as high_tickets,
        count(*) filter (where severity = 'medium') as medium_tickets,
        count(*) filter (where severity = 'low') as low_tickets,

        min(created_date) as first_ticket_date,
        max(created_date) as latest_ticket_date,

        round(avg(resolution_days)::numeric, 2) as avg_resolution_days

    from tickets
    group by account_id

),

final as (

    select
        account_id,
        total_tickets,
        open_tickets,
        resolved_tickets,
        high_priority_tickets,

        critical_tickets,
        high_tickets,
        medium_tickets,
        low_tickets,

        first_ticket_date,
        latest_ticket_date,
        avg_resolution_days,

        case
            when total_tickets >= 8 or high_priority_tickets >= 3 then 'high_burden'
            when total_tickets >= 4 or high_priority_tickets >= 1 then 'medium_burden'
            when total_tickets > 0 then 'low_burden'
            else 'no_burden'
        end as support_burden_level,

        case
            when open_tickets > 0 then true
            else false
        end as has_open_tickets,

        case
            when critical_tickets > 0 then true
            else false
        end as has_critical_ticket

    from ticket_aggregated

)

select *
from final