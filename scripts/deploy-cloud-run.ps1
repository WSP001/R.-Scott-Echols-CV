# deploy-cloud-run.ps1
# WSP001 — One-command Cloud Run deploy from Windows (Ryzen AI 9 HX 370)
# FOR THE COMMONS GOOD — reusable across WSP001 repos
#
# Prerequisites:
#   1. Google Cloud SDK installed: https://cloud.google.com/sdk/docs/install
#   2. Docker Desktop running
#   3. gcloud auth login (run once)
#   4. gcloud config set project YOUR_PROJECT_ID
#
# Usage:
#   cd C:\WSP001\R.-Scott-Echols-CV
#   .\scripts\deploy-cloud-run.ps1
#
# OR with explicit project:
#   .\scripts\deploy-cloud-run.ps1 -ProjectId "wsp001-prod"

param(
    [string]$ProjectId = "",
    [string]$Region = "us-central1",
    [string]$ServiceName = "rse-retrieval",
    [switch]$SkipBuild = $false
)

$ErrorActionPreference = "Stop"

# ── Helpers ───────────────────────────────────────────────────────────────────
function Write-Step { param($msg) Write-Host "`n[DEPLOY] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  → $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red; exit 1 }

# ── Detect project ID ─────────────────────────────────────────────────────────
if (-not $ProjectId) {
    $ProjectId = (gcloud config get-value project 2>$null).Trim()
    if (-not $ProjectId) {
        Write-Fail "No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
    }
}

$ImageName = "gcr.io/$ProjectId/$ServiceName"

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host " WSP001 Cloud Run Deploy" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "  Project:  $ProjectId"
Write-Host "  Region:   $Region"
Write-Host "  Service:  $ServiceName"
Write-Host "  Image:    $ImageName"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta

# ── Step 1: Check prerequisites ───────────────────────────────────────────────
Write-Step "Checking prerequisites"

if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Fail "gcloud not found. Install: https://cloud.google.com/sdk/docs/install"
}
Write-OK "gcloud found"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Fail "Docker not found. Install Docker Desktop."
}
Write-OK "docker found"

# Check env vars
if (-not $env:GEMINI_API_KEY) {
    Write-Warn "GEMINI_API_KEY not set locally — will use Cloud Run secret"
}
if (-not $env:INGEST_SECRET) {
    Write-Warn "INGEST_SECRET not set locally — will use Cloud Run secret"
}

# ── Step 2: Build Docker image ─────────────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Step "Building Docker image"
    
    # Run from repo root (Dockerfile copies scripts/ and docs/)
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    Push-Location $RepoRoot
    
    docker build -t $ServiceName -f scripts/Dockerfile .
    if ($LASTEXITCODE -ne 0) { Write-Fail "Docker build failed" }
    Write-OK "Image built: $ServiceName"
    
    Pop-Location
}

# ── Step 3: Configure Container Registry ──────────────────────────────────────
Write-Step "Configuring Container Registry auth"
gcloud auth configure-docker --quiet
if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to configure Docker auth" }
Write-OK "Container Registry auth configured"

# ── Step 4: Tag and push image ─────────────────────────────────────────────────
Write-Step "Pushing image to Container Registry"
docker tag $ServiceName $ImageName
docker push $ImageName
if ($LASTEXITCODE -ne 0) { Write-Fail "Docker push failed" }
Write-OK "Image pushed: $ImageName"

# ── Step 5: Deploy to Cloud Run ────────────────────────────────────────────────
Write-Step "Deploying to Cloud Run"

$DeployArgs = @(
    "run", "deploy", $ServiceName,
    "--image", $ImageName,
    "--region", $Region,
    "--platform", "managed",
    "--allow-unauthenticated",    # Netlify edge functions call this publicly
    "--memory", "512Mi",
    "--cpu", "1",
    "--min-instances", "0",       # Scale to zero between requests
    "--max-instances", "10",
    "--timeout", "30",
    "--concurrency", "80",
    "--port", "8080",
    "--quiet"
)

# Set secrets if available in Secret Manager
$SecretsArg = ""
$Secrets = @()
if (gcloud secrets describe GEMINI_API_KEY --project=$ProjectId 2>$null) {
    $Secrets += "GEMINI_API_KEY=GEMINI_API_KEY:latest"
    Write-OK "Using Secret Manager: GEMINI_API_KEY"
}
if (gcloud secrets describe INGEST_SECRET --project=$ProjectId 2>$null) {
    $Secrets += "INGEST_SECRET=INGEST_SECRET:latest"
    Write-OK "Using Secret Manager: INGEST_SECRET"
}
if ($Secrets.Count -gt 0) {
    $DeployArgs += "--set-secrets"
    $DeployArgs += ($Secrets -join ",")
}

gcloud @DeployArgs
if ($LASTEXITCODE -ne 0) { Write-Fail "Cloud Run deploy failed" }

# ── Step 6: Get service URL ────────────────────────────────────────────────────
Write-Step "Getting service URL"
$ServiceUrl = (gcloud run services describe $ServiceName --region=$Region --format="value(status.url)" 2>$null).Trim()

if (-not $ServiceUrl) {
    Write-Warn "Could not auto-detect service URL — check Cloud Run console"
} else {
    Write-OK "Service URL: $ServiceUrl"
}

# ── Step 7: Health check ───────────────────────────────────────────────────────
Write-Step "Running health check"

if ($ServiceUrl) {
    $HealthUrl = "$ServiceUrl/health"
    try {
        $Response = Invoke-RestMethod -Uri $HealthUrl -Method GET -TimeoutSec 15
        if ($Response.status -eq "ok") {
            Write-OK "Health check passed: $HealthUrl"
            Write-OK "Chunks in DB: $($Response.chunks)"
        } else {
            Write-Warn "Health check returned: $($Response.status) — $($Response.error)"
        }
    } catch {
        Write-Warn "Health check request failed — service may still be starting"
    }
}

# ── Step 8: Print Netlify env var instruction ──────────────────────────────────
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host " NEXT STEP: Add to Netlify Environment Variables" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Key:   VECTOR_ENGINE_URL"
Write-Host "  Value: $ServiceUrl"
Write-Host ""
Write-Host "  Go to: Netlify → Site Settings → Environment Variables"
Write-Host "  Set team-level so all edge functions inherit it."
Write-Host ""
Write-Host "  Then redeploy Netlify (or trigger via git push) to activate RAG." -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host " ✓ DEPLOY COMPLETE" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
