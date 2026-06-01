param(
    [switch]$SkipDocker,
    [switch]$SkipDocs
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Invoke-CheckedCommand {
    param(
        [string]$Description,
        [scriptblock]$Command
    )

    Write-Step $Description

    try {
        & $Command

        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            throw "Command failed with exit code $LASTEXITCODE"
        }

        Write-Host "SUCCESS: $Description"
    }
    catch {
        Write-Host "FAILED: $Description"
        Write-Host $_
        exit 1
    }
}

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectRoot

Write-Host "Project root: $ProjectRoot"

if (-not $SkipDocker) {
    Invoke-CheckedCommand "Checking Docker availability" {
        docker version
    }

    Invoke-CheckedCommand "Starting Docker Compose services" {
        docker compose up -d
    }

    Invoke-CheckedCommand "Checking running containers" {
        docker ps
    }
}

Invoke-CheckedCommand "Generating synthetic source data" {
    python scripts\generate_synthetic_data.py
}

Invoke-CheckedCommand "Resetting dbt-managed schemas before raw reload" {
    docker exec saas_platform_postgres psql `
        -U analytics `
        -d saas_platform `
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

if (-not $SkipDocs) {
    Invoke-CheckedCommand "Generating dbt documentation" {
        dbt docs generate --project-dir warehouse\dbt --profiles-dir warehouse\dbt
    }
}

Write-Step "Pipeline completed successfully"

Write-Host "Metabase:"
Write-Host "http://localhost:3001"
Write-Host ""
Write-Host "dbt docs:"
Write-Host "Run: dbt docs serve --project-dir warehouse\dbt --profiles-dir warehouse\dbt"