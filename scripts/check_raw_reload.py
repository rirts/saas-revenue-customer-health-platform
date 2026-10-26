"""Integration regression: run after dbt build against the demo database."""

import json

from load_raw_to_postgres import TABLE_FILES, create_db_engine, main
from sqlalchemy import text


def snapshot():
    engine = create_db_engine()
    try:
        with engine.connect() as conn:
            result = {
                name: tuple(
                    conn.execute(
                        text(
                            f"select count(*), md5(coalesce(string_agg(row_to_json(t)::text, '' order by row_to_json(t)::text), '')) from raw.{name} t"
                        )
                    ).one()
                )
                for name in TABLE_FILES
            }
        return result
    finally:
        engine.dispose()


if __name__ == "__main__":
    before = snapshot()
    main()
    assert snapshot() == before, "Raw contents changed on reload"
    engine = create_db_engine()
    try:
        with engine.connect() as conn:
            assert (
                conn.execute(
                    text("select count(*) from staging.stg_crm__accounts")
                ).scalar_one()
                > 0
            )
    finally:
        engine.dispose()
    print(json.dumps({"raw_reload": "passed", "tables": len(TABLE_FILES)}))
