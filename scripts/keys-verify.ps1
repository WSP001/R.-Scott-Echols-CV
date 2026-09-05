#Requires -Version 7.0
<#
.SYNOPSIS
  keys-verify — prove the deployed chatbot stack is alive, end to end.

.DESCRIPTION
  Never prints secret values. Checks, in order:
    1. Netlify env presence (via `netlify env:list`) for the runtime contract.
    2. Cloud Run retrieval service: /health body status, /partitions, /retrieve.
    3. Live /api/chat: HTTP code, X-RAG-Status header, rag_status, rag_attempts,
       rag_context_used, answer_source.
    4. /api/identity.json reachable.

  Exit 0  = chat is HTTP 200 (bot online).  rag_status is reported, not gated.
  Exit 1  = chat is not HTTP 200, or a hard prerequisite failed.

.PARAMETER Site
  Base URL of the CV site. Default: https://robertoscottecholscv.netlify.app
.PARAMETER Question
  Prompt sent to /api/chat.
.PARAMETER RequireGrounded
  Also fail unless rag_status == "ok" (gate G2).
.PARAMETER Json
  Emit a single JSON object instead of text.
#>
param(
  [string]$Site = 'https://robertoscottecholscv.netlify.app',
  [string]$Question = 'What does SeaTrace do?',
  [switch]$RequireGrounded,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$result = [ordered]@{
  checked_at   = (Get-Date).ToUniversalTime().ToString('o')
  site         = $Site
  env          = [ordered]@{}
  cloud_run    = [ordered]@{}
  chat         = [ordered]@{}
  identity     = [ordered]@{}
  verdict      = 'UNKNOWN'
  failures     = @()
}
$fail = New-Object System.Collections.Generic.List[string]

function Get-Body([Microsoft.PowerShell.Commands.WebResponseObject]$r, [int]$max = 240) {
  if (-not $r.Content) { return '' }
  $c = [string]$r.Content
  if ($c.Length -gt $max) { $c.Substring(0, $max) + '…' } else { $c }
}

# ── 1. Netlify env presence ───────────────────────────────────────────────────
$required = 'ANTHROPIC_API_KEY', 'GEMINI_API_KEY', 'BUSINESS_ACCESS_KEY'
$optional = 'VECTOR_ENGINE_URL', 'ABACUS_API_KEY'
$vectorUrl = ''
try {
  $envJson = netlify env:list --json 2>$null | ConvertFrom-Json
  $names = @($envJson.PSObject.Properties.Name)
  foreach ($n in $required + $optional) {
    $present = $names -contains $n
    $result.env[$n] = if ($present) { 'set' } else { 'MISSING' }
    if (-not $present -and $n -in $required) { $fail.Add("netlify env $n missing") }
  }
  if ($names -contains 'VECTOR_ENGINE_URL') { $vectorUrl = ([string]$envJson.VECTOR_ENGINE_URL).Trim() }
} catch {
  $result.env['error'] = 'netlify env:list failed — is the repo linked? run: netlify link'
}
if (-not $vectorUrl -and $env:VECTOR_ENGINE_URL) { $vectorUrl = $env:VECTOR_ENGINE_URL }

# ── 2. Cloud Run retrieval service ────────────────────────────────────────────
if ($vectorUrl) {
  $result.cloud_run.url = $vectorUrl
  try {
    $h = Invoke-WebRequest -Uri "$vectorUrl/health" -TimeoutSec 30 -SkipHttpErrorCheck
    $hb = $null; try { $hb = $h.Content | ConvertFrom-Json } catch {}
    $result.cloud_run.health_http   = $h.StatusCode
    $result.cloud_run.health_status = if ($hb -and $hb.status) { $hb.status } else { 'unparsed' }
    if ($hb -and $hb.error) { $result.cloud_run.health_error = $hb.error }
  } catch { $result.cloud_run.health_http = "unreachable: $($_.Exception.Message)" }

  try {
    $p = Invoke-WebRequest -Uri "$vectorUrl/partitions" -TimeoutSec 30 -SkipHttpErrorCheck
    $pb = $null; try { $pb = $p.Content | ConvertFrom-Json } catch {}
    $result.cloud_run.partitions = if ($pb) { @($pb.partitions.PSObject.Properties.Name) } else { @() }
    $result.cloud_run.linkedin_history_allowed = ($result.cloud_run.partitions -contains 'linkedin_history')
  } catch { $result.cloud_run.partitions = "unreachable: $($_.Exception.Message)" }

  try {
    $q = @{ query = 'traceability'; tier = 'public'; top_k = 3 } | ConvertTo-Json -Compress
    $rt = Invoke-WebRequest -Uri "$vectorUrl/retrieve" -Method Post -ContentType 'application/json' -Body $q -TimeoutSec 60 -SkipHttpErrorCheck
    $result.cloud_run.retrieve_http = $rt.StatusCode
    if ($rt.StatusCode -eq 200) {
      $arr = @($rt.Content | ConvertFrom-Json)
      $result.cloud_run.retrieve_results = $arr.Count
    } else {
      $result.cloud_run.retrieve_body = Get-Body $rt
    }
  } catch { $result.cloud_run.retrieve_http = "unreachable: $($_.Exception.Message)" }
} else {
  $result.cloud_run.url = 'not configured (rag_status will be "disabled")'
}

# ── 3. Live chat ──────────────────────────────────────────────────────────────
try {
  $body = @{ message = $Question } | ConvertTo-Json -Compress
  $c = Invoke-WebRequest -Uri "$Site/api/chat" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 90 -SkipHttpErrorCheck
  $result.chat.http = $c.StatusCode
  $result.chat.x_rag_status = [string]$c.Headers['X-RAG-Status']
  $cb = $null; try { $cb = $c.Content | ConvertFrom-Json } catch {}
  if ($cb) {
    foreach ($k in 'tier', 'rag_status', 'rag_attempts', 'rag_context_used', 'answer_source', 'tokens_used', 'error') {
      if ($null -ne $cb.$k) { $result.chat[$k] = $cb.$k }
    }
    if ($cb.reply) { $result.chat.reply_chars = ([string]$cb.reply).Length }
  } else {
    $result.chat.body = Get-Body $c
  }
  if ($c.StatusCode -ne 200) {
    $why = switch ($c.StatusCode) {
      503 { 'ANTHROPIC_API_KEY not visible to the edge function (unset, or deploy predates the var)' }
      502 { 'Anthropic call threw — most likely an invalid/revoked ANTHROPIC_API_KEY, or Anthropic-side error' }
      default { 'unexpected status' }
    }
    $result.chat.diagnosis = $why
    $fail.Add("chat HTTP $($c.StatusCode): $why")
  } elseif ($RequireGrounded -and $result.chat.rag_status -ne 'ok') {
    $fail.Add("chat rag_status='$($result.chat.rag_status)' (RequireGrounded)")
  }
} catch {
  $result.chat.http = "unreachable: $($_.Exception.Message)"
  $fail.Add('chat unreachable')
}

# ── 4. Identity endpoint ──────────────────────────────────────────────────────
try {
  $i = Invoke-WebRequest -Uri "$Site/api/identity.json" -TimeoutSec 30 -SkipHttpErrorCheck
  $result.identity.http = $i.StatusCode
  if ($i.StatusCode -ne 200) { $fail.Add("identity.json HTTP $($i.StatusCode)") }
} catch { $result.identity.http = "unreachable"; $fail.Add('identity.json unreachable') }

# ── Verdict ───────────────────────────────────────────────────────────────────
$result.failures = @($fail)
$result.verdict = if ($fail.Count -eq 0) { 'PASS' } else { 'FAIL' }

if ($Json) {
  $result | ConvertTo-Json -Depth 6
} else {
  Write-Host "KEYS-VERIFY: $($result.verdict)" -ForegroundColor ($(if ($result.verdict -eq 'PASS') { 'Green' } else { 'Red' }))
  Write-Host "  site            $Site"
  Write-Host "  env             " -NoNewline; Write-Host (($result.env.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '  ')
  Write-Host "  cloud_run       url=$($result.cloud_run.url)"
  if ($result.cloud_run.health_http) {
    Write-Host "                  /health HTTP $($result.cloud_run.health_http) status=$($result.cloud_run.health_status)"
    if ($result.cloud_run.health_error) { Write-Host "                    error: $($result.cloud_run.health_error)" -ForegroundColor Yellow }
    Write-Host "                  /partitions linkedin_history_allowed=$($result.cloud_run.linkedin_history_allowed)"
    Write-Host "                  /retrieve HTTP $($result.cloud_run.retrieve_http) results=$($result.cloud_run.retrieve_results)"
  }
  Write-Host "  chat            HTTP $($result.chat.http)  X-RAG-Status=$($result.chat.x_rag_status)"
  foreach ($k in 'tier', 'rag_status', 'rag_attempts', 'rag_context_used', 'answer_source', 'tokens_used', 'reply_chars', 'error', 'diagnosis') {
    if ($result.chat.Contains($k)) { Write-Host ("                  {0,-17}{1}" -f $k, $result.chat[$k]) }
  }
  Write-Host "  identity.json   HTTP $($result.identity.http)"
  foreach ($f in $fail) { Write-Host "  ✗ $f" -ForegroundColor Red }
}

exit $(if ($result.verdict -eq 'PASS') { 0 } else { 1 })
