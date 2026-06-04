from __future__ import annotations

import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow import DAG
from airflow.operators.bash import BashOperator


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", "/opt/airflow/project"))

DEFAULT_ARGS = {
    "owner": "data-platform",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


with DAG(
    dag_id="saas_revenue_customer_health_pipeline",
    description="Orchestrates the SaaS revenue and customer health analytics pipeline.",
    default_args=DEFAULT_ARGS,
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    max_active_runs=1,
    tags=["saas", "analytics-engineering", "customer-health", "dbt"],
    doc_md="""
# SaaS Revenue & Customer Health Pipeline

This DAG orchestrates the end-to-end analytics pipeline for the SaaS Revenue & Customer Health Platform.

Pipeline stages:

1. Generate synthetic SaaS source data.
2. Load raw CSV data into PostgreSQL.
3. Validate raw data quality.
4. Install dbt package dependencies.
5. Build dbt staging, intermediate, and mart models.
6. Collect warehouse row-count observability snapshots.

The DAG intentionally delegates business logic to existing Python scripts and dbt models.
Airflow is used only for orchestration, retries, scheduling, and operational visibility.
""",
) as dag:
    generate_synthetic_data = BashOperator(
        task_id="generate_synthetic_data",
        bash_command=f"cd {PROJECT_ROOT} && python scripts/generate_synthetic_data.py",
    )

    load_raw_to_postgres = BashOperator(
        task_id="load_raw_to_postgres",
        bash_command=f"cd {PROJECT_ROOT} && python scripts/load_raw_to_postgres.py",
    )

    validate_raw_data = BashOperator(
        task_id="validate_raw_data",
        bash_command=f"cd {PROJECT_ROOT} && python scripts/validate_raw_data.py",
    )

    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=(
            f"cd {PROJECT_ROOT} && "
            "dbt deps --project-dir warehouse/dbt --profiles-dir warehouse/dbt"
        ),
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command=(
            f"cd {PROJECT_ROOT} && "
            "dbt build --project-dir warehouse/dbt --profiles-dir warehouse/dbt"
        ),
    )

    collect_table_row_counts = BashOperator(
        task_id="collect_table_row_counts",
        bash_command=(
            f"cd {PROJECT_ROOT} && "
            "python scripts/collect_table_row_counts.py "
            "--run-id {{ dag_run.run_id }}"
        ),
    )

    (
        generate_synthetic_data
        >> load_raw_to_postgres
        >> validate_raw_data
        >> dbt_deps
        >> dbt_build
        >> collect_table_row_counts
    )