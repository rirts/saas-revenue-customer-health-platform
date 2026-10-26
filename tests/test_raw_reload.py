"""Exercise the actual loader with dependent views and transactional rollback."""
import pandas as pd
import pytest
from sqlalchemy import create_engine, text
from scripts import load_raw_to_postgres as loader

@pytest.fixture
def database(tmp_path, monkeypatch):
    monkeypatch.setattr(loader, "DATA_DIR", tmp_path)
    engine = create_engine("sqlite://")
    with engine.begin() as conn:
        conn.execute(text("ATTACH DATABASE ':memory:' AS raw"))
    pd.DataFrame({"account_id": ["old"]}).to_csv(tmp_path / "accounts.csv", index=False)
    pd.DataFrame({"contact_id": ["old"]}).to_csv(tmp_path / "contacts.csv", index=False)
    with engine.begin() as conn:
        loader.load_table(conn, "crm_accounts", "accounts.csv")
        loader.load_table(conn, "crm_contacts", "contacts.csv")
        conn.execute(text("CREATE VIEW raw.account_view AS SELECT * FROM crm_accounts"))
    yield engine, tmp_path
    engine.dispose()

def test_reload_preserves_dependent_view(database):
    engine, root = database
    pd.DataFrame({"account_id": ["new"]}).to_csv(root / "accounts.csv", index=False)
    with engine.begin() as conn:
        loader.load_table(conn, "crm_accounts", "accounts.csv")
    with engine.connect() as conn:
        assert conn.execute(text("SELECT * FROM raw.account_view")).all() == [("new",)]

def test_failure_in_later_source_rolls_back_previous_source(database):
    engine, root = database
    pd.DataFrame({"account_id": ["new"]}).to_csv(root / "accounts.csv", index=False)
    pd.DataFrame({"unexpected_column": ["bad"]}).to_csv(root / "contacts.csv", index=False)
    with pytest.raises(Exception):
        with engine.begin() as conn:
            loader.load_table(conn, "crm_accounts", "accounts.csv")
            loader.load_table(conn, "crm_contacts", "contacts.csv")
    with engine.connect() as conn:
        assert conn.execute(text("SELECT * FROM raw.account_view")).all() == [("old",)]
        assert conn.execute(text("SELECT * FROM raw.crm_contacts")).all() == [("old",)]
