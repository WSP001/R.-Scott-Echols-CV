# verify-vector.ps1
# WSP001 — Automated vector engine verification
# FOR THE COMMONS GOOD — reusable across WSP001 repos
#
# Tests the full round-trip from SirTrav's queryVectorEngine() call
# through the Cloud Run /query endpoint.
#
# Usage:
#   .\scripts\verify-vector.ps1 -Url "https://your-cloud-run-url"
#   .\scripts\verify-vector.ps1              # reads VECTOR_ENGINE_URL env var
#
# What it tests:
#   1. /health         → is the server alive, how many chunks in DB
#   2. /partitions     → are cv_personal + cv_projects present
#   3. /query          → does SirTrav's exact payload work, does response have context_chunks[]
#   4. chunk content   → do chunks look like real identity text (not empty/garbage)
#   5. Netlify hint    → prints the VECTOR_ENGINE_URL value to paste into Netlify
#
# Architecture: Scott Echols / WSP001 — Commons Good
# Engineering:  Claude Sonnet 4.6

param(
    [string]$Url = $env:VECTOR_ENGINE_URL,
    [string]$TestQuery = "SeaTrace fisheries traceability maritime supply chain"
)

$ErrorActionPreference = "SilentlyContinue"

function Write-Step { param($msg) Write-Host "`n[VERIFY] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  PASS  $msg" -ForegroundColor Green }
function Write-Fail { param($msg) Write-Host "  FAIL  $msg" -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host "  WARN  $msg" -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host "  INFO  $msg" -ForegroundColor Gray }

$PassCount = 0
$FailCount = 0

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " WSP001 Vector Engine — Full Verification" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

if (-not $Url) {
    Write-Fail "No URL provided. Pass -Url or set VECTOR_ENGINE_URL env var."
    Write-Host ""
    Write-Host "  Example: .\scripts\verify-vector.ps1 -Url 'https://rse-retrieval-xxx.run.app'"
    exit 1
}

$Url = $Url.TrimEnd("/")
Write-Info "Target: $Url"
Write-Info "Query:  $TestQuery"

# ── Test 1: Health ─────────────────────────────────────────────────────────────
Write-Step "1/4 — Health check"
try {
    $Health = Invoke-RestMethod -Uri "$Url/health" -Method GET -TimeoutSec 15
    if ($Health.status -eq "ok") {
        Write-OK "Server alive. Chunks in DB: $($Health.chunks)"
        $PassCount++
        if ($Health.chunks -eq 0) {
            Write-Warn "DB is empty — run: just ingest-identity (or embed_engine.py) to populate"
        }
    } else {
        Write-Fail "Health returned: $($Health.status) — $($Health.error)"
        $FailCount++
    }
} catch {
    Write-Fail "Health check failed — server unreachable or not yet started"
    Write-Info "Error: $_"
    $FailCount++
    Write-Host ""
    Write-Host "  Cloud Run cold start can take 10-20s. Wait and retry." -ForegroundColor Yellow
    exit 1
}

# ── Test 2: Partitions ─────────────────────────────────────────────────────────
Write-Step "2/4 — Partition check"
try {
    $Parts = Invoke-RestMethod -Uri "$Url/partitions" -Method GET -TimeoutSec 10
    $Required = @("cv_personal", "cv_projects")
    $Found = $true
    foreach ($p in $Required) {
        if ($Parts.partitions.PSObject.Properties.Name -contains $p) {
            Write-OK "Partition registered: $p"
        } else {
            Write-Fail "Partition missing: $p"
            $Found = $false
            $FailCount++
        }
    }
    if ($Found) { $PassCount++ }
} catch {
    Write-Fail "Partitions endpoint failed: $_"
    $FailCount++
}

# ── Test 3: /query — SirTrav calling contract ─────────────────────────────────
Write-Step "3/4 — /query endpoint (SirTrav contract)"
$QueryBody = @{
    query      = $TestQuery
    partitions = @("cv_personal", "cv_projects")
    n_results  = 4
} | ConvertTo-Json

try {
    $Response = Invoke-RestMethod -Uri "$Url/query" -Method POST `
        -ContentType "application/json" -Body $QueryBody -TimeoutSec 20

    if ($null -ne $Response.context_chunks) {
        $Count = $Response.context_chunks.Count
        Write-OK "/query returned context_chunks[] with $Count items"
        $PassCount++

        if ($Count -eq 0) {
            Write-Warn "context_chunks is empty — DB may not be ingested yet"
            Write-Warn "Run: just ingest-identity (cv repo) to populate cv_personal + cv_projects"
        }
    } else {
        Write-Fail "/query response missing context_chunks field — format mismatch"
        Write-Info "Raw response: $($Response | ConvertTo-Json -Depth 3)"
        $FailCount++
    }
} catch {
    Write-Fail "/query failed: $_"
    $FailCount++
}

# ── Test 4: Chunk content sanity ───────────────────────────────────────────────
Write-Step "4/4 — Chunk content sanity"
if ($null -ne $Response -and $Response.context_chunks.Count -gt 0) {
    $FirstChunk = $Response.context_chunks[0]
    $WordCount = ($FirstChunk -split "\s+").Count
    if ($WordCount -ge 10) {
        Write-OK "First chunk has $WordCount words — looks like real content"
        Write-Info "Preview: $($FirstChunk.Substring(0, [Math]::Min(120, $FirstChunk.Length)))..."
        $PassCount++
    } else {
        Write-Fail "First chunk is suspiciously short ($WordCount words) — may be garbage"
        $FailCount++
    }
} else {
    Write-Warn "Skipped chunk sanity — no chunks returned (DB empty or query mismatch)"
}

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host " RESULT: $PassCount passed / $FailCount failed" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor Magenta

if ($FailCount -eq 0) {
    Write-Host ""
    Write-Host "  Vector engine is LIVE and SirTrav-compatible." -ForegroundColor Green
    Write-Host ""
    Write-Host "  NEXT: Add this to Netlify Environment Variables (Functions scope):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Key:   VECTOR_ENGINE_URL" -ForegroundColor White
    Write-Host "    Value: $Url" -ForegroundColor White
    Write-Host ""
    Write-Host "  Then: git push to trigger Netlify redeploy → Phase 2 activates." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "  Fix failures above before setting VECTOR_ENGINE_URL in Netlify." -ForegroundColor Red
}
Write-Host ""
