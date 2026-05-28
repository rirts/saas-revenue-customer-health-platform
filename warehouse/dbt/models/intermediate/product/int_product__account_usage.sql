with events as (

    select *
    from {{ ref('stg_product__events') }}

),

usage_aggregated as (

    select
        account_id,
        count(*) as total_events,
        count(distinct user_id) as active_users,
        count(distinct event_date) as active_days,

        min(event_date) as first_event_date,
        max(event_date) as latest_event_date,

        count(*) filter (where event_type = 'login') as login_events,
        count(*) filter (where event_type = 'dashboard_viewed') as dashboard_view_events,
        count(*) filter (where event_type = 'report_created') as report_created_events,
        count(*) filter (where event_type = 'integration_connected') as integration_connected_events,
        count(*) filter (where event_type = 'user_invited') as user_invited_events,
        count(*) filter (where event_type = 'export_downloaded') as export_downloaded_events,

        count(distinct event_type) as adopted_feature_count

    from events
    group by account_id

),

final as (

    select
        account_id,
        total_events,
        active_users,
        active_days,
        first_event_date,
        latest_event_date,

        login_events,
        dashboard_view_events,
        report_created_events,
        integration_connected_events,
        user_invited_events,
        export_downloaded_events,
        adopted_feature_count,

        case
            when total_events >= 500 then 'high_usage'
            when total_events >= 150 then 'medium_usage'
            when total_events > 0 then 'low_usage'
            else 'no_usage'
        end as usage_intensity,

        case
            when integration_connected_events > 0 then true
            else false
        end as has_connected_integration,

        case
            when report_created_events > 0 then true
            else false
        end as has_created_report

    from usage_aggregated

)

select *
from final