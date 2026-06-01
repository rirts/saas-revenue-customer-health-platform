create schema if not exists monitoring;

create table if not exists monitoring.pipeline_run_audit (
    run_id text primary key,
    pipeline_name text not null,
    started_at timestamptz not null,
    finished_at timestamptz,
    status text not null,
    total_duration_seconds numeric(18, 2),
    error_message text,
    created_at timestamptz not null default now()
);

create table if not exists monitoring.pipeline_stage_audit (
    audit_id bigserial primary key,
    run_id text not null,
    pipeline_name text not null,
    stage_name text not null,
    started_at timestamptz not null,
    finished_at timestamptz,
    duration_seconds numeric(18, 2),
    status text not null,
    error_message text,
    created_at timestamptz not null default now()
);

create index if not exists idx_pipeline_stage_audit_run_id
    on monitoring.pipeline_stage_audit (run_id);

create index if not exists idx_pipeline_stage_audit_stage_name
    on monitoring.pipeline_stage_audit (stage_name);

create index if not exists idx_pipeline_stage_audit_status
    on monitoring.pipeline_stage_audit (status);