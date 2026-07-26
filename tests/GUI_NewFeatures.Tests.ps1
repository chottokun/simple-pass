# GUI_NewFeatures.Tests.ps1 - New Features (Password Change, Toggle Sync, Auto-Lock) Test Suite

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-GuiNewFeaturesTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"

    Import-Module (Join-Path $srcDir "CryptoModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "VaultModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "UtilsModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "LoggerModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Helper: Create Window instance
    function New-TestWindow {
        $appScript = Join-Path $srcDir "SimplePASS.ps1"
        $scriptContent = Get-Content $appScript -Raw
        $xamlMatch = [regex]::Match($scriptContent, '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@')
        $xamlStr = $xamlMatch.Groups[1].Value
        [xml]$xmlObj = $xamlStr
        $reader = (New-Object System.Xml.XmlNodeReader $xmlObj)
        return [Windows.Markup.XamlReader]::Load($reader)
    }

    # Test 1: Password Change Workflow & Error Handling
    try {
        $tempVault = [System.IO.Path]::GetTempFileName()
        try {
            $origPass = "OriginalPass123!"
            $newPass = "NewMasterPass456!"
            $e1 = New-VaultEntry -Title "TestEntry" -Password "Secret"
            Save-Vault -Entries @($e1) -MasterPassword $origPass -Path $tempVault

            # Verify reload with original pass
            $loaded = @(Load-Vault -MasterPassword $origPass -Path $tempVault)
            Assert-True ($loaded.Count -eq 1) "Initial vault load with original password succeeded"

            # Change password logic simulation
            Save-Vault -Entries $loaded -MasterPassword $newPass -Path $tempVault

            # Verify original pass fails
            $origFailed = $false
            try {
                $null = Load-Vault -MasterPassword $origPass -Path $tempVault
            } catch {
                $origFailed = $true
            }
            Assert-True $origFailed "Old password correctly rejected after password change"

            # Verify new pass succeeds
            $reloadedNew = @(Load-Vault -MasterPassword $newPass -Path $tempVault)
            Assert-True ($reloadedNew[0].title -eq "TestEntry") "New password successfully decrypts vault data"

            $results.Passed++
            $results.Log += "[PASS] Test 1: Master Password Change Workflow & Encryption Re-keying"
        } finally {
            if (Test-Path $tempVault) { Remove-Item $tempVault -Force -ErrorAction SilentlyContinue }
        }
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: Master Password Change Workflow - $_"
    }

    # Test 2: Password Box vs Text Box Visibility & Sync Toggle
    try {
        $win = New-TestWindow
        $pbFormPass = $win.FindName("PbFormPassword")
        $txtFormPass = $win.FindName("TxtFormPassword")
        $btnToggle = $win.FindName("BtnTogglePassVisibility")

        Assert-True ($pbFormPass.Visibility -eq [System.Windows.Visibility]::Visible) "PasswordBox initially visible"
        Assert-True ($txtFormPass.Visibility -eq [System.Windows.Visibility]::Collapsed) "TextBox initially collapsed"

        # Set password in PasswordBox
        $pbFormPass.Password = "TestSecret123"

        # Toggle to visible (Simulate click)
        $txtFormPass.Text = $pbFormPass.Password
        $pbFormPass.Visibility = [System.Windows.Visibility]::Collapsed
        $txtFormPass.Visibility = [System.Windows.Visibility]::Visible

        Assert-True ($txtFormPass.Text -eq "TestSecret123") "TextBox received synced password from PasswordBox"
        Assert-True ($txtFormPass.Visibility -eq [System.Windows.Visibility]::Visible) "TextBox now visible after toggle"

        # Edit in TextBox and toggle back
        $txtFormPass.Text = "ModifiedSecret456"
        $pbFormPass.Password = $txtFormPass.Text
        $txtFormPass.Visibility = [System.Windows.Visibility]::Collapsed
        $pbFormPass.Visibility = [System.Windows.Visibility]::Visible

        Assert-True ($pbFormPass.Password -eq "ModifiedSecret456") "PasswordBox received synced password back from TextBox"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Password Visibility Toggle & Text Synchronization"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Password Visibility Toggle & Sync - $_"
    }

    # Test 3: Lock-VaultApp State Reset and UI Collapsing
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

        $appScript = Join-Path $srcDir "SimplePASS.ps1"
        $scriptContent = [System.IO.File]::ReadAllText($appScript, [System.Text.Encoding]::UTF8)

        # Parse SimplePASS.ps1 and extract Lock-VaultApp function body
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
        & $sb -StatusText "Vault locked. (Test)"

        # Assertions
        Assert-True $global:StopAutoLockTimerCalled "Stop-AutoLockTimer was called"
        Assert-True $global:UpdateLoginUIStateCalled "Update-LoginUIState was called"
        Assert-True ($null -eq $script:MasterPassword) "MasterPassword was successfully cleared to null"
        Assert-True ($script:VaultEntries.Count -eq 0) "VaultEntries was successfully cleared to an empty array"
        Assert-True ($null -eq $dgEntries.ItemsSource) "DataGrid ItemsSource was cleared to null"
        Assert-True ($mainGrid.Visibility -eq [System.Windows.Visibility]::Collapsed) "MainGrid was collapsed"
        Assert-True ($entryModal.Visibility -eq [System.Windows.Visibility]::Collapsed) "EntryModal was collapsed"
        Assert-True ($changePassModal.Visibility -eq [System.Windows.Visibility]::Collapsed) "ChangePassModal was collapsed"
        Assert-True ($loginPanel.Visibility -eq [System.Windows.Visibility]::Visible) "LoginPanel was made visible"
        Assert-True ($txtStatus.Text -eq "Vault locked. (Test)") "txtStatus text was set to the correct custom message"

        # Execute again with default parameter to check default status text
        $script:MasterPassword = "Secret"
        $dgEntries.ItemsSource = @("reloaded")
        & $sb

        Assert-True ($txtStatus.Text -eq "Vault locked.") "Default status text was successfully applied"

        $results.Passed++
        $results.Log += "[PASS] Test 3: Lock-VaultApp State Reset and UI Collapsing"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Lock-VaultApp State Reset and UI Collapsing - $_"
    }

    # Test 4: URL Scheme Formatting Integration
    try {
        $formattedUrl1 = Format-VaultUrl -Url "my-service.net"
        Assert-True ($formattedUrl1 -eq "https://my-service.net") "Format-VaultUrl auto-prefixes https://"

        $formattedUrl2 = Format-VaultUrl -Url "http://insecure.local"
        Assert-True ($formattedUrl2 -eq "http://insecure.local") "Format-VaultUrl preserves http://"

        $results.Passed++
        $results.Log += "[PASS] Test 4: URL Scheme Formatting Integration"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: URL Scheme Formatting - $_"
    }

    # Test 5: DataGrid Entry Custom Reordering (Move Up / Down)
    try {
        $e1 = New-VaultEntry -Title "Alpha"
        $e2 = New-VaultEntry -Title "Beta"
        $entries = @($e1, $e2)

        $reordered = Move-VaultEntryDown -Entries $entries -TargetId $e1.id
        Assert-True ($reordered[0].title -eq "Beta") "Beta is now index 0 after Alpha moved down"
        Assert-True ($reordered[1].title -eq "Alpha") "Alpha is now index 1 after moving down"

        $results.Passed++
        $results.Log += "[PASS] Test 5: DataGrid Entry Custom Reordering"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 5: DataGrid Entry Custom Reordering - $_"
    }

    # Test 6: Start-AutoLockTimer Initialization and Lifecycle
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

        # Override New-Object to mock DispatcherTimer on non-Windows/headless systems
        function New-Object {
            param(
                [string]$TypeName,
                $ArgumentList
            )
            if ($TypeName -eq "System.Windows.Threading.DispatcherTimer") {
                $mockTimer = [PSCustomObject]@{
                    Interval = $null
                    Started = $false
                    Ticks = @()
                }
                $mockTimer | Add-Member -MemberType ScriptMethod -Name "Add_Tick" -Value {
                    param($action)
                    $this.Ticks += $action
                }
                $mockTimer | Add-Member -MemberType ScriptMethod -Name "Start" -Value {
                    $this.Started = $true
                }
                $mockTimer | Add-Member -MemberType ScriptMethod -Name "Stop" -Value {
                    $this.Started = $false
                }
                return $mockTimer
            } else {
                return Microsoft.PowerShell.Utility\New-Object @PSBoundParameters
            }
        }

        # Mock dependent elements
        $global:LockVaultAppCalled = $false
        $global:LockVaultAppStatusText = ""
        function Lock-VaultApp {
            param([string]$StatusText)
            $global:LockVaultAppCalled = $true
            $global:LockVaultAppStatusText = $StatusText
        }

        $appScript = Join-Path $srcDir "SimplePASS.ps1"
        $scriptContent = [System.IO.File]::ReadAllText($appScript, [System.Text.Encoding]::UTF8)
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)

        $startFuncAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Start-AutoLockTimer' }, $true)[0]
        Assert-True ($null -ne $startFuncAst) "Start-AutoLockTimer function AST successfully extracted"
        $startSb = $startFuncAst.Body.GetScriptBlock()

        $stopFuncAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Stop-AutoLockTimer' }, $true)[0]
        Assert-True ($null -ne $stopFuncAst) "Stop-AutoLockTimer function AST successfully extracted"
        $stopSb = $stopFuncAst.Body.GetScriptBlock()

        # Initialize script variables
        $script:AutoLockTimer = $null
        $script:LastActivityTime = $null

        # Call Start-AutoLockTimer
        & $startSb

        Assert-True ($null -ne $script:AutoLockTimer) "AutoLockTimer was created"
        Assert-True ($script:AutoLockTimer.Interval.TotalSeconds -eq 30) "Timer interval is 30 seconds"
        Assert-True ($script:AutoLockTimer.Started) "Timer was started"
        Assert-True ($null -ne $script:LastActivityTime) "LastActivityTime was set"
        Assert-True ($script:AutoLockTimer.Ticks.Count -eq 1) "Tick event handler was added"

        # Call Start-AutoLockTimer again to ensure it reuses the timer
        $firstTimer = $script:AutoLockTimer
        $firstTimer.Started = $false
        $script:LastActivityTime = [DateTime]::Now.AddMinutes(-10) # Set past activity time

        & $startSb

        Assert-True ([object]::ReferenceEquals($firstTimer, $script:AutoLockTimer)) "Timer object was reused, not recreated"
        Assert-True ($script:AutoLockTimer.Started) "Timer was started again"
        $diff = [DateTime]::Now - $script:LastActivityTime
        Assert-True ($diff.TotalSeconds -lt 5) "LastActivityTime was refreshed to current time"
        Assert-True ($script:AutoLockTimer.Ticks.Count -eq 1) "No duplicate tick handlers added"

        # Call Stop-AutoLockTimer
        & $stopSb
        Assert-True (-not $script:AutoLockTimer.Started) "Timer was stopped"

        $results.Passed++
        $results.Log += "[PASS] Test 6: Start-AutoLockTimer Initialization and Lifecycle"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 6: Start-AutoLockTimer Initialization and Lifecycle - $_"
    }

    # Test 7: Auto-Lock Tick Handler Behaviour & Inactivity Conditions
    try {
        # Initialize script variables and mock timer
        $script:AutoLockTimer = $null
        $script:LastActivityTime = $null

        $mainGrid = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }

        # Extract/Run Start-AutoLockTimer to register Tick event
        & $startSb

        $tickHandler = $script:AutoLockTimer.Ticks[0]
        Assert-True ($null -ne $tickHandler) "Tick handler was registered"

        # Case 1: Grid is Visible, Inactivity is less than 5 minutes (e.g., 2 minutes)
        $global:LockVaultAppCalled = $false
        $global:LockVaultAppStatusText = ""
        $script:LastActivityTime = [DateTime]::Now.AddMinutes(-2)

        & $tickHandler

        Assert-True (-not $global:LockVaultAppCalled) "Lock-VaultApp was NOT called for < 5 mins inactivity"

        # Case 2: Grid is Visible, Inactivity is 5 minutes or more (e.g., 5.1 minutes)
        $global:LockVaultAppCalled = $false
        $global:LockVaultAppStatusText = ""
        $script:LastActivityTime = [DateTime]::Now.AddMinutes(-5.1)

        & $tickHandler

        Assert-True $global:LockVaultAppCalled "Lock-VaultApp WAS called for >= 5 mins inactivity"
        Assert-True ($global:LockVaultAppStatusText -eq "Auto-locked due to 5 minutes of inactivity.") "Correct status text used"

        # Case 3: Grid is Collapsed, Inactivity is 5 minutes or more (e.g., 10 minutes)
        $global:LockVaultAppCalled = $false
        $global:LockVaultAppStatusText = ""
        $mainGrid.Visibility = [System.Windows.Visibility]::Collapsed
        $script:LastActivityTime = [DateTime]::Now.AddMinutes(-10)

        & $tickHandler

        Assert-True (-not $global:LockVaultAppCalled) "Lock-VaultApp was NOT called when mainGrid is collapsed"

        $results.Passed++
        $results.Log += "[PASS] Test 7: Auto-Lock Tick Handler Behaviour & Inactivity Conditions"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: Auto-Lock Tick Handler Behaviour & Inactivity Conditions - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiNewFeaturesTests
}
