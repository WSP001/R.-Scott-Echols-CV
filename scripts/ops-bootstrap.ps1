#Requires -Version 7.0
<#
.SYNOPSIS
  ops-bootstrap — take the WSP001 chatbot stack from "credentials in hand" to
  "G2 green" in one non-interactive run. Idempotent; safe to re-run.

.DESCRIPTION
  Executes §9 steps 3-5 of the 2026-09-05 Engineering Execution Plan plus the F7
  secret-hygiene fix. Every stage is skippable so an agent can resume after a
  partial failure. Secrets are read from environment variables ONLY and are
  never echoed, logged, or written to disk.

  Required env (set these in the shell, or in your secret manager -> shell bridge):
    WSP001_DATABASE_URL        postgresql://... with pgvector available (Netlify DB / Neon / Supabase)
    WSP001_GEMINI_API_KEY      freshly rotated (the previous value was exposed as plaintext env - F7)
    WSP001_ANTHROPIC_API_KEY   freshly rotated (production /api/chat is 502 on the old one - F6)
  Optional env:
    WSP001_INGEST_SECRET       if absent a 32-hex random value is generated and stored
    WSP001_LINKEDIN_CSV        path to the LinkedIn "Shares.csv" export -> ingests linkedin_history
    WSP001_GCP_PROJECT         default worldseafood-project-001
    WSP001_GCP_REGION          default us-central1
    WSP001_NETLIFY_SITE_ID     default 56cfb2da-8997-47bd-a822-604771a64f3c (robertoscottecholscv)

  Stages (in order):
    1 preflight   tools present + authenticated; repo on main and clean
    2 secrets     upsert GEMINI_API_KEY / INGEST_SECRET / DATABASE_URL into GCP Secret Manager,
                  grant the Cloud Run service account secretAccessor
    3 cloudrun    build + deploy via scripts/deploy-cloud-run.ps1 (Secret Manager refs only,
                  VECTOR_STORE_BACKEND=pgvector) ; wait for /health status=ok backend=pgvector
    4 ingest      python scripts/embed_engine.py --from-manifest  (remote mode -> Cloud Run /ingest)
                  + node scripts/ingest-linkedin-posts.mjs --csv $WSP001_LINKEDIN_CSV  (if provided)
    5 netlify     env:set ANTHROPIC_API_KEY + VECTOR_ENGINE_URL, trigger a clear-cache production
                  build from git main, wait for state=ready
    6 verify      just keys-verify grounded=1   (exit 0 == chat HTTP 200 AND rag_status=ok == G2)

.PARAMETER Skip
  Stage names to skip, e.g. -Skip secrets,cloudrun to only re-ingest and verify.
.PARAMETER Only
  Run just these stages.
.PARAMETER DryRun
  Print what would run. Nothing is mutated.

.EXAMPLE
  $env:WSP001_DATABASE_URL = '...'; $env:WSP001_GEMINI_API_KEY = '...'; $env:WSP001_ANTHROPIC_API_KEY = '...'
  pwsh -File scripts/ops-bootstrap.ps1
.EXAMPLE
  pwsh -File scripts/ops-bootstrap.ps1 -Only ingest,verify
#>
param(
  [string[]]$Skip = @(),
  [string[]]$Only = @(),
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Project = if ($env:WSP001_GCP_PROJECT) { $env:WSP001_GCP_PROJECT } else { 'worldseafood-project-001' }
$Region  = if ($env:WSP001_GCP_REGION)  { $env:WSP001_GCP_REGION }  else { 'us-central1' }
$SiteId  = if ($env:WSP001_NETLIFY_SITE_ID) { $env:WSP001_NETLIFY_SITE_ID } else { '56cfb2da-8997-47bd-a822-604771a64f3c' }
$Service = 'rse-retrieval'
$Stages  = 'preflight', 'secrets', 'cloudrun', 'ingest', 'netlify', 'verify'

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function OK($msg)   { Write-Host "  OK    $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "  ..    $msg" -ForegroundColor Gray }
function Die($msg)  { Write-Host "  FAIL  $msg" -ForegroundColor Red; exit 1 }
function Runs($stage) {
  if ($Only.Count -gt 0) { return $Only -contains $stage }
  return -not ($Skip -contains $stage)
}
function Need-Env($name) {
  $v = [Environment]::GetEnvironmentVariable($name)
  if (-not $v) { Die "$name is not set. This script reads secrets from env only; nothing is prompted or hardcoded." }
  return $v
}
function Upsert-Secret($name, $value) {
  if ($DryRun) { Info "would upsert Secret Manager: $name"; return }
  $exists = gcloud secrets describe $name --project $Project 2>$null
  if ($exists) { $value | gcloud secrets versions add $name --project $Project --data-file=- | Out-Null }
  else         { $value | gcloud secrets create $name --project $Project --replication-policy automatic --data-file=- | Out-Null }
  if ($LASTEXITCODE -ne 0) { Die "Secret Manager write failed for $name" }
  OK "$name stored (Secret Manager, version latest)"
}

# ── 1 preflight ───────────────────────────────────────────────────────────────
if (Runs 'preflight') {
  Step 1 'preflight'
  foreach ($t in 'gcloud', 'netlify', 'docker', 'python', 'node', 'just', 'git') {
    if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { Die "$t not on PATH" }
  }
  OK 'tools present'
  $acct = (gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>$null)
  if (-not $acct) { Die 'gcloud not authenticated: gcloud auth login' }
  OK "gcloud as $acct / project $Project"
  $nl = netlify status 2>&1 | Select-String 'Email:'
  if (-not $nl) { Die 'netlify not authenticated: netlify login' }
  OK "netlify $($nl.Line.Trim())"
  docker info 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { Die 'Docker daemon not running (needed to build the Cloud Run image)' }
  OK 'docker daemon up'
  $branch = git rev-parse --abbrev-ref HEAD
  if ($branch -ne 'main') { Die "on branch '$branch' - deploy from main only" }
  if (git status --porcelain) { Die 'working tree not clean - commit or stash first' }
  OK "repo on main @ $(git rev-parse --short HEAD), clean"
  python scripts/truth_audit.py | Out-Null
  if ($LASTEXITCODE -ne 0) { Die 'truth_audit.py FAIL - fix before deploying anything' }
  OK 'truth-audit PASS'
}

# ── 2 secrets ─────────────────────────────────────────────────────────────────
$IngestSecret = $env:WSP001_INGEST_SECRET
if (Runs 'secrets') {
  Step 2 'secrets -> GCP Secret Manager (F7: never plaintext env again)'
  $dbUrl  = Need-Env 'WSP001_DATABASE_URL'
  $gemini = Need-Env 'WSP001_GEMINI_API_KEY'
  if ($dbUrl -notmatch '^postgres(ql)?://') { Die 'WSP001_DATABASE_URL must be a postgresql:// DSN' }
  if (-not $IngestSecret) {
    $IngestSecret = -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    Info 'WSP001_INGEST_SECRET absent - generated a fresh 32-hex value (rotates the exposed one)'
  }
  Upsert-Secret 'DATABASE_URL'   $dbUrl
  Upsert-Secret 'GEMINI_API_KEY' $gemini
  Upsert-Secret 'INGEST_SECRET'  $IngestSecret
  if (-not $DryRun) {
    $sa = gcloud run services describe $Service --region $Region --project $Project --format 'value(spec.template.spec.serviceAccountName)' 2>$null
    if (-not $sa) { $pn = gcloud projects describe $Project --format 'value(projectNumber)'; $sa = "$pn-compute@developer.gserviceaccount.com" }
    foreach ($s in 'DATABASE_URL', 'GEMINI_API_KEY', 'INGEST_SECRET') {
      gcloud secrets add-iam-policy-binding $s --project $Project --member "serviceAccount:$sa" --role roles/secretmanager.secretAccessor --quiet 2>$null | Out-Null
    }
    OK "secretAccessor granted to $sa"
  }
} elseif (-not $IngestSecret -and (Runs 'ingest')) {
  if ($DryRun) { Info 'would read INGEST_SECRET from Secret Manager' }
  else {
    $IngestSecret = gcloud secrets versions access latest --secret INGEST_SECRET --project $Project 2>$null
    if (-not $IngestSecret) { Die 'INGEST_SECRET not in env and not in Secret Manager - run the secrets stage' }
    Info 'INGEST_SECRET read from Secret Manager for the ingest stage'
  }
}

# ── 3 cloudrun ────────────────────────────────────────────────────────────────
$VectorUrl = ''
if (Runs 'cloudrun') {
  Step 3 'cloudrun -> build image from main, deploy with Secret Manager refs, VECTOR_STORE_BACKEND=pgvector'
  if ($DryRun) { Info 'would run scripts/deploy-cloud-run.ps1' }
  else {
    & "$PSScriptRoot/deploy-cloud-run.ps1" -ProjectId $Project -Region $Region -ServiceName $Service
    if ($LASTEXITCODE -ne 0) { Die 'deploy-cloud-run.ps1 failed' }
  }
}
if (-not $DryRun) {
  $VectorUrl = (gcloud run services describe $Service --region $Region --project $Project --format 'value(status.url)' 2>$null).Trim()
  if (-not $VectorUrl) { Die 'could not resolve Cloud Run URL' }
  Info "service url $VectorUrl"
}
if ((Runs 'cloudrun') -and -not $DryRun) {
  $deadline = (Get-Date).AddMinutes(3); $h = $null
  do {
    Start-Sleep 5
    try { $h = Invoke-RestMethod -Uri "$VectorUrl/health" -TimeoutSec 20 } catch { $h = $null }
  } while ((-not $h -or $h.status -ne 'ok') -and (Get-Date) -lt $deadline)
  if (-not $h) { Die '/health unreachable after deploy' }
  if ($h.status -ne 'ok') { Die "/health status=$($h.status) error=$($h.error) - DATABASE_URL unreachable or vector extension unavailable on that database" }
  if ($h.backend -ne 'pgvector') { Die "/health backend=$($h.backend), expected pgvector" }
  OK "/health ok backend=pgvector durable=$($h.durable) chunks=$($h.chunks)"
  $p = Invoke-RestMethod -Uri "$VectorUrl/partitions" -TimeoutSec 20
  if (-not $p.partitions.linkedin_history) { Die '/partitions lacks linkedin_history - image was not built from current main' }
  OK '/partitions includes linkedin_history'
}

# ── 4 ingest ──────────────────────────────────────────────────────────────────
if (Runs 'ingest') {
  Step 4 'ingest -> corpus (manifest) + LinkedIn posts (if WSP001_LINKEDIN_CSV)'
  if ($DryRun) { Info 'would run embed_engine.py --from-manifest and ingest-linkedin-posts.mjs' }
  else {
    $env:VECTOR_ENGINE_URL = $VectorUrl
    $env:INGEST_SECRET     = $IngestSecret
    $env:GEMINI_API_KEY    = if ($env:WSP001_GEMINI_API_KEY) { $env:WSP001_GEMINI_API_KEY } else { gcloud secrets versions access latest --secret GEMINI_API_KEY --project $Project }
    try {
      python scripts/embed_engine.py --from-manifest
      if ($LASTEXITCODE -ne 0) { Die 'embed_engine.py --from-manifest failed' }
      OK 'manifest corpus ingested'
      if ($env:WSP001_LINKEDIN_CSV) {
        if (-not (Test-Path $env:WSP001_LINKEDIN_CSV)) { Die "WSP001_LINKEDIN_CSV not found: $env:WSP001_LINKEDIN_CSV" }
        node scripts/ingest-linkedin-posts.mjs --csv $env:WSP001_LINKEDIN_CSV
        if ($LASTEXITCODE -ne 0) { Die 'ingest-linkedin-posts.mjs failed' }
        OK 'linkedin_history ingested'
      } else {
        Info 'WSP001_LINKEDIN_CSV not set - skipping LinkedIn ingest (SirTrav voice pack stays empty until this runs)'
      }
    } finally {
      Remove-Item Env:\INGEST_SECRET, Env:\GEMINI_API_KEY -ErrorAction SilentlyContinue
    }
    $h = Invoke-RestMethod -Uri "$VectorUrl/health" -TimeoutSec 20
    if ($h.chunks -lt 1) { Die 'health reports 0 chunks after ingest' }
    OK "chunks in pgvector: $($h.chunks)"
  }
}

# ── 5 netlify ─────────────────────────────────────────────────────────────────
if (Runs 'netlify') {
  Step 5 'netlify -> env + clear-cache production build from git main'
  $anthropic = Need-Env 'WSP001_ANTHROPIC_API_KEY'
  if ($DryRun) { Info 'would netlify env:set ANTHROPIC_API_KEY, VECTOR_ENGINE_URL and trigger a clear-cache build' }
  else {
    netlify env:set ANTHROPIC_API_KEY $anthropic --secret --force 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Die 'netlify env:set ANTHROPIC_API_KEY failed (is the repo linked? netlify link)' }
    OK 'ANTHROPIC_API_KEY set (secret)'
    if ($VectorUrl) { netlify env:set VECTOR_ENGINE_URL $VectorUrl --force 2>&1 | Out-Null; OK "VECTOR_ENGINE_URL = $VectorUrl" }
    $b = netlify api createSiteBuild --data "{`"site_id`":`"$SiteId`",`"clear_cache`":true}" 2>$null | ConvertFrom-Json
    if (-not $b.deploy_id) { Die 'could not trigger a Netlify build' }
    Info "build $($b.id) -> deploy $($b.deploy_id) (clear_cache=true)"
    $deadline = (Get-Date).AddMinutes(6); $d = $null
    do {
      Start-Sleep 8
      $d = netlify api getDeploy --data "{`"deploy_id`":`"$($b.deploy_id)`"}" 2>$null | ConvertFrom-Json
    } while ($d.state -notin 'ready', 'error' -and (Get-Date) -lt $deadline)
    if ($d.state -ne 'ready') { Die "deploy state=$($d.state) $($d.error_message)" }
    OK "production deploy ready: $($d.ssl_url) @ $($d.commit_ref.Substring(0,7))"
  }
}

# ── 6 verify ──────────────────────────────────────────────────────────────────
if (Runs 'verify') {
  Step 6 'verify -> just keys-verify grounded=1 (G2)'
  if ($DryRun) { Info 'would run just keys-verify grounded=1' }
  else {
    just keys-verify grounded=1
    if ($LASTEXITCODE -ne 0) { Die 'G2 not green - read the keys-verify diagnosis above' }
    Write-Host "`nG2 GREEN - chatbot is live and grounded." -ForegroundColor Green
  }
}
