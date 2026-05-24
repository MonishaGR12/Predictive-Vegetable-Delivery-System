$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$toolsRoot = Join-Path $projectRoot "tools"
$backendLogPath = Join-Path $toolsRoot "cloudflared.log"
$mlLogPath = Join-Path $toolsRoot "cloudflared-ml.log"
$mlApiLogPath = Join-Path $toolsRoot "ml-api.log"
$pythonPath = "C:\Users\Monisha\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$cloudflaredPath = Join-Path $toolsRoot "cloudflared.exe"
$javaHome = "C:\Program Files\Android\Android Studio\jbr"
$gradleWrapper = Join-Path $projectRoot "gradlew.bat"
$apkPath = Join-Path $projectRoot "app\build\outputs\apk\debug\app-debug.apk"

function Wait-HttpReady {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 90
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-WebRequest $Url -UseBasicParsing | Out-Null
            return
        } catch {
            Start-Sleep -Seconds 2
        }
    }

    throw "Timed out waiting for $Url"
}

function Wait-QuickTunnelUrl {
    param(
        [string]$LogPath,
        [int]$TimeoutSeconds = 45
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $pattern = "https://[a-z0-9-]+\.trycloudflare\.com"

    while ((Get-Date) -lt $deadline) {
        if (Test-Path $LogPath) {
            $content = Get-Content $LogPath -Raw
            $match = [regex]::Match($content, $pattern)
            if ($match.Success) {
                return $match.Value
            }
        }
        Start-Sleep -Seconds 2
    }

    throw "Timed out waiting for a tunnel URL in $LogPath"
}

Write-Host "Stopping old cloudflared/python processes..."
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process python -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like "*codex-primary-runtime*python.exe" } |
    Stop-Process -Force

Write-Host "Starting Flask ML API..."
Set-Content $mlApiLogPath ""
Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c","cd /D ""$projectRoot"" && ""$pythonPath"" -u app.py > ""$mlApiLogPath"" 2>&1" `
    -WindowStyle Hidden

Wait-HttpReady -Url "http://127.0.0.1:5000/health"

Write-Host "Starting backend tunnel..."
Set-Content $backendLogPath ""
Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c","cd /D ""$projectRoot"" && ""$cloudflaredPath"" tunnel --protocol http2 --no-autoupdate --loglevel info --url http://127.0.0.1:80 > ""$backendLogPath"" 2>&1" `
    -WindowStyle Hidden

Write-Host "Starting ML tunnel..."
Set-Content $mlLogPath ""
Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c","cd /D ""$projectRoot"" && ""$cloudflaredPath"" tunnel --protocol http2 --no-autoupdate --loglevel info --url http://127.0.0.1:5000 > ""$mlLogPath"" 2>&1" `
    -WindowStyle Hidden

$backendUrl = Wait-QuickTunnelUrl -LogPath $backendLogPath
$mlUrl = Wait-QuickTunnelUrl -LogPath $mlLogPath
$temporaryBackendBaseUrl = "$backendUrl/vegetable_api/"
$temporaryMlPredictUrl = "$mlUrl/predict"

Write-Host "Backend tunnel: $backendUrl"
Write-Host "ML tunnel: $mlUrl"

if (-not (Test-Path $javaHome)) {
    throw "JAVA_HOME not found at $javaHome"
}

Write-Host "Building debug APK..."
$env:JAVA_HOME = $javaHome
$env:Path = "$javaHome\bin;$env:Path"
& $gradleWrapper assembleDebug `
    "-PGRUNO_BACKEND_BASE_URL=$temporaryBackendBaseUrl" `
    "-PGRUNO_ML_PREDICT_URL=$temporaryMlPredictUrl"

Write-Host ""
Write-Host "Done."
Write-Host "Temporary backend base URL: $temporaryBackendBaseUrl"
Write-Host "Temporary ML predict URL: $temporaryMlPredictUrl"
Write-Host "These quick tunnel URLs were used only for this build and were not written into the source code."
Write-Host "APK: $apkPath"
