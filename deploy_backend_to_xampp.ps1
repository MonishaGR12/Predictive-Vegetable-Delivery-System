param(
    [string]$Source = "C:\Users\Monisha\AndroidStudioProjects\Gruno\vegetable_api",
    [string]$Destination = "C:\xampp\htdocs\vegetable_api"
)

$resolvedSource = (Resolve-Path -LiteralPath $Source).Path

if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination | Out-Null
}

Get-ChildItem -LiteralPath $resolvedSource -File | ForEach-Object {
    $destinationPath = Join-Path $Destination $_.Name
    Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
}

$sourceSrc = Join-Path $resolvedSource "src"
$destinationSrc = Join-Path $Destination "src"
if (Test-Path -LiteralPath $destinationSrc) {
    Remove-Item -LiteralPath $destinationSrc -Recurse -Force
}
Copy-Item -LiteralPath $sourceSrc -Destination $destinationSrc -Recurse -Force

Write-Output "Backend OTP files deployed to $Destination"
