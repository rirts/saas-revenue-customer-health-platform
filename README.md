# SaaS Revenue & Customer Health Data Platform

Production-style data engineering and analytics engineering project for a B2B SaaS business.

This project simulates a modern data platform that integrates CRM, billing, product usage, and support data to build revenue analytics, customer health scoring, churn risk indicators, and executive-ready data marts.

The goal is to demonstrate how raw operational data can be transformed into reliable business metrics using orchestration, warehouse modeling, data quality checks, monitoring, and BI-ready outputs.

## Tech Stack

- Python
- PostgreSQL
- dbt
- Apache Airflow
- Docker Compose
- Metabase
- GitHub Actions

## Business Context

A B2B SaaS company needs a reliable analytics platform to answer questions such as:

- How much MRR and ARR are we generating?
- Which customers are expanding, contracting, or churning?
- Which accounts show early signs of churn risk?
- How does product usage relate to customer health?
- Which customers generate the highest support burden?
- What metrics should executives monitor weekly?

This project builds the data foundation required to answer those questions consistently.

## Planned Architecture

Synthetic source data
        ↓
Python ingestion scripts
        ↓
PostgreSQL raw schema
        ↓
dbt staging models
        ↓
dbt intermediate models
        ↓
dbt marts
        ↓
Metabase dashboards
        ↓
Monitoring tables and pipeline logs

## Data Sources

The project uses synthetic data representing four operational systems:

- CRM: accounts, contacts, deals
- Billing: customers, subscriptions, invoices, payments
- Product: user and account-level product events
- Support: tickets, severity, status, and resolution times

## Planned Data Models

The warehouse follows a layered modeling approach:

- Raw: source-aligned tables loaded into PostgreSQL
- Staging: cleaned and typed source models
- Intermediate: business logic and entity resolution
- Marts: BI-ready tables for revenue, customer health, product usage, and executive reporting

## Planned Metrics

Revenue metrics:

- MRR
- ARR
- New MRR
- Expansion MRR
- Contraction MRR
- Churned MRR
- Net Revenue Retention
- Gross Revenue Retention

Customer health metrics:

- Health score
- Activation status
- Usage trend
- Support burden
- Payment status
- Churn risk segment

Product Metrics

- Monthly active accounts
- Feature adoption
- Active users per account
- Integrations connected
- Reports created

Support Metrics

- Tickets per account
- Average resolution time
- Open critical tickets
- Repeated issue accounts

## Project Structure

```bash
saas-revenue-customer-health-platform/
├── data/
├── scripts/
├── warehouse/dbt/
├── orchestration/airflow/
├── monitoring/
├── dashboards/
├── docs/
└── .github/workflows/
```

## Current Status

Project Initialized

Next Steps:

1. Configure Docker Compose with PostgreSQL, Airflow, and Metabase.
2. Generate synthetic source data.
3. Load raw data into PostgreSQL.
4. Build dbt staging models.
5. Add data quality checks and pipeline monitoring.
6. Create BI-ready marts and dashboard screenshots.

## License

All rights reserved.

No permission is granted to use, copy, modify, or distribute this work without explicit written consent from the copyright holder.