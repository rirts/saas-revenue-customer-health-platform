import argparse
import os
from datetime import UTC, datetime
from typing import Any

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

PIPELINE_NAME = "saas_revenue_customer_health_platform"
TARGET_SCHEMAS = ["raw", "staging", "intermediate", "marts"]


def get_database_url() -> str:
    load_dotenv()

    user = os.getenv("POSTGRES_USER", "analytics")
    password = os.getenv("POSTGRES_PASSWORD", "analytics_pwd")
    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    database = os.getenv("POSTGRES_DB", "saas_platform")

    # In Docker Compose, the PostgreSQL service is reachable as "postgres".
    # When this script runs from the local host machine, it must use "localhost".
    if host == "postgres":
        host = "localhost"

    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}"


def create_monitoring_table(engine: Engine) -> None:
    with engine.begin() as connection:
        connection.execute(text("create schema if not exists monitoring;"))

        connection.execute(
            text(
                """
                create table if not exists monitoring.table_row_count_audit (
                    audit_id bigserial primary key,
                    run_id text,
                    pipeline_name text not null,
                    schema_name text not null,
                    relation_name text not null,
                    relation_type text not null,
                    row_count bigint not null,
                    observed_at timestamptz not null default now(),
                    created_at timestamptz not null default now()
                );
                """
            )
        )

        connection.execute(
            text(
                """
                create index if not exists idx_table_row_count_audit_run_id
                    on monitoring.table_row_count_audit (run_id);
                """
            )
        )

        connection.execute(
            text(
                """
                create index if not exists idx_table_row_count_audit_schema_relation
                    on monitoring.table_row_count_audit (schema_name, relation_name);
                """
            )
        )

        connection.execute(
            text(
                """
                create index if not exists idx_table_row_count_audit_observed_at
                    on monitoring.table_row_count_audit (observed_at);
                """
            )
        )


def get_relations(engine: Engine) -> list[dict[str, Any]]:
    with engine.begin() as connection:
        result = connection.execute(
            text(
                """
                select
                    table_schema as schema_name,
                    table_name as relation_name,
                    table_type as relation_type
                from information_schema.tables
                where table_schema in ('raw', 'staging', 'intermediate', 'marts')
                  and table_type in ('BASE TABLE', 'VIEW')
                order by table_schema, table_name;
                """
            )
        )

        return [dict(row._mapping) for row in result]


def quote_identifier(identifier: str) -> str:
    return '"' + identifier.replace('"', '""') + '"'


def count_relation_rows(engine: Engine, schema_name: str, relation_name: str) -> int:
    quoted_schema = quote_identifier(schema_name)
    quoted_relation = quote_identifier(relation_name)

    query = text(
        f"select count(*) as row_count from {quoted_schema}.{quoted_relation};"
    )

    with engine.begin() as connection:
        result = connection.execute(query).scalar_one()

    return int(result)


def insert_row_count_audit(
    engine: Engine,
    run_id: str | None,
    schema_name: str,
    relation_name: str,
    relation_type: str,
    row_count: int,
    observed_at: datetime,
) -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                """
                insert into monitoring.table_row_count_audit (
                    run_id,
                    pipeline_name,
                    schema_name,
                    relation_name,
                    relation_type,
                    row_count,
                    observed_at
                )
                values (
                    :run_id,
                    :pipeline_name,
                    :schema_name,
                    :relation_name,
                    :relation_type,
                    :row_count,
                    :observed_at
                );
                """
            ),
            {
                "run_id": run_id,
                "pipeline_name": PIPELINE_NAME,
                "schema_name": schema_name,
                "relation_name": relation_name,
                "relation_type": relation_type,
                "row_count": row_count,
                "observed_at": observed_at,
            },
        )


def collect_table_row_counts(run_id: str | None) -> None:
    engine = create_engine(get_database_url())

    create_monitoring_table(engine)

    relations = get_relations(engine)
    observed_at = datetime.now(UTC)

    if not relations:
        print("No relations found for row-count collection.")
        return

    print("Collecting table and view row counts...")

    for relation in relations:
        schema_name = relation["schema_name"]
        relation_name = relation["relation_name"]
        relation_type = relation["relation_type"]

        row_count = count_relation_rows(
            engine=engine,
            schema_name=schema_name,
            relation_name=relation_name,
        )

        insert_row_count_audit(
            engine=engine,
            run_id=run_id,
            schema_name=schema_name,
            relation_name=relation_name,
            relation_type=relation_type,
            row_count=row_count,
            observed_at=observed_at,
        )

        print(f"{schema_name}.{relation_name} ({relation_type}) -> {row_count:,} rows")

    print(f"Row-count collection completed. Relations observed: {len(relations)}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect row counts for warehouse relations."
    )

    parser.add_argument(
        "--run-id",
        required=False,
        default=None,
        help="Pipeline run identifier used to associate row counts with a pipeline execution.",
    )

    return parser.parse_args()


def main() -> None:
    args = parse_args()
    collect_table_row_counts(run_id=args.run_id)


if __name__ == "__main__":
    main()
