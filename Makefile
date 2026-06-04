# Optional developer shortcuts for Unix-like environments, WSL, Git Bash, or systems with GNU Make installed.
# Windows users can run the equivalent PowerShell and Python commands documented in the README.

.PHONY: install docker-up docker-down generate load-raw validate-raw dbt-deps dbt-build dbt-test dbt-docs ruff sqlfluff lint pipeline clean-dbt

install:
	pip install -r requirements.txt

docker-up:
	docker compose up -d

docker-down:
	docker compose down

generate:
	python scripts/generate_synthetic_data.py

load-raw:
	python scripts/load_raw_to_postgres.py

validate-raw:
	python scripts/validate_raw_data.py

dbt-deps:
	dbt deps --project-dir warehouse/dbt --profiles-dir warehouse/dbt

dbt-build:
	dbt build --project-dir warehouse/dbt --profiles-dir warehouse/dbt

dbt-test:
	dbt test --project-dir warehouse/dbt --profiles-dir warehouse/dbt

dbt-docs:
	dbt docs generate --project-dir warehouse/dbt --profiles-dir warehouse/dbt

ruff:
	ruff check scripts
	ruff check orchestration/airflow/dags
	ruff format scripts --check
	ruff format orchestration/airflow/dags --check

sqlfluff:
	sqlfluff lint warehouse/dbt/models
	sqlfluff lint warehouse/dbt/tests

lint: ruff sqlfluff

pipeline:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -SkipDocker -SkipDocs

clean-dbt:
	if exist warehouse\dbt\target rmdir /s /q warehouse\dbt\target
	if exist warehouse\dbt\dbt_packages rmdir /s /q warehouse\dbt\dbt_packages