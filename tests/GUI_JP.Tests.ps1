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

    # Test 3: Start-AutoLockTimer and Stop-AutoLockTimer Mechanics
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

        # Parse SimplePASS_JP.ps1 and extract Start-AutoLockTimer and Stop-AutoLockTimer function bodies
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)

        $startFuncAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Start-AutoLockTimer' }, $true)[0]
        Assert-True ($null -ne $startFuncAst) "Start-AutoLockTimer function AST successfully extracted"
        $startSb = $startFuncAst.Body.GetScriptBlock()

        $stopFuncAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stop-AutoLockTimer' }, $true)[0]
        Assert-True ($null -ne $stopFuncAst) "Stop-AutoLockTimer function AST successfully extracted"
        $stopSb = $stopFuncAst.Body.GetScriptBlock()

        # Mock dependent functions
        $global:LockVaultAppCalled = $false
        $global:LockVaultAppStatusText = $null
        function Lock-VaultApp {
            param([string]$StatusText)
            $global:LockVaultAppCalled = $true
            $global:LockVaultAppStatusText = $StatusText
        }

        # Mock New-Object to intercept DispatcherTimer instantiation on Linux
        function New-Object {
            param(
                [string]$TypeName,
                [object[]]$ArgumentList
            )
            if ($TypeName -eq "System.Windows.Threading.DispatcherTimer") {
                $mockTimer = [PSCustomObject]@{
                    Interval = $null
                    TickHandlers = [System.Collections.Generic.List[scriptblock]]::new()
                    StartCalled = $false
                    StopCalled = $false
                }
                $mockTimer | Add-Member -MemberType ScriptMethod -Name "Add_Tick" -Value {
                    param($sb)
                    $this.TickHandlers.Add($sb)
                }
                $mockTimer | Add-Member -MemberType ScriptMethod -Name "Start" -Value {
                    $this.StartCalled = $true
                }
                $mockTimer | Add-Member -MemberType ScriptMethod -Name "Stop" -Value {
                    $this.StopCalled = $true
                }
                return $mockTimer
            } else {
                Microsoft.PowerShell.Utility\New-Object -TypeName $TypeName -ArgumentList $ArgumentList
            }
        }

        # Mock script variables
        $script:AutoLockTimer = $null
        $script:LastActivityTime = $null

        # Mock GUI Controls
        $mainGrid = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }

        # Execute Start-AutoLockTimer
        & $startSb

        # Verify timer is created and configured correctly
        Assert-True ($null -ne $script:AutoLockTimer) "AutoLockTimer was created"
        Assert-True ($script:AutoLockTimer.Interval -eq [TimeSpan]::FromSeconds(30)) "AutoLockTimer Interval was set to 30 seconds"
        Assert-True ($script:AutoLockTimer.StartCalled) "AutoLockTimer.Start() was called"
        Assert-True ($script:AutoLockTimer.TickHandlers.Count -eq 1) "One Tick handler was registered"

        # Verify LastActivityTime is updated
        $now = [DateTime]::Now
        $diff = ($now - $script:LastActivityTime).TotalSeconds
        Assert-True ($diff -lt 5 -and $diff -ge 0) "LastActivityTime was updated to now"

        # Verify tick handler logic
        $tickHandler = $script:AutoLockTimer.TickHandlers[0]

        # Case A: Idle time >= 5 minutes AND mainGrid is Visible -> should lock vault
        $script:LastActivityTime = [DateTime]::Now.AddMinutes(-6)
        $mainGrid.Visibility = [System.Windows.Visibility]::Visible
        $global:LockVaultAppCalled = $false
        $global:LockVaultAppStatusText = $null
        & $tickHandler
        Assert-True $global:LockVaultAppCalled "Lock-VaultApp was called when idle and visible"
        Assert-True ($global:LockVaultAppStatusText -eq "5分間無操作のため自動ロックされました。") "Lock-VaultApp status text is correct"

        # Case B: Idle time < 5 minutes AND mainGrid is Visible -> should NOT lock vault
        $script:LastActivityTime = [DateTime]::Now.AddMinutes(-4)
        $mainGrid.Visibility = [System.Windows.Visibility]::Visible
        $global:LockVaultAppCalled = $false
        & $tickHandler
        Assert-True (-not $global:LockVaultAppCalled) "Lock-VaultApp was not called when idle for less than 5 minutes"

        # Case C: Idle time >= 5 minutes AND mainGrid is NOT Visible -> should NOT lock vault
        $script:LastActivityTime = [DateTime]::Now.AddMinutes(-6)
        $mainGrid.Visibility = [System.Windows.Visibility]::Collapsed
        $global:LockVaultAppCalled = $false
        & $tickHandler
        Assert-True (-not $global:LockVaultAppCalled) "Lock-VaultApp was not called when mainGrid is collapsed"

        # Verify Stop-AutoLockTimer stops the timer
        Assert-True (-not $script:AutoLockTimer.StopCalled) "Stop() has not been called on timer yet"
        & $stopSb
        Assert-True $script:AutoLockTimer.StopCalled "Stop-AutoLockTimer stopped the active timer"

        $results.Passed++
        $results.Log += "[PASS] Test 3: Start-AutoLockTimer and Stop-AutoLockTimer Mechanics"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Start-AutoLockTimer and Stop-AutoLockTimer Mechanics - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiJpTests
}
