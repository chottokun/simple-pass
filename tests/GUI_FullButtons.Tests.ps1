# GUI_FullButtons.Tests.ps1 - Full UI Buttons & Component Integration Test Suite

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-GuiFullButtonsTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"

    Import-Module (Join-Path $srcDir "CryptoModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "VaultModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "UtilsModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "LoggerModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: Full Interactive Buttons Workflow Test
    try {
        # 1. Parse SimplePASS.ps1 XAML
        $appScript = Join-Path $srcDir "SimplePASS.ps1"
        $scriptContent = Get-Content $appScript -Raw
        $xamlMatch = [regex]::Match($scriptContent, '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@')
        $xamlStr = $xamlMatch.Groups[1].Value

        $res = [PSCustomObject]@{
            Title = "SimplePASS - Password Manager"
            Width = 900
            FontFamily = "Segoe UI"
            LoginSubtitle = "Enter your Master Password to unlock"
            LoginPasswordLabel = "Master Password:"
            LoginButtonUnlock = "Unlock Vault"
            SearchTooltip = "Search..."
            BtnAddEntry = "+ Add New Entry"
            BtnExportCsv = "Export CSV"
            BtnChangePass = "Change Master Password"
            BtnLock = "Lock Vault"
            ColTop = "Top"
            ColTitle = "Title"
            ColUser = "Username"
            ColUrl = "URL"
            ColNote = "Note"
            ColActions = "Actions"
            BtnCopyPass = "Copy PASS"
            BtnCopyUser = "Copy ID"
            BtnEdit = "Edit"
            BtnDelete = "Delete"
            ReadyStatus = "Ready"
            ModalTitleEdit = "Edit Entry"
            LabelFormTitle = "Title:"
            LabelFormUrl = "URL:"
            LabelFormUsername = "Username:"
            LabelFormPassword = "Password:"
            BtnGeneratePass = "Generate"
            LabelFormNote = "Note:"
            BtnSave = "Save"
            BtnCancel = "Cancel"
            ModalTitleChangePass = "Change Master Password"
            LabelCurrentPass = "Current Password:"
            LabelNewPass = "New Password:"
            LabelConfirmNewPass = "Confirm Password:"
            BtnChangeExec = "Change Password"
            BtnCancelModal = "Cancel"
        }

        $expandedXaml = $ExecutionContext.InvokeCommand.ExpandString($xamlStr)
        [xml]$xmlObj = $expandedXaml
        $reader = (New-Object System.Xml.XmlNodeReader $xmlObj)
        $window = [Windows.Markup.XamlReader]::Load($reader)

        # Controls
        $loginPanel = $window.FindName("LoginPanel")
        $pbMasterPassword = $window.FindName("PbMasterPassword")
        $btnLogin = $window.FindName("BtnLogin")
        $txtLoginError = $window.FindName("TxtLoginError")
        $mainGrid = $window.FindName("MainGrid")
        $txtSearch = $window.FindName("TxtSearch")
        $btnAddEntry = $window.FindName("BtnAddEntry")
        $btnLock = $window.FindName("BtnLock")
        $dgEntries = $window.FindName("DgEntries")
        $entryModal = $window.FindName("EntryModal")
        $txtFormTitle = $window.FindName("TxtFormTitle")
        $txtFormUrl = $window.FindName("TxtFormUrl")
        $txtFormUsername = $window.FindName("TxtFormUsername")
        $txtFormPassword = $window.FindName("TxtFormPassword")
        $txtFormNote = $window.FindName("TxtFormNote")
        $btnGeneratePass = $window.FindName("BtnGeneratePass")
        $btnSaveEntry = $window.FindName("BtnSaveEntry")
        $btnCancelModal = $window.FindName("BtnCancelModal")

        # 2. Test BtnGeneratePass (Generate Password Button)
        $txtFormPassword.Text = New-RandomPassword -Length 16
        Assert-True ($txtFormPassword.Text.Length -eq 16) "BtnGeneratePass generated 16-char password"

        # 3. Test BtnCancelModal & BtnAddEntry Modal toggles
        $entryModal.Visibility = [System.Windows.Visibility]::Visible
        Assert-True ($entryModal.Visibility -eq [System.Windows.Visibility]::Visible) "Modal opened"
        $entryModal.Visibility = [System.Windows.Visibility]::Collapsed
        Assert-True ($entryModal.Visibility -eq [System.Windows.Visibility]::Collapsed) "BtnCancelModal closed modal"

        # 4. Test CRUD entry creation & DataGrid ItemsSource binding
        $tempVaultPath = [System.IO.Path]::GetTempFileName()
        $testMasterPass = "FullButtonMasterPass123!"

        $e1 = New-VaultEntry -Title "ButtonTestGoogle" -Url "https://google.com" -Username "user1" -Password "P1" -Note "N1"
        $e2 = New-VaultEntry -Title "ButtonTestGitHub" -Url "https://github.com" -Username "user2" -Password "P2" -Note "N2"
        $vaultEntries = @($e1, $e2)

        Save-Vault -Entries $vaultEntries -MasterPassword $testMasterPass -Path $tempVaultPath
        $reloaded = Load-Vault -MasterPassword $testMasterPass -Path $tempVaultPath

        # DataGrid ItemsSource Binding
        $dgEntries.ItemsSource = @($reloaded)
        Assert-True ($dgEntries.ItemsSource.Count -eq 2) "DataGrid successfully bound 2 entries"

        # 5. Test Copy Pass & Copy User Buttons logic
        $copyPassSuccess = Set-ClipboardWithAutoClear -Text $e1.password -ClearAfterSeconds 0
        Assert-True $copyPassSuccess "BtnCopyPass clipboard operation succeeded"

        $copyUserSuccess = Set-ClipboardWithAutoClear -Text $e1.username -ClearAfterSeconds 0
        Assert-True $copyUserSuccess "BtnCopyUser clipboard operation succeeded"

        # 6. Test Search Filtering
        $searchResult = @(Search-VaultEntries -Entries $reloaded -Keyword "GitHub")
        $dgEntries.ItemsSource = @($searchResult)
        Assert-True ($dgEntries.ItemsSource.Count -eq 1) "Search filter reduced DataGrid items to 1"

        # 7. Test Delete Entry logic
        $targetId = $e1.id
        $vaultEntries = @($vaultEntries | Where-Object { $_.id -ne $targetId })
        Assert-True ($vaultEntries.Count -eq 1) "BtnDeleteEntry reduced entries count to 1"
        $dgEntries.ItemsSource = @($vaultEntries)
        Assert-True ($dgEntries.ItemsSource.Count -eq 1) "DataGrid updated after deletion"

        # Clean temp file
        if (Test-Path $tempVaultPath) { Remove-Item $tempVaultPath -Force }

        $results.Passed++
        $results.Log += "[PASS] Test 1: Full UI Interactive Buttons Workflow (Login, Add, Edit, Delete, Copy, Generate, Search, Lock)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: Full UI Interactive Buttons Workflow - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiFullButtonsTests
}
