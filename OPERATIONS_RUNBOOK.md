# Operations Runbook

## SaaS Revenue & Customer Health Platform

This runbook describes how to operate, validate, and troubleshoot the SaaS Revenue & Customer Health Platform.

---

## 1. Local Pipeline Execution

To run the full local pipeline:

```bash
.\scripts\run_pipeline.ps1
```

To run the pipeline without starting Docker:

```bash
.\scripts\run_pipeline.ps1 -SkipDocker
```

To skip dbt documentation generation:

```bash
.\scripts\run_pipeline.ps1 -SkipDocker -SkipDocs
```

The pipeline executes:

1. Synthetic data generation
2. Raw data loading into PostgreSQL
3. Raw data quality validation
4. dbt dependency installation
5. dbt build
6. Warehouse row-count collection
7. Optional dbt documentation generation

---

## 2. Service Health Checks

Start services:

```powershell
docker compose up -d
```

Check running containers:

```powershell
docker ps
```

Expected services:

- `saas_platform_postgres`
- `saas_platform_metabase`

PostgreSQL should be available on:

```text
localhost:5432
```

Metabase should be available on:

```text
http://localhost:3001
```

---

## 3. Pipeline Monitoring Tables

The pipeline writes execution metadata to the `monitoring` schema.

### Pipeline run audit

```sql
select *
from monitoring.pipeline_run_audit
order by started_at desc
limit 10;
```

Use this table to inspect:

- Pipeline run ID
- Start time
- Finish time
- Final status
- Total duration
- Error message, if any

### Pipeline stage audit

```sql
select *
from monitoring.pipeline_stage_audit
order by started_at desc
limit 20;
```

Use this table to inspect:

- Stage name
- Stage duration
- Stage status
- Stage-level error messages

### Raw load audit

```sql
select *
from monitoring.raw_load_audit
order by loaded_at desc
limit 20;
```

Use this table to inspect:

- Raw tables loaded
- Row counts by table
- Load timestamps

### Warehouse row-count audit

```sql
select
    run_id,
    schema_name,
    relation_name,
    relation_type,
    row_count,
    observed_at
from monitoring.table_row_count_audit
order by observed_at desc, schema_name, relation_name
limit 50;
```

Use this table to validate row counts across:

- `raw`
- `staging`
- `intermediate`
- `marts`

---

## 4. Recommended Validation Queries

### Latest pipeline status

```sql
select
    run_id,
    pipeline_name,
    started_at,
    finished_at,
    status,
    total_duration_seconds,
    error_message
from monitoring.pipeline_run_audit
order by started_at desc
limit 5;
```

### Latest stage durations

```sql
select
    stage_name,
    status,
    duration_seconds,
    error_message
from monitoring.pipeline_stage_audit
where run_id = (
    select run_id
    from monitoring.pipeline_run_audit
    order by started_at desc
    limit 1
)
order by started_at;
```

### Latest row counts by schema

```sql
select
    schema_name,
    count(*) as relations_observed,
    sum(row_count) as total_rows_observed
from monitoring.table_row_count_audit
where observed_at = (
    select max(observed_at)
    from monitoring.table_row_count_audit
)
group by schema_name
order by schema_name;
```

---

## 5. dbt Validation

Run all dbt tests:

```powershell
dbt test --project-dir warehouse\dbt --profiles-dir warehouse\dbt
```

Run only data contract tests:

```powershell
dbt test --project-dir warehouse\dbt --profiles-dir warehouse\dbt --select tag:data_contract
```

Run the full dbt build:

```powershell
dbt build --project-dir warehouse\dbt --profiles-dir warehouse\dbt
```

Generate dbt docs:

```powershell
dbt docs generate --project-dir warehouse\dbt --profiles-dir warehouse\dbt
```

Serve dbt docs locally:

```powershell
dbt docs serve --project-dir warehouse\dbt --profiles-dir warehouse\dbt
```

---

## 6. Common Failure Scenarios

### PostgreSQL connection fails

Check that Docker services are running:

```powershell
docker ps
```

Restart services:

```powershell
docker compose up -d
```

### Raw load fails because downstream views depend on raw tables

Run the full pipeline instead of the raw loader directly:

```powershell
.\scripts\run_pipeline.ps1 -SkipDocker -SkipDocs
```

The pipeline resets dbt-managed schemas before reloading raw data.

### dbt build fails

Run:

```powershell
dbt debug --project-dir warehouse\dbt --profiles-dir warehouse\dbt
dbt deps --project-dir warehouse\dbt --profiles-dir warehouse\dbt
dbt build --project-dir warehouse\dbt --profiles-dir warehouse\dbt
```

Then inspect the failing model or test from the dbt output.

### GitHub Actions fails but local pipeline passes

Check:

1. Dependency versions in `requirements.txt`
2. Environment variables in `.github/workflows/ci.yml`
3. PostgreSQL service health in the CI logs
4. dbt version and adapter version in the CI output

---

## 7. Production Readiness Notes

Implemented:

- End-to-end CI validation
- Local reproducible pipeline runner
- Pipeline-level audit logging
- Stage-level audit logging
- Raw ingestion audit logging
- Warehouse row-count observability
- dbt data tests
- dbt business logic tests
- dbt data contract tests

Recommended future improvements:

- Airflow DAG orchestration
- Python linting with Ruff
- SQL linting with SQLFluff
- Alert thresholds for failed runs or unexpected row-count changes
- dbt docs artifact publishing from CI