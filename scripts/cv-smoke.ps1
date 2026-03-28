# cv-smoke.ps1 — Post-deploy smoke test for R. Scott Echols CV site
# WSP001 — Commons Good
# Usage: .\scripts\cv-smoke.ps1 [-Url "https://robertoscottecholscv.netlify.app"]
#
# Tests:
#   1. Site is live (HTTP 200)
#   2. Project cards render (Sir James, LearnQuest, SeaTrace, SirTrav)
#   3. Years Experience counter shows 39+
#   4. Chat endpoint responds
#   5. Vector retrieval (if VECTOR_ENGINE_URL is set)

param(
    [string]$Url = "https://robertoscottecholscv.netlify.app"
)

$ErrorActionPreference = "Continue"
$pass = 0; $fail = 0; $skip = 0

function Test-Step($name, $check) {
    try {
        $result = & $check
        if ($result) { Write-Host "  PASS: $name" -ForegroundColor Green; $script:pass++ }
        else { Write-Host "  FAIL: $name" -ForegroundColor Red; $script:fail++ }
    } catch {
        Write-Host "  FAIL: $name — $($_.Exception.Message)" -ForegroundColor Red
        $script:fail++
    }
}

Write-Host "`n=== CV SMOKE TEST ===" -ForegroundColor Cyan
Write-Host "Target: $Url`n"

# 1. Site alive
Write-Host "--- Step 1: Site Health ---"
$page = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
Test-Step "HTTP 200" { $page.StatusCode -eq 200 }
Test-Step "HTML contains <title>" { $page.Content -match '<title>' }

# 2. Project cards
Write-Host "`n--- Step 2: Project Cards ---"
$html = $page.Content
Test-Step "SeaTrace card present" { $html -match '(?i)seatrace|four pillars' }
Test-Step "SirTrav card present" { $html -match '(?i)sirtrav|a2a' }
Test-Step "Sir James card present" { $html -match '(?i)sir james|adventures' }
Test-Step "LearnQuest card present" { $html -match '(?i)learnquest' }

# 3. Years counter
Write-Host "`n--- Step 3: Years Experience ---"
Test-Step "Years shows 39+" { $html -match '39\+' }

# 4. Chat endpoint
Write-Host "`n--- Step 4: Chat API ---"
try {
    $chatResp = Invoke-RestMethod -Uri "$Url/api/chat" -Method POST -ContentType "application/json" -Body '{"message":"hello","tier":"public","questionCount":0}' -TimeoutSec 15 -ErrorAction Stop
    Test-Step "Chat returns reply" { $chatResp.reply -and $chatResp.reply.Length -gt 0 }
    Test-Step "Chat returns tier" { $chatResp.tier -eq 'public' -or $chatResp.tier -eq 'business' }
} catch {
    Write-Host "  FAIL: Chat API — $($_.Exception.Message)" -ForegroundColor Red
    $fail++
}

# 5. Vector retrieval (optional)
Write-Host "`n--- Step 5: Vector Retrieval ---"
$vectorUrl = $env:VECTOR_ENGINE_URL
if ($vectorUrl) {
    try {
        $health = Invoke-RestMethod -Uri "$vectorUrl/health" -TimeoutSec 5 -ErrorAction Stop
        Test-Step "Vector server alive" { $health }
        $query = Invoke-RestMethod -Uri "$vectorUrl/query" -Method POST -ContentType "application/json" -Body '{"query":"Scott Echols background","partitions":["cv_personal"],"n_results":3}' -TimeoutSec 10 -ErrorAction Stop
        Test-Step "Vector returns chunks" { $query.context_chunks -and $query.context_chunks.Count -gt 0 }
    } catch {
        Write-Host "  FAIL: Vector — $($_.Exception.Message)" -ForegroundColor Red
        $fail++
    }
} else {
    Write-Host "  SKIP: VECTOR_ENGINE_URL not set (expected until Cloud Run deploy)" -ForegroundColor Yellow
    $skip++
}

# Summary
Write-Host "`n=== RESULTS ===" -ForegroundColor Cyan
Write-Host "  PASS: $pass | FAIL: $fail | SKIP: $skip"
if ($fail -eq 0) {
    Write-Host "  VERDICT: ALL GREEN" -ForegroundColor Green
} else {
    Write-Host "  VERDICT: $fail FAILURES — review above" -ForegroundColor Red
}