param(
    [switch]$SkipDocker,
    [switch]$SkipDocs
)

$ErrorActionPreference = "Stop"

$PipelineName = "saas_revenue_customer_health_platform"
$RunId = [guid]::NewGuid().ToString()
$PipelineStartedAt = Get-Date
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

Set-Location $ProjectRoot

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Convert-ToSqlText {
    param(
        [string]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return $Value.Replace("'", "''")
}

function Invoke-PostgresSql {
    param(
        [string]$Sql
    )

    $Sql | docker exec -i saas_platform_postgres psql `
        -U analytics `
        -d saas_platform `
        -v ON_ERROR_STOP=1
}

function Initialize-MonitoringTables {
    Write-Step "Initializing monitoring tables"

    Get-Content scripts\create_monitoring_tables.sql -Raw | docker exec -i saas_platform_postgres psql `
        -U analytics `
        -d saas_platform `
        -v ON_ERROR_STOP=1

    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        throw "Failed to initialize monitoring tables"
    }

    Write-Host "SUCCESS: Monitoring tables initialized"
}

function Start-PipelineRun {
    $Sql = @"
insert into monitoring.pipeline_run_audit (
    run_id,
    pipeline_name,
    started_at,
    status
)
values (
    '$RunId',
    '$PipelineName',
    now(),
    'running'
);
"@

    Invoke-PostgresSql $Sql
}

function Complete-PipelineRun {
    param(
        [string]$Status,
        [string]$ErrorMessage = ""
    )

    $PipelineFinishedAt = Get-Date
    $TotalDurationSeconds = [math]::Round(($PipelineFinishedAt - $PipelineStartedAt).TotalSeconds, 2)
    $SafeErrorMessage = Convert-ToSqlText $ErrorMessage

    $Sql = @"
update monitoring.pipeline_run_audit
set
    finished_at = now(),
    status = '$Status',
    total_duration_seconds = $TotalDurationSeconds,
    error_message = nullif('$SafeErrorMessage', '')
where run_id = '$RunId';
"@

    Invoke-PostgresSql $Sql
}

function Start-PipelineStage {
    param(
        [string]$StageName
    )

    $SafeStageName = Convert-ToSqlText $StageName

    $Sql = @"
insert into monitoring.pipeline_stage_audit (
    run_id,
    pipeline_name,
    stage_name,
    started_at,
    status
)
values (
    '$RunId',
    '$PipelineName',
    '$SafeStageName',
    now(),
    'running'
);
"@

    Invoke-PostgresSql $Sql
}

function Complete-PipelineStage {
    param(
        [string]$StageName,
        [string]$Status,
        [decimal]$DurationSeconds,
        [string]$ErrorMessage = ""
    )

    $SafeStageName = Convert-ToSqlText $StageName
    $SafeErrorMessage = Convert-ToSqlText $ErrorMessage

    $Sql = @"
update monitoring.pipeline_stage_audit
set
    finished_at = now(),
    duration_seconds = $DurationSeconds,
    status = '$Status',
    error_message = nullif('$SafeErrorMessage', '')
where audit_id = (
    select audit_id
    from monitoring.pipeline_stage_audit
    where run_id = '$RunId'
      and stage_name = '$SafeStageName'
      and status = 'running'
    order by started_at desc
    limit 1
);
"@

    Invoke-PostgresSql $Sql
}

function Invoke-CheckedCommand {
    param(
        [string]$Description,
        [scriptblock]$Command
    )

    Write-Step $Description
    Start-PipelineStage $Description

    $StageStartedAt = Get-Date

    try {
        & $Command

        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            throw "Command failed with exit code $LASTEXITCODE"
        }

        $StageFinishedAt = Get-Date
        $DurationSeconds = [math]::Round(($StageFinishedAt - $StageStartedAt).TotalSeconds, 2)

        Complete-PipelineStage `
            -StageName $Description `
            -Status "success" `
            -DurationSeconds $DurationSeconds

        Write-Host "SUCCESS: $Description"
    }
    catch {
        $StageFinishedAt = Get-Date
        $DurationSeconds = [math]::Round(($StageFinishedAt - $StageStartedAt).TotalSeconds, 2)
        $ErrorMessage = $_.Exception.Message

        Complete-PipelineStage `
            -StageName $Description `
            -Status "failed" `
            -DurationSeconds $DurationSeconds `
            -ErrorMessage $ErrorMessage

        Complete-PipelineRun `
            -Status "failed" `
            -ErrorMessage "Stage failed: $Description. $ErrorMessage"

        Write-Host "FAILED: $Description"
        Write-Host $ErrorMessage
        Write-Host ""
        Write-Host "Pipeline run_id: $RunId"

        exit 1
    }
}

Write-Host "Project root: $ProjectRoot"
Write-Host "Pipeline run_id: $RunId"

if (-not $SkipDocker) {
    Write-Step "Checking Docker availability"
    docker version

    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        throw "Docker is not available"
    }

    Write-Step "Starting Docker Compose services"
    docker compose up -d

    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        throw "Docker Compose failed"
    }

    Write-Step "Checking running containers"
    docker ps
}

Initialize-MonitoringTables
Start-PipelineRun

Invoke-CheckedCommand "Generating synthetic source data" {
    python scripts\generate_synthetic_data.py
}

Invoke-CheckedCommand "Resetting dbt-managed schemas before raw reload" {
    docker exec saas_platform_postgres psql `
        -U analytics `
        -d saas_platform `
        -v ON_ERROR_STOP=1 `
        -c "drop schema if exists staging cascade; drop schema if exists intermediate cascade; drop schema if exists marts cascade; create schema if not exists staging; create schema if not exists intermediate; create schema if not exists marts;"
}

Invoke-CheckedCommand "Loading raw data into PostgreSQL" {
    python scripts\load_raw_to_postgres.py
}

Invoke-CheckedCommand "Validating raw data quality" {
    python scripts\validate_raw_data.py
}

Invoke-CheckedCommand "Installing dbt dependencies" {
    dbt deps --project-dir warehouse\dbt --profiles-dir warehouse\dbt
}

Invoke-CheckedCommand "Running dbt build" {
    dbt build --project-dir warehouse\dbt --profiles-dir warehouse\dbt
}

Invoke-CheckedCommand "Collecting warehouse row counts" {
    python scripts\collect_table_row_counts.py --run-id $RunId
}

if (-not $SkipDocs) {
    Invoke-CheckedCommand "Generating dbt documentation" {
        dbt docs generate --project-dir warehouse\dbt --profiles-dir warehouse\dbt
    }
}

Complete-PipelineRun -Status "success"

Write-Step "Pipeline completed successfully"

Write-Host "Pipeline run_id: $RunId"
Write-Host ""
Write-Host "Metabase:"
Write-Host "http://localhost:3001"
Write-Host ""
Write-Host "dbt docs:"
Write-Host "Run: dbt docs serve --project-dir warehouse\dbt --profiles-dir warehouse\dbt"