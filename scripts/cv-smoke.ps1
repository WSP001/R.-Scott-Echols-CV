param(
    [string]$BaseUrl = "https://robertoscottecholscv.netlify.app",
    [string]$Prompt = "Say hello in one short sentence.",
    [int]$TimeoutSec = 45
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BaseUrl = $BaseUrl.TrimEnd("/")

try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor `
        [Net.SecurityProtocolType]::Tls12
} catch {
    # Ignore on platforms where this is not needed.
}

try {
    Add-Type -AssemblyName System.Net.Http -ErrorAction Stop
} catch {
    # Already available in some hosts.
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Fail {
    param(
        [int]$Code,
        [string]$Message
    )
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    exit $Code
}

function Get-Preview {
    param(
        [string]$Text,
        [int]$Max = 240
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $flat = ($Text -replace "\s+", " ").Trim()
    if ($flat.Length -le $Max) {
        return $flat
    }

    return $flat.Substring(0, $Max) + "..."
}

function New-HttpClient {
    param([int]$TimeoutSec)

    $handler = New-Object System.Net.Http.HttpClientHandler
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd("cv-smoke/1.0")
    return $client
}

function Invoke-HttpText {
    param(
        [System.Net.Http.HttpClient]$Client,
        [ValidateSet("GET", "POST")][string]$Method,
        [string]$Uri,
        [AllowNull()][string]$Body = $null
    )

    $response = $null
    $contentObj = $null

    try {
        switch ($Method) {
            "GET" {
                $response = $Client.GetAsync($Uri).GetAwaiter().GetResult()
            }
            "POST" {
                $requestBody = $Body
                if ($null -eq $requestBody) {
                    $requestBody = ""
                }
                $contentObj = New-Object System.Net.Http.StringContent(
                    $requestBody,
                    [System.Text.Encoding]::UTF8,
                    "application/json"
                )
                $response = $Client.PostAsync($Uri, $contentObj).GetAwaiter().GetResult()
            }
            default {
                throw "Unsupported method: $Method"
            }
        }

        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        $contentType = ""
        if ($response.Content.Headers.ContentType) {
            $contentType = [string]$response.Content.Headers.ContentType.MediaType
        }

        return [pscustomobject]@{
            StatusCode   = [int]$response.StatusCode
            ReasonPhrase = [string]$response.ReasonPhrase
            Content      = [string]$content
            ContentType  = $contentType
        }
    }
    finally {
        if ($response) {
            $response.Dispose()
        }
        if ($contentObj) {
            $contentObj.Dispose()
        }
    }
}

function Get-ReplyText {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        $text = $Value.Trim()
        if ($text.Length -gt 0) {
            return $text
        }
        return $null
    }

    if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
        foreach ($item in $Value) {
            $nested = Get-ReplyText -Value $item
            if ($nested) {
                return $nested
            }
        }
    }

    $simpleNames = @("reply", "message", "text", "answer", "completion", "response")
    foreach ($name in $simpleNames) {
        $prop = $Value.PSObject.Properties[$name]
        if ($prop) {
            $nested = Get-ReplyText -Value $prop.Value
            if ($nested) {
                return $nested
            }
        }
    }

    $contentProp = $Value.PSObject.Properties["content"]
    if ($contentProp) {
        $content = $contentProp.Value

        if ($content -is [string]) {
            $text = $content.Trim()
            if ($text.Length -gt 0) {
                return $text
            }
        }

        if (($content -is [System.Collections.IEnumerable]) -and -not ($content -is [string])) {
            $parts = @()
            foreach ($item in $content) {
                if ($item -is [string]) {
                    $parts += $item
                }
                else {
                    $textProp = $item.PSObject.Properties["text"]
                    if ($textProp -and $textProp.Value) {
                        $parts += [string]$textProp.Value
                    }
                }
            }

            if ($parts.Count -gt 0) {
                return (($parts -join "`n").Trim())
            }
        }
    }

    $choicesProp = $Value.PSObject.Properties["choices"]
    if ($choicesProp -and $choicesProp.Value) {
        foreach ($choice in $choicesProp.Value) {
            $nested = Get-ReplyText -Value $choice
            if ($nested) {
                return $nested
            }
        }
    }

    return $null
}

$client = $null

try {
    $client = New-HttpClient -TimeoutSec $TimeoutSec

    $homeUri = $BaseUrl
    $chatUri = "$BaseUrl/api/chat"

    Write-Host "Checking $homeUri"
    $homeResponse = Invoke-HttpText -Client $client -Method GET -Uri $homeUri

    if ($homeResponse.StatusCode -lt 200 -or $homeResponse.StatusCode -ge 300) {
        Fail 1 "Home page returned $($homeResponse.StatusCode) $($homeResponse.ReasonPhrase)."
    }

    Write-Ok "Home page returned $($homeResponse.StatusCode)."

    if (($homeResponse.Content -match "RSE-Assistant") -or ($homeResponse.Content -match "/api/chat")) {
        Write-Ok "Home page contains expected chat markers."
    }
    else {
        Write-Warn "Home page loaded, but expected chat markers were not found in HTML. Continuing with live chat probe."
    }

    $bodyJson = @{ message = $Prompt } | ConvertTo-Json -Compress -Depth 5

    Write-Host "Posting smoke prompt to $chatUri"
    $chat = Invoke-HttpText -Client $client -Method POST -Uri $chatUri -Body $bodyJson

    if ($chat.StatusCode -eq 503) {
        $preview = Get-Preview -Text $chat.Content

        if ($preview -match "ANTHROPIC_API_KEY") {
            Fail 3 "Chat endpoint returned 503. Missing ANTHROPIC_API_KEY on the deployed site. Body: $preview"
        }

        Fail 3 "Chat endpoint returned 503. Body: $preview"
    }

    if ($chat.StatusCode -lt 200 -or $chat.StatusCode -ge 300) {
        $preview = Get-Preview -Text $chat.Content
        Fail 2 "Chat endpoint returned $($chat.StatusCode) $($chat.ReasonPhrase). Body: $preview"
    }

    $replyText = $null

    try {
        $json = $chat.Content | ConvertFrom-Json -Depth 20
        $replyText = Get-ReplyText -Value $json
    }
    catch {
        if (($chat.Content -notmatch "^\s*<") -and -not [string]::IsNullOrWhiteSpace($chat.Content)) {
            $replyText = $chat.Content.Trim()
        }
    }

    if (-not $replyText) {
        $preview = Get-Preview -Text $chat.Content
        Fail 4 "Chat endpoint returned 200 but no assistant text could be extracted. Body: $preview"
    }

    Write-Ok "Chat endpoint returned $($chat.StatusCode)."
    Write-Ok "Assistant reply: $(Get-Preview -Text $replyText)"
    Write-Host ""
    Write-Host "SMOKE TEST PASSED" -ForegroundColor Green
    exit 0
}
catch {
    Fail 9 $_.Exception.Message
}
finally {
    if ($client) {
        $client.Dispose()
    }
}
