$ErrorActionPreference = "Stop"

$projectRoot = Split-Path $PSScriptRoot -Parent
$gradlePropertiesPath = Join-Path $projectRoot "gradle.properties"

function Get-PrimaryIpv4Address {
    $routeLines = route print -4
    foreach ($line in $routeLines) {
        if ($line -match "^\s*0\.0\.0\.0\s+0\.0\.0\.0\s+\S+\s+(\d{1,3}(?:\.\d{1,3}){3})\s+\d+\s*$") {
            return $matches[1]
        }
    }

    $ipconfigLines = ipconfig
    foreach ($line in $ipconfigLines) {
        if ($line -match "IPv4 Address[^\:]*:\s*(\d{1,3}(?:\.\d{1,3}){3})") {
            if ($matches[1] -notmatch "^169\.254\.") {
                return $matches[1]
            }
        }
    }

    throw "Could not find an active Wi-Fi or LAN IPv4 address from route print or ipconfig."
}

if (-not (Test-Path $gradlePropertiesPath)) {
    throw "gradle.properties not found at $gradlePropertiesPath"
}

$ipAddress = Get-PrimaryIpv4Address
$backendUrl = "http://$ipAddress/vegetable_api/"
$content = Get-Content $gradlePropertiesPath -Raw

if ($content -match "(?m)^GRUNO_BACKEND_BASE_URL=") {
    $updatedContent = [regex]::Replace(
        $content,
        "(?m)^GRUNO_BACKEND_BASE_URL=.*$",
        "GRUNO_BACKEND_BASE_URL=$backendUrl"
    )
} else {
    $updatedContent = $content.TrimEnd("`r", "`n") + "`r`nGRUNO_BACKEND_BASE_URL=$backendUrl`r`n"
}

Set-Content -Path $gradlePropertiesPath -Value $updatedContent -Encoding ASCII

Write-Host "Updated GRUNO_BACKEND_BASE_URL to $backendUrl"
Write-Host "Rebuild and reinstall the app so the new default URL is bundled into the APK."
