# GUI_CriticalUserOperations.Tests.ps1 - Critical User Operations & Edge Cases Test Suite

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-GuiCriticalUserOperationsTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"

    Import-Module (Join-Path $srcDir "CryptoModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "VaultModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "UtilsModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "LoggerModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: Critical: Zero-match Search & Search Reset Restoration
    try {
        $e1 = New-VaultEntry -Title "Alpha" -Password "P1"
        $e2 = New-VaultEntry -Title "Beta" -Password "P2"
        $all = @($e1, $e2)

        # 0件ヒットの検索
        $noMatch = @(Search-VaultEntries -Entries $all -Keyword "NonExistentWordXYZ999")
        Assert-True ($noMatch.Count -eq 0) "Search returns 0 items for non-existent keyword"

        $dg = New-Object System.Windows.Controls.DataGrid
        $dg.ItemsSource = @($noMatch)
        Assert-True ($null -ne $dg.ItemsSource) "DataGrid cleanly displays 0 items without throwing exception"

        # 検索文字列クリア時の全件復帰
        $restored = @(Search-VaultEntries -Entries $all -Keyword "")
        Assert-True ($restored.Count -eq 2) "Empty keyword search restores all 2 entries"

        $results.Passed++
        $results.Log += "[PASS] Test 1: Zero-match Search & Search Reset Restoration"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: Zero-match Search & Restoration - $_"
    }

    # Test 2: Critical: Multi-cycle Re-authentication (Correct -> Lock -> Wrong -> Correct)
    try {
        $tempVaultPath = [System.IO.Path]::GetTempFileName()
        $masterPass = "ReAuthMasterPass123!"

        # Create vault
        Save-Vault -Entries @($e1) -MasterPassword $masterPass -Path $tempVaultPath

        # 1. Correct Auth
        $auth1 = @(Load-Vault -MasterPassword $masterPass -Path $tempVaultPath)
        Assert-True ($auth1.Count -eq 1) "First login succeeded"

        # 2. Wrong Auth (Must fail)
        $wrongPassFailed = $false
        try {
            $dummy = Load-Vault -MasterPassword "WrongPassword999!" -Path $tempVaultPath
        } catch {
            $wrongPassFailed = $true
        }
        Assert-True $wrongPassFailed "Wrong password attempt strictly rejected during multi-cycle test"

        # 3. Correct Re-Auth
        $auth2 = @(Load-Vault -MasterPassword $masterPass -Path $tempVaultPath)
        Assert-True ($auth2[0].title -eq "Alpha") "Re-authentication succeeded with correct password"

        if (Test-Path $tempVaultPath) { Remove-Item $tempVaultPath -Force }

        $results.Passed++
        $results.Log += "[PASS] Test 2: Multi-cycle Re-authentication Security Workflow"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Multi-cycle Re-authentication - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiCriticalUserOperationsTests
}
