# 🔮 Tarot Website Server (PowerShell/.NET)
# Run: powershell -ExecutionPolicy Bypass -File server.ps1
#   or: powershell -ExecutionPolicy Bypass -File server.ps1 -LocalOnly
param([switch]$LocalOnly)

$PORT = 3000
$DATA_FILE = Join-Path $PSScriptRoot "data.json"
$PUBLIC_DIR = $PSScriptRoot
$ADMIN_CODE = "taroyuan112510"

# Ensure data file exists
if (-not (Test-Path $DATA_FILE)) {
    @{ count = 0; visits = @() } | ConvertTo-Json -Depth 10 | Set-Content $DATA_FILE
}

function Read-Data {
    try {
        $json = Get-Content $DATA_FILE -Raw -Encoding UTF8
        return $json | ConvertFrom-Json
    } catch {
        return @{ count = 0; visits = @() }
    }
}

function Write-Data($data) {
    $data | ConvertTo-Json -Depth 10 | Set-Content $DATA_FILE -Encoding UTF8
}

function Send-Response($context, $body, $statusCode = 200, $contentType = "application/json") {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $context.Response.StatusCode = $statusCode
    $context.Response.ContentType = $contentType
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.OutputStream.Close()
}

function Get-MimeType($path) {
    $ext = [System.IO.Path]::GetExtension($path).ToLower()
    switch ($ext) {
        ".html" { return "text/html; charset=utf-8" }
        ".css"  { return "text/css; charset=utf-8" }
        ".js"   { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".png"  { return "image/png" }
        ".jpg"  { return "image/jpeg" }
        ".svg"  { return "image/svg+xml" }
        ".ico"  { return "image/x-icon" }
        default { return "application/octet-stream" }
    }
}

function Handle-Request {
    param($context)
    $request = $context.Request
    $response = $context.Response
    $path = $request.Url.AbsolutePath

    # Add CORS headers
    $response.AddHeader("Access-Control-Allow-Origin", "*")
    $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")

    if ($request.HttpMethod -eq "OPTIONS") {
        Send-Response $context "{}" 200
        return
    }

    # API: Record visit
    if ($path -eq "/api/visit" -and $request.HttpMethod -eq "POST") {
        $data = Read-Data
        $data.count += 1
        $visit = @{
            ip = $request.UserHostAddress
            userAgent = $request.UserAgent
            time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        $data.visits += $visit
        if ($data.visits.Count -gt 1000) {
            $data.visits = $data.visits[-1000..-1]
        }
        Write-Data $data
        Send-Response $context (@{ totalVisitors = $data.count } | ConvertTo-Json) 200
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] POST /api/visit - count: $($data.count)"
        return
    }

    # API: Admin login
    if ($path -eq "/api/admin" -and $request.HttpMethod -eq "POST") {
        $reader = New-Object System.IO.StreamReader($request.InputStream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        try {
            $json = $body | ConvertFrom-Json
            if ($json.code -eq $ADMIN_CODE) {
                $data = Read-Data
                $recent = @($data.visits | Select-Object -Last 20)
                [Array]::Reverse($recent)
                Send-Response $context (@{
                    authorized = $true
                    totalVisitors = $data.count
                    recentVisits = $recent
                } | ConvertTo-Json -Depth 10) 200
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] POST /api/admin - authorized"
            } else {
                Send-Response $context (@{ authorized = $false } | ConvertTo-Json) 200
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] POST /api/admin - denied"
            }
        } catch {
            Send-Response $context (@{ authorized = $false } | ConvertTo-Json) 200
        }
        return
    }

    # API: Get count
    if ($path -eq "/api/count" -and $request.HttpMethod -eq "GET") {
        $data = Read-Data
        Send-Response $context (@{ totalVisitors = $data.count } | ConvertTo-Json) 200
        return
    }

    # Static file serving
    $filePath = $path
    if ($filePath -eq "/") { $filePath = "/index.html" }
    $fullPath = Join-Path $PUBLIC_DIR $filePath.TrimStart("/")

    if (Test-Path $fullPath -PathType Leaf) {
        $mime = Get-MimeType $fullPath
        $content = [System.IO.File]::ReadAllBytes($fullPath)
        $context.Response.StatusCode = 200
        $context.Response.ContentType = $mime
        $context.Response.ContentLength64 = $content.Length
        $context.Response.AddHeader("Access-Control-Allow-Origin", "*")
        $context.Response.OutputStream.Write($content, 0, $content.Length)
        $context.Response.OutputStream.Close()
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] GET $path ($($content.Length) bytes)"
    } else {
        Send-Response $context "Not Found" 404 "text/plain"
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] GET $path - 404"
    }
}

# Get local IP
$localIP = "localhost"
try {
    $hostname = [System.Net.Dns]::GetHostName()
    $addresses = [System.Net.Dns]::GetHostAddresses($hostname)
    foreach ($addr in $addresses) {
        if ($addr.AddressFamily -eq 'InterNetwork' -and -not $addr.ToString().StartsWith("127.")) {
            $localIP = $addr.ToString()
            break
        }
    }
} catch {}

$listener = New-Object System.Net.HttpListener
if ($LocalOnly) {
    $listener.Prefixes.Add("http://localhost:$PORT/")
    Write-Host "  Mode: Local only (no admin required)" -ForegroundColor DarkYellow
} else {
    $listener.Prefixes.Add("http://+:$PORT/")
    Write-Host "  Mode: Network (accessible from other devices)" -ForegroundColor Green
}
$listener.Start()

Write-Host ""
Write-Host "🔮 ============================================" -ForegroundColor DarkMagenta
Write-Host "    命运之轮 · Tarot Website Server" -ForegroundColor Yellow
Write-Host "============================================ " -ForegroundColor DarkMagenta
Write-Host ""
Write-Host "  Local:    http://localhost:$PORT" -ForegroundColor Cyan
Write-Host "  Network:  http://${localIP}:$PORT" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Admin code: $ADMIN_CODE" -ForegroundColor DarkGray
Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host ""

try {
    while ($listener.IsListening) {
        $contextTask = $listener.GetContextAsync()
        while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) {}
        $context = $contextTask.Result
        Handle-Request $context
    }
} finally {
    $listener.Stop()
    Write-Host "`n✨ Server stopped." -ForegroundColor Yellow
}
