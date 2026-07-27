# RunAllTests.ps1 - Automated Test Suite Runner

$currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $currentDir) { $currentDir = Get-Location }

$isWindows = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop')
try {
    $isWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
} catch {}

. (Join-Path $currentDir "Crypto.Tests.ps1")
. (Join-Path $currentDir "Vault.Tests.ps1")
. (Join-Path $currentDir "Utils.Tests.ps1")
. (Join-Path $currentDir "Logger.Tests.ps1")
. (Join-Path $currentDir "EncodingAndSyntax.Tests.ps1")

if ($isWindows) {
    . (Join-Path $currentDir "GUI.Tests.ps1")
    . (Join-Path $currentDir "GUI_FullButtons.Tests.ps1")
    . (Join-Path $currentDir "GUI_CriticalUserOperations.Tests.ps1")
    . (Join-Path $currentDir "GUI_JP.Tests.ps1")
    . (Join-Path $currentDir "GUI_NewFeatures.Tests.ps1")
}

Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host " Running SimplePASS Automated Test Suite " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor DarkGray

$testResults = @(
    (Run-CryptoTests),
    (Run-VaultTests),
    (Run-UtilsTests),
    (Run-LoggerTests),
    (Run-EncodingAndSyntaxTests)
)

if ($isWindows) {
    $testResults += (Run-GuiTests)
    $testResults += (Run-GuiFullButtonsTests)
    $testResults += (Run-GuiCriticalUserOperationsTests)
    $testResults += (Run-GuiJpTests)
    $testResults += (Run-GuiNewFeaturesTests)
} else {
    Write-Host "`n[SKIP] Non-Windows environment detected. Skipping WPF GUI tests." -ForegroundColor Yellow
}

$totalPassed = ($testResults | Where-Object { $_ -and $_.Passed } | ForEach-Object { $_.Passed }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$totalFailed = ($testResults | Where-Object { $_ -and $_.Failed } | ForEach-Object { $_.Failed }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum

if ($null -eq $totalPassed) { $totalPassed = 0 }
if ($null -eq $totalFailed) { $totalFailed = 0 }

Write-Host "`n--- Execution Logs ---" -ForegroundColor Yellow
foreach ($res in $testResults) {
    if ($res -and $res.Log) {
        foreach ($log in $res.Log) {
            if ($log -and $log.StartsWith("[PASS]")) {
                Write-Host $log -ForegroundColor Green
            } elseif ($log) {
                Write-Host $log -ForegroundColor Red
            }
        }
    }
}

$summaryColor = if ($totalFailed -eq 0) { "Green" } else { "Red" }
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " SUMMARY: Passed: $totalPassed | Failed: $totalFailed " -ForegroundColor $summaryColor
Write-Host "==========================================" -ForegroundColor Cyan

if ($totalFailed -gt 0) {
    exit 1
} else {
    exit 0
}
