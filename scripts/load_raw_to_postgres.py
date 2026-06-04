from __future__ import annotations

import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "generated"

RAW_SCHEMA = "raw"

TABLE_FILES = {
    "crm_accounts": "crm_accounts.csv",
    "crm_contacts": "crm_contacts.csv",
    "crm_deals": "crm_deals.csv",
    "billing_customers": "billing_customers.csv",
    "billing_subscriptions": "billing_subscriptions.csv",
    "billing_invoices": "billing_invoices.csv",
    "billing_payments": "billing_payments.csv",
    "product_events": "product_events.csv",
    "support_tickets": "support_tickets.csv",
}


def get_database_url() -> str:
    load_dotenv(PROJECT_ROOT / ".env")

    user = os.getenv("POSTGRES_USER", "analytics")
    password = os.getenv("POSTGRES_PASSWORD", "analytics_pwd")
    database = os.getenv("POSTGRES_DB", "saas_platform")
    port = os.getenv("POSTGRES_LOCAL_PORT", "5432")

    # This script runs from the host machine, so localhost is correct here.
    host = "localhost"

    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}"


def create_db_engine() -> Engine:
    database_url = get_database_url()
    return create_engine(database_url)


def ensure_raw_schema(engine: Engine) -> None:
    with engine.begin() as connection:
        connection.execute(text(f"create schema if not exists {RAW_SCHEMA};"))


def validate_input_files() -> None:
    missing_files = []

    for filename in TABLE_FILES.values():
        path = DATA_DIR / filename
        if not path.exists():
            missing_files.append(str(path.relative_to(PROJECT_ROOT)))

    if missing_files:
        missing = "\n".join(f"- {file}" for file in missing_files)
        raise FileNotFoundError(
            "Missing generated CSV files. Run scripts/generate_synthetic_data.py first.\n"
            f"{missing}"
        )


def load_table(engine: Engine, table_name: str, filename: str) -> int:
    path = DATA_DIR / filename
    df = pd.read_csv(path)

    df.to_sql(
        name=table_name,
        con=engine,
        schema=RAW_SCHEMA,
        if_exists="replace",
        index=False,
        method="multi",
        chunksize=5_000,
    )

    return len(df)


def create_load_audit_table(engine):
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                create schema if not exists monitoring;
                """
            )
        )

        connection.execute(
            text(
                """
                create table if not exists monitoring.raw_load_audit (
                    load_id bigserial primary key,
                    table_schema text not null,
                    table_name text not null,
                    row_count integer not null,
                    loaded_at timestamp not null default current_timestamp
                );
                """
            )
        )


def write_load_audit(engine: Engine, table_name: str, row_count: int) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                insert into monitoring.raw_load_audit (
                    table_schema,
                    table_name,
                    row_count
                )
                values (
                    :table_schema,
                    :table_name,
                    :row_count
                );
                """
            ),
            {
                "table_schema": RAW_SCHEMA,
                "table_name": table_name,
                "row_count": row_count,
            },
        )


def main() -> None:
    validate_input_files()

    engine = create_db_engine()
    ensure_raw_schema(engine)
    create_load_audit_table(engine)

    print("Loading generated CSV files into PostgreSQL raw schema...\n")

    for table_name, filename in TABLE_FILES.items():
        row_count = load_table(engine, table_name, filename)
        write_load_audit(engine, table_name, row_count)
        print(f"Loaded raw.{table_name}: {row_count:,} rows")

    print("\nRaw data load completed.")


if __name__ == "__main__":
    main()
