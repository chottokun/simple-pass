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

    # Test 1: SimplePASS_JP.ps1 and SimplePASS.ps1 Japanese XAML Parsing & Control Binding
    try {
        $jpScript = Join-Path $srcDir "SimplePASS_JP.ps1"
        Assert-True (Test-Path $jpScript) "SimplePASS_JP.ps1 wrapper exists"

        $mainScript = Join-Path $srcDir "SimplePASS.ps1"
        Assert-True (Test-Path $mainScript) "SimplePASS.ps1 exists"

        $scriptContent = [System.IO.File]::ReadAllText($mainScript, [System.Text.Encoding]::UTF8)
        $xamlMatch = [regex]::Match($scriptContent, '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@')
        Assert-True $xamlMatch.Success "XAML string template extracted from SimplePASS.ps1"

        # Mock Japanese Resource Dictionary
        $res = [PSCustomObject]@{
            Title = "SimplePASS - パスワード管理ツール"
            Width = 900
            FontFamily = "Meiryo, Segoe UI"
            LoginSubtitle = "マスターパスワードを入力して保管庫を解除してください"
            LoginPasswordLabel = "マスターパスワード:"
            LoginButtonUnlock = "保管庫の解除"
            SearchTooltip = "タイトル、URL、ユーザー名、メモをリアルタイム検索..."
            BtnAddEntry = "+ 新規エントリ追加"
            BtnExportCsv = "📥 CSV出力"
            BtnChangePass = "🔑 パスワード変更"
            BtnLock = "保管庫をロック"
            ColTop = "最上部"
            ColTitle = "タイトル"
            ColUser = "ユーザー名 / ID"
            ColUrl = "URL"
            ColNote = "メモ"
            ColActions = "操作"
            BtnCopyPass = "PASSコピー"
            BtnCopyUser = "IDコピー"
            BtnEdit = "編集"
            BtnDelete = "削除"
            ReadyStatus = "準備完了"
            ModalTitleEdit = "エントリの編集"
            LabelFormTitle = "タイトル / サービス名:"
            LabelFormUrl = "URL:"
            LabelFormUsername = "ユーザー名 / ID:"
            LabelFormPassword = "パスワード:"
            BtnGeneratePass = "⚡ ランダム生成"
            LabelFormNote = "メモ:"
            BtnSave = "保存"
            BtnCancel = "キャンセル"
            ModalTitleChangePass = "マスターパスワードの変更"
            LabelCurrentPass = "現在のマスターパスワード:"
            LabelNewPass = "新しいマスターパスワード:"
            LabelConfirmNewPass = "新しいマスターパスワード (確認):"
            BtnChangeExec = "変更実行"
            BtnCancelModal = "キャンセル"
        }

        # Expand the XAML with the mock Japanese resources
        $xamlTemplate = $xamlMatch.Groups[1].Value
        $expandedXaml = $ExecutionContext.InvokeCommand.ExpandString($xamlTemplate)

        [xml]$xmlObj = $expandedXaml
        $reader = (New-Object System.Xml.XmlNodeReader $xmlObj)
        $windowObj = [Windows.Markup.XamlReader]::Load($reader)

        Assert-True ($null -ne $windowObj) "SimplePASS Japanese XAML loaded without XamlParseException"
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

        $mainScript = Join-Path $srcDir "SimplePASS.ps1"
        $scriptContent = [System.IO.File]::ReadAllText($mainScript, [System.Text.Encoding]::UTF8)

        # Parse SimplePASS.ps1 and extract Lock-VaultApp function body
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)
        $funcAst = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Lock-VaultApp' }, $true)[0]
        Assert-True ($null -ne $funcAst) "Lock-VaultApp function AST successfully extracted from SimplePASS.ps1"
        $sb = $funcAst.Body.GetScriptBlock()

        # Mock dependent functions
        $global:StopAutoLockTimerCalled = $false
        $global:UpdateLoginUIStateCalled = $false
        function Stop-AutoLockTimer { $global:StopAutoLockTimerCalled = $true }
        function Update-LoginUIState { $global:UpdateLoginUIStateCalled = $true }

        # Mock script variables
        $script:MasterPassword = "MySecretMasterPassword"
        $script:VaultEntries = @("Item1", "Item2")

        # Mock Japanese Resource for default status
        $res = [PSCustomObject]@{
            LockStatus = "保管庫をロックしました。"
        }

        # Mock WPF GUI Controls
        $dgEntries = [PSCustomObject]@{ ItemsSource = @("some", "entries") }
        $mainGrid = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }
        $entryModal = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }
        $changePassModal = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Visible }
        $loginPanel = [PSCustomObject]@{ Visibility = [System.Windows.Visibility]::Collapsed }
        $txtStatus = [PSCustomObject]@{ Text = "Initial State" }

        # Execute Lock-VaultApp with custom message
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

    # Test 3: Update-LoginUIState (Japanese Edition) - first-time setup state and existing vault state
    try {
        $jpScript = Join-Path $srcDir "SimplePASS_JP.ps1"
        $scriptContent = [System.IO.File]::ReadAllText($jpScript, [System.Text.Encoding]::UTF8)

        # Parse SimplePASS_JP.ps1 and extract Update-LoginUIState function body
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

        Assert-True ($txtLoginSubtitle.Text -eq "初回起動を検知しました。マスターパスワードを設定してください。") "Subtitle text is set for JP first run"
        Assert-True ($btnLogin.Content -eq "保管庫の新規作成") "Button content is set for JP first run"

        # Case 2: Existing vault (Vault exists)
        $global:TestVaultExistsReturnValue = $true
        & $sb

        Assert-True ($txtLoginSubtitle.Text -eq "マスターパスワードを入力して保管庫を解除してください。") "Subtitle text is set for JP unlock"
        Assert-True ($btnLogin.Content -eq "保管庫の解除") "Button content is set for JP unlock"

        $results.Passed++
        $results.Log += "[PASS] Test 3: Update-LoginUIState (JP) state rendering (First run vs Unlock)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Update-LoginUIState (JP) - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiJpTests
}
