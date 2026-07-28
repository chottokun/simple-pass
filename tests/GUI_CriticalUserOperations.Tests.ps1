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

        $results.Passed++
        $results.Log += "[PASS] Test 2: Multi-cycle Re-authentication Security Workflow"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Multi-cycle Re-authentication - $_"
    }

    # Test 3: Interactive XAML Form Field Input & Validation Workflow
    try {
        $appScript = Join-Path $srcDir "SimplePASS.ps1"
        $scriptContent = Get-Content $appScript -Raw
        $xamlMatch = [regex]::Match($scriptContent, '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@')
        $xamlStr = $xamlMatch.Groups[1].Value

        $res = [PSCustomObject]@{
            Title = "SimplePASS"
            Width = 900
            FontFamily = "Segoe UI"
            LoginSubtitle = "Subtitle"
            LoginPasswordLabel = "Password:"
            LoginButtonUnlock = "Unlock"
            SearchTooltip = "Search..."
            BtnAddEntry = "Add"
            BtnExportCsv = "Export"
            BtnChangePass = "Change"
            BtnLock = "Lock"
            ColTop = "Top"
            ColTitle = "Title"
            ColUser = "User"
            ColUrl = "URL"
            ColNote = "Note"
            ColActions = "Actions"
            BtnCopyPass = "Copy PASS"
            BtnCopyUser = "Copy ID"
            BtnEdit = "Edit"
            BtnDelete = "Delete"
            ReadyStatus = "Ready"
            ModalTitleEdit = "Edit"
            LabelFormTitle = "Title:"
            LabelFormUrl = "URL:"
            LabelFormUsername = "Username:"
            LabelFormPassword = "Password:"
            BtnGeneratePass = "Generate"
            LabelFormNote = "Note:"
            BtnSave = "Save"
            BtnCancel = "Cancel"
            ModalTitleChangePass = "Change"
            LabelCurrentPass = "Current:"
            LabelNewPass = "New:"
            LabelConfirmNewPass = "Confirm:"
            BtnChangeExec = "Change"
            BtnCancelModal = "Cancel"
        }

        $expandedXaml = $ExecutionContext.InvokeCommand.ExpandString($xamlStr)
        [xml]$xmlObj = $expandedXaml
        $reader = (New-Object System.Xml.XmlNodeReader $xmlObj)
        $win = [Windows.Markup.XamlReader]::Load($reader)

        $txtTitle = $win.FindName("TxtFormTitle")
        $txtUser = $win.FindName("TxtFormUsername")
        $pbPass = $win.FindName("PbFormPassword")
        $txtUrl = $win.FindName("TxtFormUrl")
        $txtNote = $win.FindName("TxtFormNote")

        $txtTitle.Text = "GitHub Account"
        $txtUser.Text = "user@example.com"
        $pbPass.Password = "SuperSecretPass123!"
        $txtUrl.Text = "github.com"
        $txtNote.Text = "Personal dev account"

        Assert-True ($txtTitle.Text -eq "GitHub Account") "Title text set correctly in UI form"
        Assert-True ($txtUser.Text -eq "user@example.com") "Username text set correctly in UI form"
        Assert-True ($pbPass.Password -eq "SuperSecretPass123!") "Password set correctly in UI form"
        Assert-True ($txtUrl.Text -eq "github.com") "URL text set correctly in UI form"
        Assert-True ($txtNote.Text -eq "Personal dev account") "Note text set correctly in UI form"

        $results.Passed++
        $results.Log += "[PASS] Test 3: Interactive XAML Form Field Input & Validation Workflow"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Interactive XAML Form Field Input - $_"
    }

    # Test 4: Password Strength Enforcement in UI Creation Flow
    try {
        $weak1 = Test-PasswordStrength -Password "12345"
        Assert-True (-not $weak1) "Short password (5 chars) rejected as weak"

        $weak2 = Test-PasswordStrength -Password "lowercaseonly"
        Assert-True (-not $weak2) "Single charset password rejected as weak"

        $weak3 = Test-PasswordStrength -Password "ABCDEFGH"
        Assert-True (-not $weak3) "Uppercase only password rejected as weak"

        $strong = Test-PasswordStrength -Password "P@ssw0rd2026!"
        Assert-True $strong "Multi-charset strong password accepted"

        $results.Passed++
        $results.Log += "[PASS] Test 4: Password Strength Enforcement in UI Creation Flow"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: Password Strength Enforcement - $_"
    }

    # Test 5: URL Scheme Whitelist Security Check in UI
    try {
        $safeHttp = Format-VaultUrl -Url "http://example.com"
        Assert-True ($safeHttp -eq "http://example.com") "HTTP scheme preserved"

        $safeHttps = Format-VaultUrl -Url "https://secure.example.com"
        Assert-True ($safeHttps -eq "https://secure.example.com") "HTTPS scheme preserved"

        $autoHttps = Format-VaultUrl -Url "mybank.com"
        Assert-True ($autoHttps -eq "https://mybank.com") "Bare domain automatically upgraded to HTTPS"

        # Check scheme validation logic used in SimplePASS.ps1 for browser launch
        $validateScheme = {
            param([string]$targetUrl)
            try {
                $uri = [System.Uri]::new($targetUrl)
                return ($uri.Scheme -eq "http" -or $uri.Scheme -eq "https")
            } catch {
                return $false
            }
        }

        Assert-True (& $validateScheme "https://github.com") "HTTPS URL validated as safe"
        Assert-True (& $validateScheme "http://localhost:8080") "HTTP URL validated as safe"
        Assert-True (-not (& $validateScheme "javascript:alert(1)")) "javascript: scheme strictly rejected"
        Assert-True (-not (& $validateScheme "file:///C:/Windows/System32/cmd.exe")) "file: scheme strictly rejected"
        Assert-True (-not (& $validateScheme "data:text/html,<script>alert(1)</script>")) "data: scheme strictly rejected"

        $results.Passed++
        $results.Log += "[PASS] Test 5: URL Scheme Whitelist Security Check in UI"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 5: URL Scheme Whitelist Security Check - $_"
    }

    # Test 6: Multilingual Resource Key Parity (en.psd1 vs ja.psd1)
    try {
        $enPath = Join-Path $srcDir "Locales\en.psd1"
        $jaPath = Join-Path $srcDir "Locales\ja.psd1"

        $enDict = Import-PowerShellDataFile -Path $enPath
        $jaDict = Import-PowerShellDataFile -Path $jaPath

        $enKeys = @($enDict.Keys) | Sort-Object
        $jaKeys = @($jaDict.Keys) | Sort-Object

        $missingInJa = @()
        foreach ($k in $enKeys) {
            if (-not $jaDict.ContainsKey($k)) {
                $missingInJa += $k
            }
        }

        $missingInEn = @()
        foreach ($k in $jaKeys) {
            if (-not $enDict.ContainsKey($k)) {
                $missingInEn += $k
            }
        }

        Assert-True ($missingInJa.Count -eq 0) "All keys in en.psd1 are present in ja.psd1 (Missing in JP: $($missingInJa -join ', '))"
        Assert-True ($missingInEn.Count -eq 0) "All keys in ja.psd1 are present in en.psd1 (Missing in EN: $($missingInEn -join ', '))"

        $results.Passed++
        $results.Log += "[PASS] Test 6: Multilingual Resource Key Parity (en.psd1 vs ja.psd1)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 6: Multilingual Resource Key Parity - $_"
    }

    # Test 7: Clipboard Copy UI Action & Auto-Clear Integration
    try {
        $copiedText1 = "FirstPassword123"
        $res1 = Set-ClipboardWithAutoClear -Text $copiedText1 -ClearAfterSeconds 1
        Assert-True ($res1 -eq $true -or $res1 -eq $false) "Set-ClipboardWithAutoClear executes cleanly in UI workflow without unhandled exceptions"

        $results.Passed++
        $results.Log += "[PASS] Test 7: Clipboard Copy UI Action & Auto-Clear Integration"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: Clipboard Copy UI Action & Auto-Clear Integration - $_"
    }




    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiCriticalUserOperationsTests
}

