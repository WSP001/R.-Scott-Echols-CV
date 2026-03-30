# setup-pgvector.ps1 — WSP001 One-shot pgvector activation
# FOR THE COMMONS GOOD — reusable across WSP001 repos
#
# Run this ONCE after you have a Supabase (or any PostgreSQL+pgvector) connection string.
# It will:
#   1. Store DATABASE_URL in GCP Secret Manager
#   2. Rebuild + redeploy Cloud Run so it boots on the latest pgvector-capable image
#   3. Re-ingest the full corpus into pgvector
#   4. Run verify-vector.ps1 to confirm chunks are live
#
# Usage:
#   .\scripts\setup-pgvector.ps1 -DatabaseUrl "postgresql://postgres:PASSWORD@db.xxx.supabase.co:5432/postgres"
#
# Get your Supabase connection string:
#   supabase.com → your project → Settings → Database → Connection string → URI
#   Make sure to replace [YOUR-PASSWORD] with your actual DB password.
#
# Architecture: Scott Echols / WSP001 — Commons Good
# Engineering:  Claude Sonnet 4.6

param(
    [Parameter(Mandatory=$true)]
    [string]$DatabaseUrl,
    [string]$ProjectId = "worldseafood-project-001",
    [string]$Region    = "us-central1",
    [string]$Service   = "rse-retrieval",
    [string]$VectorUrl = "",
    [string]$IngestSecret = $env:INGEST_SECRET
)

$ErrorActionPreference = "Stop"

function Write-Step { param($msg) Write-Host "`n[SETUP] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  OK    $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  FAIL  $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "  INFO  $msg" -ForegroundColor Gray }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host " WSP001 pgvector One-Shot Activation" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta

# Validate URL looks like a postgres connection string
if ($DatabaseUrl -notmatch '^postgresql://') {
    Write-Fail "DATABASE_URL must start with postgresql://"
    Write-Info "Get it from: supabase.com → your project → Settings → Database → URI"
    exit 1
}

if (-not $IngestSecret) {
    $IngestSecret = "1ef718866b5440ad842a0d87c19a12e1"
    Write-Info "Using known INGEST_SECRET from this session"
}

# ── Step 1: Store DATABASE_URL in GCP Secret Manager ─────────────────────────
Write-Step "1/4 — Storing DATABASE_URL in GCP Secret Manager"
try {
    # Check if secret already exists
    $exists = gcloud secrets describe DATABASE_URL --project=$ProjectId 2>$null
    if ($exists) {
        Write-Info "Secret DATABASE_URL already exists — adding new version"
        $DatabaseUrl | gcloud secrets versions add DATABASE_URL --project=$ProjectId --data-file=-
    } else {
        $DatabaseUrl | gcloud secrets create DATABASE_URL --project=$ProjectId --data-file=-
    }
    Write-OK "DATABASE_URL stored in Secret Manager"
} catch {
    Write-Fail "Failed to store secret: $_"
    exit 1
}

# ── Step 2: Redeploy Cloud Run with DATABASE_URL secret ──────────────────────
Write-Step "2/4 — Rebuilding and redeploying Cloud Run with pgvector backend"
try {
    & "$PSScriptRoot\deploy-cloud-run.ps1" `
        -ProjectId $ProjectId `
        -Region $Region `
        -ServiceName $Service
    Write-OK "Cloud Run redeployed from the latest image with DATABASE_URL available"
} catch {
    Write-Fail "Cloud Run redeploy failed: $_"
    exit 1
}

# Resolve the live service URL after redeploy so ingest and verification hit the
# current Cloud Run endpoint, not a stale hardcoded hostname.
try {
    $ResolvedUrl = (
        gcloud run services describe $Service `
            --region=$Region `
            --format="value(status.url)" 2>$null
    ).Trim()
    if ($ResolvedUrl) {
        $VectorUrl = $ResolvedUrl
        Write-Info "Using live service URL: $VectorUrl"
    } elseif (-not $VectorUrl) {
        Write-Fail "Could not resolve the Cloud Run service URL after redeploy"
        exit 1
    }
} catch {
    if (-not $VectorUrl) {
        Write-Fail "Could not resolve the Cloud Run service URL: $_"
        exit 1
    }
}

# Wait for revision to stabilize
Write-Info "Waiting 10s for new revision to stabilize..."
Start-Sleep -Seconds 10

# ── Step 3: Confirm backend switched to pgvector ─────────────────────────────
Write-Step "3/4 — Confirming pgvector backend is active"
try {
    $health = Invoke-RestMethod -Uri "$VectorUrl/health" -Method GET -TimeoutSec 20
    if ($health.backend -eq "pgvector") {
        Write-OK "Backend: pgvector — durable: $($health.durable)"
        Write-Info "Chunks in pgvector DB: $($health.chunks)"
    } elseif ($health.backend -eq "chroma") {
        Write-Fail "Still on Chroma — DATABASE_URL may not have been picked up yet"
        Write-Info "Try: gcloud run services describe $Service --region $Region --format=json | ConvertFrom-Json | Select-Object -ExpandProperty spec"
        exit 1
    } else {
        Write-Info "Health response: $($health | ConvertTo-Json)"
    }
} catch {
    Write-Fail "Health check failed: $_"
    exit 1
}

# ── Step 4: Re-ingest corpus into pgvector ────────────────────────────────────
Write-Step "4/4 — Ingesting corpus into pgvector"
$env:VECTOR_ENGINE_URL = $VectorUrl
$env:INGEST_SECRET     = $IngestSecret
python scripts\embed_engine.py --from-manifest
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Ingest failed — check output above"
    exit 1
}

# ── Final health check ────────────────────────────────────────────────────────
Write-Host ""
$final = Invoke-RestMethod -Uri "$VectorUrl/health" -Method GET -TimeoutSec 15
Write-Host "==========================================" -ForegroundColor Magenta
Write-Host " RESULT: $($final.chunks) chunks in pgvector" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Magenta

if ($final.chunks -gt 0) {
    Write-Step "Verification — Running verify-vector.ps1"
    pwsh -File "$PSScriptRoot\verify-vector.ps1" -Url $VectorUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "verify-vector.ps1 failed — investigate the vector service before wiring Netlify"
        exit 1
    }

    Write-Host ""
    Write-Host "  pgvector is LIVE and durable." -ForegroundColor Green
    Write-Host "  Chunks survive Cloud Run restarts." -ForegroundColor Green
    Write-Host ""
    Write-Host "  NEXT: Set VECTOR_ENGINE_URL in Netlify (if not already done):" -ForegroundColor Yellow
    Write-Host "    Key:   VECTOR_ENGINE_URL" -ForegroundColor White
    Write-Host "    Value: $VectorUrl" -ForegroundColor White
    Write-Host ""
    Write-Host "  Then run: pwsh -File .\scripts\cv-smoke.ps1" -ForegroundColor Yellow
} else {
    Write-Fail "Chunks still 0 — ingest may have failed. Check output above."
}
Write-Host ""
