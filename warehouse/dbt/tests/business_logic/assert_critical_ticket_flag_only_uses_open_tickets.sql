select s.account_id
from {{ ref('int_support__account_ticket_summary') }} as s
where s.has_critical_ticket is distinct from exists (
    select 1 from {{ ref('stg_support__tickets') }} as t
    where
        t.account_id = s.account_id and t.severity = 'critical' and t.is_open
        and t.created_date <= '{{ var('as_of_date') }}'::date
)
