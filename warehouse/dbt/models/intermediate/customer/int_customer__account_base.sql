with accounts as (

    select *
    from {{ ref('stg_crm__accounts') }}

),

contacts as (

    select *
    from {{ ref('stg_crm__contacts') }}

),

deals as (

    select *
    from {{ ref('stg_crm__deals') }}

),

billing_customers as (

    select *
    from {{ ref('stg_billing__customers') }}

),

subscriptions as (

    select *
    from {{ ref('stg_billing__subscriptions') }}

),

contacts_aggregated as (

    select
        account_id,
        count(*) as contact_count,
        count(*) filter (where contact_role = 'Executive Sponsor') as executive_sponsor_count,
        count(*) filter (where contact_role = 'Admin') as admin_contact_count
    from contacts
    group by account_id

),

deals_aggregated as (

    select
        account_id,
        count(*) as total_deals,
        count(*) filter (where deal_stage = 'closed_won') as won_deals,
        count(*) filter (where deal_stage = 'closed_lost') as lost_deals,
        sum(deal_amount_usd) filter (where deal_stage = 'closed_won') as won_deal_amount_usd,
        sum(expected_mrr_usd) filter (where deal_stage = 'closed_won') as won_expected_mrr_usd,
        min(created_at) as first_deal_created_at,
        max(close_date) filter (where deal_stage = 'closed_won') as latest_won_close_date
    from deals
    group by account_id

),

subscriptions_aggregated as (

    select
        account_id,
        count(*) as subscription_count,
        count(*) filter (where is_active) as active_subscription_count,
        count(*) filter (where is_past_due) as past_due_subscription_count,
        count(*) filter (where is_canceled) as canceled_subscription_count,
        sum(mrr_usd) filter (where not is_canceled) as current_mrr_usd,
        sum(arr_usd) filter (where not is_canceled) as current_arr_usd,
        min(start_date) as first_subscription_start_date,
        max(canceled_at) as latest_canceled_at
    from subscriptions
    group by account_id

),

final as (

    select
        accounts.account_id,
        accounts.account_name,
        accounts.industry,
        accounts.segment,
        accounts.employee_band,
        accounts.country,
        accounts.created_at as account_created_at,
        accounts.account_owner,

        coalesce(contacts_aggregated.contact_count, 0) as contact_count,
        coalesce(contacts_aggregated.executive_sponsor_count, 0) as executive_sponsor_count,
        coalesce(contacts_aggregated.admin_contact_count, 0) as admin_contact_count,

        coalesce(deals_aggregated.total_deals, 0) as total_deals,
        coalesce(deals_aggregated.won_deals, 0) as won_deals,
        coalesce(deals_aggregated.lost_deals, 0) as lost_deals,
        coalesce(deals_aggregated.won_deal_amount_usd, 0)::numeric(18, 2) as won_deal_amount_usd,
        coalesce(deals_aggregated.won_expected_mrr_usd, 0)::numeric(18, 2) as won_expected_mrr_usd,
        deals_aggregated.first_deal_created_at,
        deals_aggregated.latest_won_close_date,

        billing_customers.billing_customer_id,

        coalesce(subscriptions_aggregated.subscription_count, 0) as subscription_count,
        coalesce(subscriptions_aggregated.active_subscription_count, 0) as active_subscription_count,
        coalesce(subscriptions_aggregated.past_due_subscription_count, 0) as past_due_subscription_count,
        coalesce(subscriptions_aggregated.canceled_subscription_count, 0) as canceled_subscription_count,
        coalesce(subscriptions_aggregated.current_mrr_usd, 0)::numeric(18, 2) as current_mrr_usd,
        coalesce(subscriptions_aggregated.current_arr_usd, 0)::numeric(18, 2) as current_arr_usd,
        subscriptions_aggregated.first_subscription_start_date,
        subscriptions_aggregated.latest_canceled_at,

        case
            when coalesce(subscriptions_aggregated.active_subscription_count, 0) > 0 then 'active_customer'
            when coalesce(subscriptions_aggregated.past_due_subscription_count, 0) > 0 then 'past_due_customer'
            when coalesce(subscriptions_aggregated.canceled_subscription_count, 0) > 0 then 'churned_customer'
            when coalesce(deals_aggregated.won_deals, 0) > 0 then 'won_not_subscribed'
            else 'prospect'
        end as account_lifecycle_stage

    from accounts
    left join contacts_aggregated
        on accounts.account_id = contacts_aggregated.account_id
    left join deals_aggregated
        on accounts.account_id = deals_aggregated.account_id
    left join billing_customers
        on accounts.account_id = billing_customers.account_id
    left join subscriptions_aggregated
        on accounts.account_id = subscriptions_aggregated.account_id

)

select *
from final