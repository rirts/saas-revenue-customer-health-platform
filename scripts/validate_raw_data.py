from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import Engine


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_SCHEMA = "raw"
MONITORING_SCHEMA = "monitoring"

EXPECTED_TABLES = {
    "crm_accounts": "account_id",
    "crm_contacts": "contact_id",
    "crm_deals": "deal_id",
    "billing_customers": "billing_customer_id",
    "billing_subscriptions": "subscription_id",
    "billing_invoices": "invoice_id",
    "billing_payments": "payment_id",
    "product_events": "event_id",
    "support_tickets": "ticket_id",
}

RELATIONSHIP_CHECKS = [
    {
        "check_name": "crm_contacts_account_id_exists_in_crm_accounts",
        "child_table": "crm_contacts",
        "child_key": "account_id",
        "parent_table": "crm_accounts",
        "parent_key": "account_id",
    },
    {
        "check_name": "crm_deals_account_id_exists_in_crm_accounts",
        "child_table": "crm_deals",
        "child_key": "account_id",
        "parent_table": "crm_accounts",
        "parent_key": "account_id",
    },
    {
        "check_name": "billing_customers_account_id_exists_in_crm_accounts",
        "child_table": "billing_customers",
        "child_key": "account_id",
        "parent_table": "crm_accounts",
        "parent_key": "account_id",
    },
    {
        "check_name": "billing_subscriptions_account_id_exists_in_crm_accounts",
        "child_table": "billing_subscriptions",
        "child_key": "account_id",
        "parent_table": "crm_accounts",
        "parent_key": "account_id",
    },
    {
        "check_name": "billing_invoices_subscription_id_exists_in_billing_subscriptions",
        "child_table": "billing_invoices",
        "child_key": "subscription_id",
        "parent_table": "billing_subscriptions",
        "parent_key": "subscription_id",
    },
    {
        "check_name": "billing_payments_invoice_id_exists_in_billing_invoices",
        "child_table": "billing_payments",
        "child_key": "invoice_id",
        "parent_table": "billing_invoices",
        "parent_key": "invoice_id",
    },
    {
        "check_name": "product_events_subscription_id_exists_in_billing_subscriptions",
        "child_table": "product_events",
        "child_key": "subscription_id",
        "parent_table": "billing_subscriptions",
        "parent_key": "subscription_id",
    },
    {
        "check_name": "support_tickets_subscription_id_exists_in_billing_subscriptions",
        "child_table": "support_tickets",
        "child_key": "subscription_id",
        "parent_table": "billing_subscriptions",
        "parent_key": "subscription_id",
    },
]

DATE_CHECKS = [
    {
        "check_name": "crm_accounts_created_at_valid",
        "table_name": "crm_accounts",
        "date_column": "created_at",
    },
    {
        "check_name": "crm_deals_created_at_valid",
        "table_name": "crm_deals",
        "date_column": "created_at",
    },
    {
        "check_name": "billing_subscriptions_start_date_valid",
        "table_name": "billing_subscriptions",
        "date_column": "start_date",
    },
    {
        "check_name": "billing_invoices_invoice_date_valid",
        "table_name": "billing_invoices",
        "date_column": "invoice_date",
    },
    {
        "check_name": "billing_payments_payment_date_valid",
        "table_name": "billing_payments",
        "date_column": "payment_date",
    },
    {
        "check_name": "product_events_occurred_at_valid",
        "table_name": "product_events",
        "date_column": "occurred_at",
    },
    {
        "check_name": "support_tickets_created_at_valid",
        "table_name": "support_tickets",
        "date_column": "created_at",
    },
]

NON_NEGATIVE_CHECKS = [
    {
        "check_name": "crm_deals_deal_amount_usd_non_negative",
        "table_name": "crm_deals",
        "amount_column": "deal_amount_usd",
    },
    {
        "check_name": "crm_deals_expected_mrr_usd_non_negative",
        "table_name": "crm_deals",
        "amount_column": "expected_mrr_usd",
    },
    {
        "check_name": "billing_subscriptions_mrr_usd_non_negative",
        "table_name": "billing_subscriptions",
        "amount_column": "mrr_usd",
    },
    {
        "check_name": "billing_subscriptions_arr_usd_non_negative",
        "table_name": "billing_subscriptions",
        "amount_column": "arr_usd",
    },
    {
        "check_name": "billing_invoices_amount_due_usd_non_negative",
        "table_name": "billing_invoices",
        "amount_column": "amount_due_usd",
    },
    {
        "check_name": "billing_payments_amount_paid_usd_non_negative",
        "table_name": "billing_payments",
        "amount_column": "amount_paid_usd",
    },
]


def get_database_url() -> str:
    load_dotenv(PROJECT_ROOT / ".env")

    user = os.getenv("POSTGRES_USER", "analytics")
    password = os.getenv("POSTGRES_PASSWORD", "analytics_pwd")
    database = os.getenv("POSTGRES_DB", "saas_platform")
    port = os.getenv("POSTGRES_LOCAL_PORT", "5432")

    return f"postgresql+psycopg2://{user}:{password}@localhost:{port}/{database}"


def create_db_engine() -> Engine:
    return create_engine(get_database_url())


def create_validation_results_table(engine: Engine) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                f"""
                create schema if not exists {MONITORING_SCHEMA};

                create table if not exists {MONITORING_SCHEMA}.raw_validation_results (
                    validation_id bigserial primary key,
                    check_name text not null,
                    table_schema text not null,
                    table_name text not null,
                    check_type text not null,
                    status text not null,
                    failed_records integer not null,
                    details text,
                    checked_at timestamp not null default current_timestamp
                );
                """
            )
        )


def write_result(
    engine: Engine,
    check_name: str,
    table_name: str,
    check_type: str,
    failed_records: int,
    details: str | None = None,
) -> None:
    status = "pass" if failed_records == 0 else "fail"

    with engine.begin() as connection:
        connection.execute(
            text(
                f"""
                insert into {MONITORING_SCHEMA}.raw_validation_results (
                    check_name,
                    table_schema,
                    table_name,
                    check_type,
                    status,
                    failed_records,
                    details
                )
                values (
                    :check_name,
                    :table_schema,
                    :table_name,
                    :check_type,
                    :status,
                    :failed_records,
                    :details
                );
                """
            ),
            {
                "check_name": check_name,
                "table_schema": RAW_SCHEMA,
                "table_name": table_name,
                "check_type": check_type,
                "status": status,
                "failed_records": failed_records,
                "details": details,
            },
        )


def get_scalar(engine: Engine, sql: str, params: dict[str, Any] | None = None) -> int:
    with engine.begin() as connection:
        result = connection.execute(text(sql), params or {}).scalar()
    return int(result or 0)


def validate_expected_tables_exist(engine: Engine) -> int:
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names(schema=RAW_SCHEMA))

    failed_checks = 0

    for table_name in EXPECTED_TABLES:
        missing = table_name not in existing_tables
        failed_records = 1 if missing else 0

        write_result(
            engine=engine,
            check_name=f"{table_name}_exists",
            table_name=table_name,
            check_type="table_exists",
            failed_records=failed_records,
            details="Missing table" if missing else "Table exists",
        )

        if missing:
            failed_checks += 1

    return failed_checks


def validate_table_not_empty(engine: Engine) -> int:
    failed_checks = 0

    for table_name in EXPECTED_TABLES:
        row_count = get_scalar(engine, f"select count(*) from {RAW_SCHEMA}.{table_name};")
        failed_records = 1 if row_count == 0 else 0

        write_result(
            engine=engine,
            check_name=f"{table_name}_not_empty",
            table_name=table_name,
            check_type="not_empty",
            failed_records=failed_records,
            details=f"row_count={row_count}",
        )

        if failed_records:
            failed_checks += 1

    return failed_checks


def validate_primary_keys(engine: Engine) -> int:
    failed_checks = 0

    for table_name, primary_key in EXPECTED_TABLES.items():
        null_count = get_scalar(
            engine,
            f"""
            select count(*)
            from {RAW_SCHEMA}.{table_name}
            where {primary_key} is null;
            """,
        )

        duplicate_count = get_scalar(
            engine,
            f"""
            select count(*)
            from (
                select {primary_key}
                from {RAW_SCHEMA}.{table_name}
                group by {primary_key}
                having count(*) > 1
            ) duplicates;
            """,
        )

        write_result(
            engine=engine,
            check_name=f"{table_name}_{primary_key}_not_null",
            table_name=table_name,
            check_type="primary_key_not_null",
            failed_records=null_count,
            details=f"primary_key={primary_key}",
        )

        write_result(
            engine=engine,
            check_name=f"{table_name}_{primary_key}_unique",
            table_name=table_name,
            check_type="primary_key_unique",
            failed_records=duplicate_count,
            details=f"primary_key={primary_key}",
        )

        if null_count > 0:
            failed_checks += 1

        if duplicate_count > 0:
            failed_checks += 1

    return failed_checks


def validate_relationships(engine: Engine) -> int:
    failed_checks = 0

    for check in RELATIONSHIP_CHECKS:
        failed_records = get_scalar(
            engine,
            f"""
            select count(*)
            from {RAW_SCHEMA}.{check["child_table"]} child
            left join {RAW_SCHEMA}.{check["parent_table"]} parent
                on child.{check["child_key"]} = parent.{check["parent_key"]}
            where child.{check["child_key"]} is not null
              and parent.{check["parent_key"]} is null;
            """,
        )

        write_result(
            engine=engine,
            check_name=check["check_name"],
            table_name=check["child_table"],
            check_type="relationship",
            failed_records=failed_records,
            details=(
                f'{check["child_table"]}.{check["child_key"]} -> '
                f'{check["parent_table"]}.{check["parent_key"]}'
            ),
        )

        if failed_records > 0:
            failed_checks += 1

    return failed_checks


def validate_dates(engine: Engine) -> int:
    failed_checks = 0

    for check in DATE_CHECKS:
        failed_records = get_scalar(
            engine,
            f"""
            select count(*)
            from {RAW_SCHEMA}.{check["table_name"]}
            where {check["date_column"]} is null
               or cast({check["date_column"]} as text) = '';
            """,
        )

        write_result(
            engine=engine,
            check_name=check["check_name"],
            table_name=check["table_name"],
            check_type="date_not_null",
            failed_records=failed_records,
            details=f'date_column={check["date_column"]}',
        )

        if failed_records > 0:
            failed_checks += 1

    return failed_checks


def validate_non_negative_amounts(engine: Engine) -> int:
    failed_checks = 0

    for check in NON_NEGATIVE_CHECKS:
        failed_records = get_scalar(
            engine,
            f"""
            select count(*)
            from {RAW_SCHEMA}.{check["table_name"]}
            where {check["amount_column"]} < 0;
            """,
        )

        write_result(
            engine=engine,
            check_name=check["check_name"],
            table_name=check["table_name"],
            check_type="non_negative_amount",
            failed_records=failed_records,
            details=f'amount_column={check["amount_column"]}',
        )

        if failed_records > 0:
            failed_checks += 1

    return failed_checks


def main() -> None:
    engine = create_db_engine()
    create_validation_results_table(engine)

    print("Running raw data validation checks...\n")

    total_failed_checks = 0
    total_failed_checks += validate_expected_tables_exist(engine)
    total_failed_checks += validate_table_not_empty(engine)
    total_failed_checks += validate_primary_keys(engine)
    total_failed_checks += validate_relationships(engine)
    total_failed_checks += validate_dates(engine)
    total_failed_checks += validate_non_negative_amounts(engine)

    if total_failed_checks == 0:
        print("All raw data validation checks passed.")
    else:
        print(f"Raw data validation completed with {total_failed_checks} failed checks.")
        raise SystemExit(1)


if __name__ == "__main__":
    main()