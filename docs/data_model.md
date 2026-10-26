# Data model

`account_id` is the shared account key. Contacts, deals, subscriptions, usage and tickets are aggregated to their intended grain before joins. `mart_account_360` has one row per account. Invoice payments are aggregated per invoice before subscription/account totals. See dbt YAML contracts and business logic tests for invariants.
