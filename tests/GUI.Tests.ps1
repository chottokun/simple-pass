# GUI.Tests.ps1 - GUI Layer & DataBinding Integration Test Suite

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-GuiTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"

    Import-Module (Join-Path $srcDir "CryptoModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "VaultModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: DataGrid ItemsSource Single-item, Zero-item, and Multi-item Binding Safety
    try {
        $dg = New-Object System.Windows.Controls.DataGrid

        # 0件 (空配列) のバインディング
        $emptyEntries = @()
        $dg.ItemsSource = @($emptyEntries)
        Assert-True ($null -ne $dg.ItemsSource) "DataGrid accepts 0-item empty array"

        # 1件 (単一要素) のバインディング (回帰防止テスト)
        $singleEntry = New-VaultEntry -Title "SingleItem" -Password "P1"
        $dg.ItemsSource = @($singleEntry)
        Assert-True ($null -ne $dg.ItemsSource) "DataGrid accepts 1-item single entry without SetValueInvocationException"

        # 複数件のバインディング
        $multiEntries = @($singleEntry, (New-VaultEntry -Title "Item2" -Password "P2"))
        $dg.ItemsSource = @($multiEntries)
        Assert-True ($null -ne $dg.ItemsSource) "DataGrid accepts multi-item array"

        $results.Passed++
        $results.Log += "[PASS] Test 1: GUI DataGrid ItemsSource Binding Safety (0, 1, Multi items)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: GUI DataGrid ItemsSource Binding Safety - $_"
    }

    # Test 2: Search Result Binding Verification for 1-item match
    try {
        $e1 = New-VaultEntry -Title "UniqueGoogle" -Password "P1"
        $e2 = New-VaultEntry -Title "GitHub" -Password "P2"
        $all = @($e1, $e2)

        $searchResult1 = @(Search-VaultEntries -Entries $all -Keyword "google")
        Assert-True ($searchResult1.Count -eq 1) "Search returns 1 match"
        
        $dg = New-Object System.Windows.Controls.DataGrid
        $dg.ItemsSource = @($searchResult1)
        Assert-True ($null -ne $dg.ItemsSource) "DataGrid successfully binds 1-item search result"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Search Result DataGrid Binding Verification"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Search Result DataGrid Binding Verification - $_"
    }

    # Test 3: Critical: Actual SimplePASS.ps1 XAML Parsing & Window Loading
    try {
        $appScript = Join-Path $srcDir "SimplePASS.ps1"
        Assert-True (Test-Path $appScript) "SimplePASS.ps1 exists"

        $scriptContent = Get-Content $appScript -Raw
        
        # Extract XAML string from script
        $xamlMatch = [regex]::Match($scriptContent, '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@')
        Assert-True $xamlMatch.Success "XAML string extracted from SimplePASS.ps1"

        $xamlStr = $xamlMatch.Groups[1].Value
        [xml]$xmlObj = $xamlStr
        $reader = (New-Object System.Xml.XmlNodeReader $xmlObj)
        $windowObj = [Windows.Markup.XamlReader]::Load($reader)

        Assert-True ($null -ne $windowObj) "SimplePASS XAML loaded via XamlReader without XamlParseException"
        Assert-True ($null -ne $windowObj.FindName("LoginPanel")) "LoginPanel control found"
        Assert-True ($null -ne $windowObj.FindName("DgEntries")) "DgEntries control found"

        $results.Passed++
        $results.Log += "[PASS] Test 3: Critical: SimplePASS.ps1 XAML Parsing & Control Binding"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: SimplePASS.ps1 XAML Parsing - $_"
    }

    # Test 4: Update-LoginUIState - first-time setup state and existing vault state
    try {
        $appScript = Join-Path $srcDir "SimplePASS.ps1"
        $scriptContent = [System.IO.File]::ReadAllText($appScript, [System.Text.Encoding]::UTF8)

        # Parse SimplePASS.ps1 and extract Update-LoginUIState function body
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
        $funcAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-LoginUIState' }, $true)[0]
        Assert-True ($null -ne $funcAst) "Update-LoginUIState function AST successfully extracted"
        $sb = $funcAst.Body.GetScriptBlock()

        # Mock dependent functions
        $global:TestVaultExistsReturnValue = $false
        function Test-VaultExists { return $global:TestVaultExistsReturnValue }

        # Mock WPF GUI Controls
        $txtLoginSubtitle = [PSCustomObject]@{ Text = "Initial State" }
        $btnLogin = [PSCustomObject]@{ Content = "Initial Content" }

        # Case 1: First-time setup (Vault does not exist)
        $global:TestVaultExistsReturnValue = $false
        & $sb

        Assert-True ($txtLoginSubtitle.Text -eq "First run detected. Create your Master Password.") "Subtitle text is set for first run"
        Assert-True ($btnLogin.Content -eq "Create Vault") "Button content is set for first run"

        # Case 2: Existing vault (Vault exists)
        $global:TestVaultExistsReturnValue = $true
        & $sb

        Assert-True ($txtLoginSubtitle.Text -eq "Enter your Master Password to unlock") "Subtitle text is set for unlock"
        Assert-True ($btnLogin.Content -eq "Unlock Vault") "Button content is set for unlock"

        $results.Passed++
        $results.Log += "[PASS] Test 4: Update-LoginUIState state rendering (First run vs Unlock)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: Update-LoginUIState - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiTests
}
