{% docs mart_customer_health_overview %}

# Customer Health Mart

The `mart_customer_health` model provides an account-level view of customer health for Customer Success and executive reporting.

It combines revenue, product usage, support burden, payment behavior, account lifecycle, and contact coverage into a single business-ready health score and customer health segment.

This mart is designed to answer questions such as:

- Which customers are healthy, at risk, critical, or under watch?
- How much current MRR is associated with each customer health segment?
- Which accounts require immediate customer success intervention?
- Which accounts should be excluded from customer health motions because they are not current customers?

{% enddocs %}


{% docs mart_account_360_overview %}

# Account 360 Mart

The `mart_account_360` model is the main executive account-level mart.

It provides one row per account and combines customer lifecycle, revenue, customer health, product adoption, support burden, churn risk, and recommended account action.

This mart is designed to support a single customer view for executive dashboards, Customer Success prioritization, and account portfolio analysis.

Key business questions:

- What is the current status of each account?
- Which accounts represent the largest MRR at risk?
- Which accounts are healthy expansion candidates?
- Which customers require intervention based on health, revenue tier, and risk signals?

{% enddocs %}


{% docs mart_revenue_retention_overview %}

# Revenue Retention Mart

The `mart_revenue_retention` model summarizes customer revenue by health segment, revenue tier, and account priority action.

It is designed for executive-level revenue retention reporting.

Key business questions:

- How much current MRR is healthy versus at risk?
- Which customer health segments concentrate the most MRR at risk?
- Which revenue tiers have the highest risk exposure?
- Which customer success actions should be prioritized based on MRR impact?

{% enddocs %}


{% docs mart_churn_risk_overview %}

# Churn Risk Mart

The `mart_churn_risk` model provides an operational account-level view of churn-risk accounts.

It classifies each risky account by primary risk reason, recommended playbook, and priority level.

Key business questions:

- Which accounts are currently at risk of churn?
- What is the main risk driver for each account?
- Which accounts require support escalation, payment follow-up, adoption intervention, or winback review?
- How should Customer Success prioritize the risk queue?

{% enddocs %}


{% docs mart_product_adoption_overview %}

# Product Adoption Mart

The `mart_product_adoption` model summarizes product usage and adoption patterns by customer health segment, revenue tier, and usage intensity.

It explains how product engagement contributes to customer health and churn risk.

Key business questions:

- How much MRR at risk is associated with low product usage?
- Which revenue tiers have low adoption risk?
- Are customers adopting key product features?
- Are customers connecting integrations and creating reports?

{% enddocs %}


{% docs mart_support_operations_overview %}

# Support Operations Mart

The `mart_support_operations` model summarizes support burden, open tickets, high-priority tickets, critical tickets, and support-driven risk by customer health segment and revenue tier.

It helps connect support operations to customer health and revenue risk.

Key business questions:

- Which customer groups generate the highest support burden?
- How much MRR at risk is associated with support issues?
- Which segments have critical or open tickets?
- Is support risk concentrated in at-risk customers or spread across the customer base?

{% enddocs %}