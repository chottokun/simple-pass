# GUI_JP.Tests.ps1 - Japanese Edition XAML & Interface Test Suite

try { Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue } catch {}
try { Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue } catch {}
try { Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue } catch {}

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-GuiJpTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: SimplePASS_JP.ps1 XAML Parsing & Control Binding
    try {
        $jpScript = Join-Path $srcDir "SimplePASS_JP.ps1"
        Assert-True (Test-Path $jpScript) "SimplePASS_JP.ps1 exists"

        $scriptContent = [System.IO.File]::ReadAllText($jpScript, [System.Text.Encoding]::UTF8)
        $xamlMatch = [regex]::Match($scriptContent, '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@')
        Assert-True $xamlMatch.Success "XAML string extracted from SimplePASS_JP.ps1"

        $xamlStr = $xamlMatch.Groups[1].Value
        [xml]$xmlObj = $xamlStr
        $reader = (New-Object System.Xml.XmlNodeReader $xmlObj)
        $windowObj = [Windows.Markup.XamlReader]::Load($reader)

        Assert-True ($null -ne $windowObj) "SimplePASS_JP XAML loaded without XamlParseException"
        Assert-True ($windowObj.Title.StartsWith("SimplePASS")) "Japanese Window Title loaded"
        Assert-True ($null -ne $windowObj.FindName("LoginPanel")) "LoginPanel found in JP edition"
        Assert-True ($null -ne $windowObj.FindName("DgEntries")) "DgEntries found in JP edition"

        $results.Passed++
        $results.Log += "[PASS] Test 1: SimplePASS_JP.ps1 XAML Parsing & Japanese Controls Binding"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: SimplePASS_JP.ps1 XAML Parsing - $_"
    }

    # Test 2: Lock-VaultApp State Reset and UI Collapsing
    try {
        # Ensure System.Windows.Visibility type exists (especially on Linux)
        try {
            $null = [System.Windows.Visibility]
        } catch {
            $definition = @'
            namespace System.Windows {
                public enum Visibility {
                    Visible = 0,
                    Hidden = 1,
                    Collapsed = 2
                }
            }
'@
            Add-Type -TypeDefinition $definition -ErrorAction SilentlyContinue
        }

        $jpScript = Join-Path $srcDir "SimplePASS_JP.ps1"
        $scriptContent = [System.IO.File]::ReadAllText($jpScript, [System.Text.Encoding]::UTF8)

        # Parse SimplePASS_JP.ps1 and extract Lock-VaultApp function body
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
        $funcAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Lock-VaultApp' }, $true)[0]
        Assert-True ($null -ne $funcAst) "Lock-VaultApp function AST successfully extracted"
        $sb = $funcAst.Body.GetScriptBlock()

        # Mock dependent functions
        $global:StopAutoLockTimerCalled = $false
        $global:UpdateLoginUIStateCalled = $false
        function Stop-AutoLockTimer { $global:StopAutoLockTimerCalled = $true }
        function Update-LoginUIState { $global:UpdateLoginUIStateCalled = $true }

        # Mock script variables
        $script:MasterPassword = "MySecretMasterPassword"
        $script:VaultEntries = @("Item1", "Item2")

        # Mock WPF GUI Controls
        $dgEntries = [PSCustomObject]@{ ItemsSource = @("some", "entries") }
        $mainGrid = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }
        $entryModal = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }
        $changePassModal = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }
        $loginPanel = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Collapsed }
        $txtStatus = [PSCustomObject]@{ Text = "Initial State" }

        # Execute Lock-VaultApp
        & $sb -StatusText "保管庫をロックしました。(テスト)"

        # Assertions
        Assert-True $global:StopAutoLockTimerCalled "Stop-AutoLockTimer was called"
        Assert-True $global:UpdateLoginUIStateCalled "Update-LoginUIState was called"
        Assert-True ($null -eq $script:MasterPassword) "MasterPassword was successfully cleared to $null"
        Assert-True ($script:VaultEntries.Count -eq 0) "VaultEntries was successfully cleared to an empty array"
        Assert-True ($null -eq $dgEntries.ItemsSource) "DataGrid ItemsSource was cleared to $null"
        Assert-True ($mainGrid.Visibility -eq [System.Windows.Visibility]::Collapsed) "MainGrid was collapsed"
        Assert-True ($entryModal.Visibility -eq [System.Windows.Visibility]::Collapsed) "EntryModal was collapsed"
        Assert-True ($changePassModal.Visibility -eq [System.Windows.Visibility]::Collapsed) "ChangePassModal was collapsed"
        Assert-True ($loginPanel.Visibility -eq [System.Windows.Visibility]::Visible) "LoginPanel was made visible"
        Assert-True ($txtStatus.Text -eq "保管庫をロックしました。(テスト)") "txtStatus text was set to the correct custom message"

        # Execute again with default parameter to check default status text
        $script:MasterPassword = "Secret"
        $dgEntries.ItemsSource = @("reloaded")
        & $sb

        Assert-True ($txtStatus.Text -eq "保管庫をロックしました。") "Default status text was successfully applied"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Lock-VaultApp State Reset and UI Collapsing"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Lock-VaultApp State Reset and UI Collapsing - $_"
    }

    # Test 3: Stop-AutoLockTimer Functionality Verification
    try {
        $jpScript = Join-Path $srcDir "SimplePASS_JP.ps1"
        $scriptContent = [System.IO.File]::ReadAllText($jpScript, [System.Text.Encoding]::UTF8)

        # Parse SimplePASS_JP.ps1 and extract Stop-AutoLockTimer function body
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
        $funcAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stop-AutoLockTimer' }, $true)[0]
        Assert-True ($null -ne $funcAst) "Stop-AutoLockTimer function AST successfully extracted from JP edition"
        $sb = $funcAst.Body.GetScriptBlock()

        # Scenario A: When $script:AutoLockTimer is null, calling the function should not throw or fail
        $script:AutoLockTimer = $null
        & $sb

        # Scenario B: When $script:AutoLockTimer is set, calling the function should trigger the Stop method
        $global:AutoLockTimerStopped = $false
        $script:AutoLockTimer = New-Object PSObject
        $script:AutoLockTimer | Add-Member -MemberType ScriptMethod -Name Stop -Value {
            $global:AutoLockTimerStopped = $true
        }
        & $sb
        Assert-True $global:AutoLockTimerStopped "Stop-AutoLockTimer successfully invoked Stop() on the timer object in JP edition"

        # Cleanup
        $script:AutoLockTimer = $null

        $results.Passed++
        $results.Log += "[PASS] Test 3: Stop-AutoLockTimer Functionality Verification (JP)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Stop-AutoLockTimer Functionality (JP) - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiJpTests
}
