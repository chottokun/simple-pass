# SimplePASS - Main GUI Application
[CmdletBinding()]
param(
    [string]$Language = "en"
)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = Get-Location }

Import-Module (Join-Path $scriptDir "CryptoModule.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir "VaultModule.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir "UtilsModule.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir "LoggerModule.psm1") -DisableNameChecking -Force

# --- Localization Resource Dictionaries ---
$res = if ($Language -eq "ja") {
    [PSCustomObject]@{
        # Window & General
        Title = "SimplePASS - パスワード管理ツール"
        Width = 900
        FontFamily = "Meiryo, Segoe UI"
        AppStartLog = "SimplePASS 日本語版 Application Started."
        FatalLogMsg = "Unhandled AppDomain Exception (JP)"

        # Login Panel
        LoginSubtitle = "マスターパスワードを入力して保管庫を解除してください"
        FirstRunSubtitle = "初回起動を検知しました。マスターパスワードを設定してください。"
        LoginButtonUnlock = "保管庫の解除"
        LoginButtonCreate = "保管庫の新規作成"
        LoginPasswordLabel = "マスターパスワード:"
        EmptyPassError = "マスターパスワードを入力してください。"
        LoginFailError = "マスターパスワードが正しくないか、データ破損、または旧v1.0形式です。"
        CreateFailError = "保管庫の作成に失敗しました: "
        FirstRunSuccessStatus = "マスターパスワードが登録され、保管庫が初期化されました。"
        UnlockSuccessStatus = "認証成功: {0} 件のエントリを読み込みました。"
        LoginFailLog = "JP Login / Vault creation failed"

        # Main Grid Actions / Search
        SearchTooltip = "タイトル、URL、ユーザー名、メモをリアルタイム検索..."
        BtnAddEntry = "+ 新規エントリ追加"
        BtnExportCsv = "📥 CSV出力"
        BtnChangePass = "🔑 パスワード変更"
        BtnLock = "保管庫をロック"
        ReadyStatus = "準備完了"
        LockStatus = "保管庫をロックしました。"
        AutoLockStatus = "5分間無操作のため自動ロックされました。"

        # DataGrid Columns
        ColTop = "最上部"
        ColTitle = "タイトル"
        ColUser = "ユーザー名 / ID"
        ColUrl = "URL"
        ColNote = "メモ"
        ColActions = "操作"

        # Actions inside DataGrid
        ToolTipMoveTop = "最上部へ固定"
        BtnCopyPass = "PASSコピー"
        BtnCopyUser = "IDコピー"
        BtnEdit = "編集"
        BtnDelete = "削除"
        MsgCopiedPass = "パスワードをクリップボードにコピーしました (30秒後に自動クリアされます)。"
        MsgCopiedPassLog = "Password copied to clipboard (JP)"
        MsgCopiedUser = "ユーザーIDをクリップボードにコピーしました。"
        MsgCopiedUserLog = "Username copied to clipboard (JP)"
        ConfirmDeleteTitle = "削除確認"
        ConfirmDeleteMsg = "'{0}' を削除してもよろしいですか？"
        StatusDeleted = "エントリを削除しました。"
        StatusMovedTop = "エントリを最上部に移動しました。"

        # Add / Edit Modal
        ModalTitleAdd = "新規パスワード登録"
        ModalTitleEdit = "エントリの編集"
        LabelFormTitle = "タイトル / サービス名:"
        LabelFormUrl = "URL:"
        LabelFormUsername = "ユーザー名 / ID:"
        LabelFormPassword = "パスワード:"
        BtnGeneratePass = "⚡ ランダム生成"
        LabelFormNote = "メモ:"
        BtnSave = "保存"
        BtnCancel = "キャンセル"
        ValidationErrorTitle = "入力エラー"
        ValidationErrorMsg = "タイトルを入力してください。"
        StatusSaved = "エントリを保存しました。 (合計: {0} 件)"

        # Change Master Password Modal
        ModalTitleChangePass = "マスターパスワードの変更"
        LabelCurrentPass = "現在のマスターパスワード:"
        LabelNewPass = "新しいマスターパスワード:"
        LabelConfirmNewPass = "新しいマスターパスワード (確認):"
        BtnChangeExec = "変更実行"
        ErrorCurrentPassIncorrect = "現在のマスターパスワードが正しくありません。"
        ErrorNewPassEmpty = "新しいマスターパスワードを入力してください。"
        ErrorConfirmMismatch = "新しいマスターパスワード（確認）が一致しません。"
        StatusPassChanged = "マスターパスワードを変更しました。"
        LogPassChanged = "Master Password changed (JP)."
        ErrorPassChangeFailed = "マスターパスワードの変更に失敗しました: "

        # CSV Export Dialog
        CsvNoEntriesMsg = "出力できるエントリがありません。"
        CsvNoEntriesTitle = "CSV出力"
        CsvWarningTitle = "セキュリティ確認"
        CsvWarningMsg = "【セキュリティ上の注意】`nエクスポートされるCSVファイルには暗号化されていない平文のパスワードが含まれます。ファイルの使用後は確実に削除するか、安全な場所へ保管してください。`n`nエクスポートを実行しますか？"
        CsvSaveFilter = "CSVファイル (*.csv)|*.csv|すべてのファイル (*.*)|*.*"
        CsvSaveTitle = "保管庫エントリをCSVファイルに出力"
        StatusCsvSuccess = "{0} 件のエントリをCSVファイルに出力しました。"
        LogCsvSuccess = "Vault entries exported to CSV (JP): "
        MsgCsvSuccess = "CSV出力が正常に完了しました。"
        MsgCsvSuccessTitle = "CSV出力完了"
        LogCsvFailed = "JP CSV Export failed"
        MsgCsvFailed = "CSV出力に失敗しました: "
        MsgCsvFailedTitle = "出力エラー"

        # URL Security
        UrlBlockMsg = "セキュリティ上の理由により、このURLの起動はブロックされました。http:// および https:// のURLのみ許可されています。"
        UrlBlockTitle = "セキュリティ警告"
        LogUrlBlocked = "Blocked launching unsafe URL (JP): "
        StatusUrlOpened = "ブラウザでURLを開きました: {0}"
        LogUrlOpened = "Opened URL in default browser (JP): {0}"
        LogUrlOpenFailed = "Failed to open URL in browser (JP)"
        StatusUrlOpenFailed = "URLの起動に失敗しました: {0}"
    }
} else {
    [PSCustomObject]@{
        # Window & General
        Title = "SimplePASS - Password Manager"
        Width = 880
        FontFamily = "Segoe UI"
        AppStartLog = "SimplePASS Application Started."
        FatalLogMsg = "Unhandled AppDomain Exception"

        # Login Panel
        LoginSubtitle = "Enter your Master Password to unlock"
        FirstRunSubtitle = "First run detected. Create your Master Password."
        LoginButtonUnlock = "Unlock Vault"
        LoginButtonCreate = "Create Vault"
        LoginPasswordLabel = "Master Password:"
        EmptyPassError = "Please enter a Master Password."
        LoginFailError = "Invalid Master Password, corrupt data, or legacy v1.0 vault format."
        CreateFailError = "Failed to create Vault: "
        FirstRunSuccessStatus = "Master Password created successfully. Vault initialized."
        UnlockSuccessStatus = "Authenticated successfully. Loaded {0} entries."
        LoginFailLog = "Login / Vault creation failed"

        # Main Grid Actions / Search
        SearchTooltip = "Search title, URL, username..."
        BtnAddEntry = "+ Add Entry"
        BtnExportCsv = "📥 Export CSV"
        BtnChangePass = "🔑 Change Master Pass"
        BtnLock = "Lock Vault"
        ReadyStatus = "Ready"
        LockStatus = "Vault locked."
        AutoLockStatus = "Auto-locked due to 5 minutes of inactivity."

        # DataGrid Columns
        ColTop = "Top"
        ColTitle = "Title"
        ColUser = "Username"
        ColUrl = "URL"
        ColNote = "Note"
        ColActions = "Actions"

        # Actions inside DataGrid
        ToolTipMoveTop = "Move to Top"
        BtnCopyPass = "Copy Pass"
        BtnCopyUser = "Copy User"
        BtnEdit = "Edit"
        BtnDelete = "Delete"
        MsgCopiedPass = "Password copied to clipboard (Auto-clears in 30s)."
        MsgCopiedPassLog = "Password copied to clipboard."
        MsgCopiedUser = "Username copied to clipboard."
        MsgCopiedUserLog = "Username copied to clipboard."
        ConfirmDeleteTitle = "Confirm Delete"
        ConfirmDeleteMsg = "Are you sure you want to delete '{0}'?"
        StatusDeleted = "Entry deleted."
        StatusMovedTop = "Entry moved to top."

        # Add / Edit Modal
        ModalTitleAdd = "New Password Entry"
        ModalTitleEdit = "Edit Entry"
        LabelFormTitle = "Title / Service Name:"
        LabelFormUrl = "URL:"
        LabelFormUsername = "Username / ID:"
        LabelFormPassword = "Password:"
        BtnGeneratePass = "Generate"
        LabelFormNote = "Note:"
        BtnSave = "Save"
        BtnCancel = "Cancel"
        ValidationErrorTitle = "Validation Error"
        ValidationErrorMsg = "Please enter a title."
        StatusSaved = "Entry saved. (Total: {0})"

        # Change Master Password Modal
        ModalTitleChangePass = "Change Master Password"
        LabelCurrentPass = "Current Master Password:"
        LabelNewPass = "New Master Password:"
        LabelConfirmNewPass = "Confirm New Master Password:"
        BtnChangeExec = "Change"
        ErrorCurrentPassIncorrect = "Current Master Password is incorrect."
        ErrorNewPassEmpty = "New Master Password cannot be empty."
        ErrorConfirmMismatch = "New Master Password confirmation does not match."
        StatusPassChanged = "Master Password updated successfully."
        LogPassChanged = "Master Password changed."
        ErrorPassChangeFailed = "Failed to update Master Password: "

        # CSV Export Dialog
        CsvNoEntriesMsg = "No entries available to export."
        CsvNoEntriesTitle = "Export CSV"
        CsvWarningTitle = "Security Warning"
        CsvWarningMsg = "Security Warning: Exported CSV files contain unencrypted plaintext passwords. Ensure you store or delete the file securely after use.`n`nDo you wish to proceed?"
        CsvSaveFilter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
        CsvSaveTitle = "Export Vault Entries to CSV"
        StatusCsvSuccess = "Exported {0} entries to CSV successfully."
        LogCsvSuccess = "Vault entries exported to CSV: "
        MsgCsvSuccess = "CSV export completed successfully."
        MsgCsvSuccessTitle = "Export CSV"
        LogCsvFailed = "CSV Export failed"
        MsgCsvFailed = "Failed to export CSV: "
        MsgCsvFailedTitle = "Export Error"

        # URL Security
        UrlBlockMsg = "Opening this URL is blocked for security reasons. Only http:// and https:// URLs are allowed."
        UrlBlockTitle = "Security Warning"
        LogUrlBlocked = "Blocked launching unsafe URL: "
        StatusUrlOpened = "Opened URL in browser: {0}"
        LogUrlOpened = "Opened URL in default browser: {0}"
        LogUrlOpenFailed = "Failed to open URL in browser"
        StatusUrlOpenFailed = "Failed to open URL: {0}"
    }
}

# --- App-wide Exception & Log Management ---
[System.AppDomain]::CurrentDomain.add_UnhandledException([System.UnhandledExceptionEventHandler]{
    param($sender, $e)
    if ($e.ExceptionObject -is [System.Exception]) {
        Write-AppLog -Level FATAL -Message $res.FatalLogMsg -Exception $e.ExceptionObject
    }
})

Write-AppLog -Level INFO -Message $res.AppStartLog

# --- XAML UI Definition ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$($res.Title)" Height="580" Width="$($res.Width)"
        WindowStartupLocation="CenterScreen" Background="#F4F5F7" FontFamily="$($res.FontFamily)">
    <Grid>
        <!-- Login Panel -->
        <Border x:Name="LoginPanel" Background="#FFFFFF" Width="420" Height="330"
                CornerRadius="8" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Border.Effect>
                <DropShadowEffect BlurRadius="20" Color="#CCCCCC" ShadowDepth="4" Opacity="0.5"/>
            </Border.Effect>
            <StackPanel Margin="30">
                <TextBlock Text="SimplePASS" FontSize="26" FontWeight="Bold" Foreground="#2C3E50" HorizontalAlignment="Center" Margin="0,0,0,10"/>
                <TextBlock x:Name="TxtLoginSubtitle" Text="$($res.LoginSubtitle)" FontSize="13" Foreground="#7F8C8D" HorizontalAlignment="Center" Margin="0,0,0,25" TextWrapping="Wrap"/>

                <TextBlock Text="$($res.LoginPasswordLabel)" FontSize="13" FontWeight="SemiBold" Foreground="#34495E" Margin="0,0,0,5"/>
                <PasswordBox x:Name="PbMasterPassword" Height="38" FontSize="16" Padding="5" Margin="0,0,0,20"/>

                <Button x:Name="BtnLogin" Content="$($res.LoginButtonUnlock)" Height="40" Background="#3498DB" Foreground="White"
                        FontSize="15" FontWeight="Bold" Cursor="Hand" BorderThickness="0">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="4"/>
                        </Style>
                    </Button.Resources>
                </Button>
                <TextBlock x:Name="TxtLoginError" Foreground="#E74C3C" FontSize="12" Margin="0,10,0,0" TextWrapping="Wrap" HorizontalAlignment="Center"/>
            </StackPanel>
        </Border>

        <!-- Main Dashboard Grid -->
        <Grid x:Name="MainGrid" Visibility="Collapsed" Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Search & Actions Bar -->
            <Grid Grid.Row="0" Margin="0,0,0,15">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="TxtSearch" Grid.Column="0" Height="35" FontSize="14" Padding="8,5" VerticalContentAlignment="Center"
                         ToolTip="$($res.SearchTooltip)"/>
                <Button x:Name="BtnAddEntry" Grid.Column="1" Content="$($res.BtnAddEntry)" Height="35" Width="135" Margin="10,0,0,0"
                        Background="#2ECC71" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
                <Button x:Name="BtnExportCsv" Grid.Column="2" Content="$($res.BtnExportCsv)" Height="35" Width="110" Margin="10,0,0,0"
                        Background="#34495E" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
                <Button x:Name="BtnChangePass" Grid.Column="3" Content="$($res.BtnChangePass)" Height="35" Width="145" Margin="10,0,0,0"
                        Background="#F39C12" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
                <Button x:Name="BtnLock" Grid.Column="4" Content="$($res.BtnLock)" Height="35" Width="110" Margin="10,0,0,0"
                        Background="#E74C3C" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
            </Grid>

            <!-- DataGrid -->
            <DataGrid x:Name="DgEntries" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True"
                      CanUserAddRows="False" SelectionMode="Single" Background="White" RowHeaderWidth="0" GridLinesVisibility="Horizontal"
                      CanUserSortColumns="True">
                <DataGrid.Columns>
                    <DataGridTemplateColumn Header="$($res.ColTop)" Width="50">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <Button Content="🔝" Tag="{Binding}" x:Name="BtnMoveTop" Margin="2,0" Padding="4,1" Background="#2980B9" Foreground="White" BorderThickness="0" ToolTip="$($res.ToolTipMoveTop)" FontSize="11" HorizontalAlignment="Center"/>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                    <DataGridTextColumn Header="$($res.ColTitle)" Binding="{Binding title}" Width="140" CanUserSort="True" SortMemberPath="title"/>
                    <DataGridTextColumn Header="$($res.ColUser)" Binding="{Binding username}" Width="140" CanUserSort="True" SortMemberPath="username"/>
                    <DataGridTemplateColumn Header="$($res.ColUrl)" Width="170" CanUserSort="True" SortMemberPath="url">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock Margin="4,2">
                                    <Hyperlink x:Name="HlUrl" NavigateUri="{Binding url}" Tag="{Binding url}">
                                        <TextBlock Text="{Binding url}"/>
                                    </Hyperlink>
                                </TextBlock>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                    <DataGridTextColumn Header="$($res.ColNote)" Binding="{Binding note}" Width="120"/>
                    <DataGridTemplateColumn Header="$($res.ColActions)" Width="*">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                                    <Button Content="$($res.BtnCopyPass)" Tag="{Binding}" x:Name="BtnCopyPass" Margin="2,2" Padding="6,2" Background="#3498DB" Foreground="White" BorderThickness="0"/>
                                    <Button Content="$($res.BtnCopyUser)" Tag="{Binding}" x:Name="BtnCopyUser" Margin="2,2" Padding="6,2" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                                    <Button Content="$($res.BtnEdit)" Tag="{Binding}" x:Name="BtnEditEntry" Margin="2,2" Padding="6,2" Background="#F39C12" Foreground="White" BorderThickness="0"/>
                                    <Button Content="$($res.BtnDelete)" Tag="{Binding}" x:Name="BtnDeleteEntry" Margin="2,2" Padding="6,2" Background="#E74C3C" Foreground="White" BorderThickness="0"/>
                                </StackPanel>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                </DataGrid.Columns>
            </DataGrid>

            <!-- Status Bar -->
            <TextBlock x:Name="TxtStatus" Grid.Row="2" Text="$($res.ReadyStatus)" Foreground="#7F8C8D" Margin="0,10,0,0" FontSize="12"/>
        </Grid>

        <!-- Entry Modal Window -->
        <Border x:Name="EntryModal" Background="#80000000" Visibility="Collapsed">
            <Border Background="White" Width="460" VerticalAlignment="Center" HorizontalAlignment="Center" CornerRadius="8" Padding="25">
                <StackPanel>
                    <TextBlock x:Name="TxtModalTitle" Text="$($res.ModalTitleEdit)" FontSize="18" FontWeight="Bold" Margin="0,0,0,15"/>

                    <TextBlock Text="$($res.LabelFormTitle)" Margin="0,5,0,2"/>
                    <TextBox x:Name="TxtFormTitle" Height="30" Padding="5"/>

                    <TextBlock Text="$($res.LabelFormUrl)" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormUrl" Height="30" Padding="5"/>

                    <TextBlock Text="$($res.LabelFormUsername)" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormUsername" Height="30" Padding="5"/>

                    <Grid Margin="0,8,0,2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="$($res.LabelFormPassword)" Grid.Column="0"/>
                        <Button x:Name="BtnGeneratePass" Content="$($res.BtnGeneratePass)" Grid.Column="1" Background="#9B59B6" Foreground="White" Padding="8,2" BorderThickness="0" Cursor="Hand"/>
                    </Grid>
                    
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <PasswordBox x:Name="PbFormPassword" Grid.Column="0" Height="30" Padding="5" Visibility="Visible"/>
                        <TextBox x:Name="TxtFormPassword" Grid.Column="0" Height="30" Padding="5" Visibility="Collapsed"/>
                        <Button x:Name="BtnTogglePassVisibility" Grid.Column="1" Content="👁" Width="30" Height="30" Margin="5,0,0,0" Background="#BDC3C7" Foreground="White" BorderThickness="0" Cursor="Hand"/>
                    </Grid>

                    <TextBlock Text="$($res.LabelFormNote)" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormNote" Height="50" Padding="5" TextWrapping="Wrap" AcceptsReturn="True"/>

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                        <Button x:Name="BtnSave" Content="$($res.BtnSave)" Width="80" Height="32" Background="#2ECC71" Foreground="White" FontWeight="Bold" Margin="0,0,10,0" BorderThickness="0"/>
                        <Button x:Name="BtnCancelModal" Content="$($res.BtnCancel)" Width="80" Height="32" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </Border>

        <!-- Change Master Password Modal Window -->
        <Border x:Name="ChangePassModal" Background="#80000000" Visibility="Collapsed">
            <Border Background="White" Width="420" VerticalAlignment="Center" HorizontalAlignment="Center" CornerRadius="8" Padding="25">
                <StackPanel>
                    <TextBlock Text="$($res.ModalTitleChangePass)" FontSize="18" FontWeight="Bold" Margin="0,0,0,15"/>

                    <TextBlock Text="$($res.LabelCurrentPass)" Margin="0,5,0,2"/>
                    <PasswordBox x:Name="PbCurrentPass" Height="30" Padding="5"/>

                    <TextBlock Text="$($res.LabelNewPass)" Margin="0,8,0,2"/>
                    <PasswordBox x:Name="PbNewPass" Height="30" Padding="5"/>

                    <TextBlock Text="$($res.LabelConfirmNewPass)" Margin="0,8,0,2"/>
                    <PasswordBox x:Name="PbConfirmNewPass" Height="30" Padding="5"/>

                    <TextBlock x:Name="TxtChangePassError" Foreground="#E74C3C" FontSize="12" Margin="0,10,0,0" TextWrapping="Wrap"/>

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                        <Button x:Name="BtnSaveNewPass" Content="$($res.BtnChangeExec)" Width="80" Height="32" Background="#F39C12" Foreground="White" FontWeight="Bold" Margin="0,0,10,0" BorderThickness="0"/>
                        <Button x:Name="BtnCancelChangePass" Content="$($res.BtnCancel)" Width="80" Height="32" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </Border>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Set Application Window & Taskbar Icon
$iconPath = Join-Path $scriptDir "..\assets\app_icon.ico"
if (-not (Test-Path $iconPath)) {
    $iconPath = Join-Path (Split-Path -Parent $scriptDir) "assets\app_icon.ico"
}
if (Test-Path $iconPath) {
    $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconPath)
}

# Controls
$loginPanel = $window.FindName("LoginPanel")
$pbMasterPassword = $window.FindName("PbMasterPassword")
$btnLogin = $window.FindName("BtnLogin")
$txtLoginError = $window.FindName("TxtLoginError")
$txtLoginSubtitle = $window.FindName("TxtLoginSubtitle")

$mainGrid = $window.FindName("MainGrid")
$txtSearch = $window.FindName("TxtSearch")
$btnAddEntry = $window.FindName("BtnAddEntry")
$btnExportCsv = $window.FindName("BtnExportCsv")
$btnChangePass = $window.FindName("BtnChangePass")
$btnLock = $window.FindName("BtnLock")
$dgEntries = $window.FindName("DgEntries")
$txtStatus = $window.FindName("TxtStatus")

$entryModal = $window.FindName("EntryModal")
$txtModalTitle = $window.FindName("TxtModalTitle")
$txtFormTitle = $window.FindName("TxtFormTitle")
$txtFormUrl = $window.FindName("TxtFormUrl")
$txtFormUsername = $window.FindName("TxtFormUsername")
$pbFormPassword = $window.FindName("PbFormPassword")
$txtFormPassword = $window.FindName("TxtFormPassword")
$btnTogglePassVisibility = $window.FindName("BtnTogglePassVisibility")
$txtFormNote = $window.FindName("TxtFormNote")
$btnGeneratePass = $window.FindName("BtnGeneratePass")
$btnSaveEntry = $window.FindName("BtnSave")
$btnCancelModal = $window.FindName("BtnCancelModal")

$changePassModal = $window.FindName("ChangePassModal")
$pbCurrentPass = $window.FindName("PbCurrentPass")
$pbNewPass = $window.FindName("PbNewPass")
$pbConfirmNewPass = $window.FindName("PbConfirmNewPass")
$txtChangePassError = $window.FindName("TxtChangePassError")
$btnSaveNewPass = $window.FindName("BtnSaveNewPass")
$btnCancelChangePass = $window.FindName("BtnCancelChangePass")

# App State
$script:MasterPassword = ""
$script:VaultEntries = @()
$script:EditingEntryId = $null
$script:LastActivityTime = [DateTime]::Now
$script:AutoLockTimer = $null
$script:IsPasswordVisible = $false

# First-time setup check function
function Update-LoginUIState {
    if (-not (Test-VaultExists)) {
        $txtLoginSubtitle.Text = $res.FirstRunSubtitle
        $btnLogin.Content = $res.LoginButtonCreate
    } else {
        $txtLoginSubtitle.Text = $res.LoginSubtitle
        $btnLogin.Content = $res.LoginButtonUnlock
    }
}

Update-LoginUIState

# --- Auto Lock Timer Setup ---
function Start-AutoLockTimer {
    if ($null -eq $script:AutoLockTimer) {
        $script:AutoLockTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:AutoLockTimer.Interval = [TimeSpan]::FromSeconds(30)
        $script:AutoLockTimer.Add_Tick({
            if ($mainGrid.Visibility -eq [System.Windows.Visibility]::Visible) {
                $idleTime = [DateTime]::Now - $script:LastActivityTime
                if ($idleTime.TotalMinutes -ge 5) {
                    Lock-VaultApp -StatusText $res.AutoLockStatus
                }
            }
        })
    }
    $script:LastActivityTime = [DateTime]::Now
    $script:AutoLockTimer.Start()
}

function Stop-AutoLockTimer {
    if ($script:AutoLockTimer) {
        $script:AutoLockTimer.Stop()
    }
}

$window.Add_PreviewMouseMove({ $script:LastActivityTime = [DateTime]::Now })
$window.Add_PreviewKeyDown({ $script:LastActivityTime = [DateTime]::Now })

function Lock-VaultApp {
    param([string]$StatusText = $null)
    if ([string]::IsNullOrEmpty($StatusText)) { $StatusText = $res.LockStatus }
    Stop-AutoLockTimer
    $script:MasterPassword = $null
    $script:VaultEntries = @()
    [System.GC]::Collect()
    $dgEntries.ItemsSource = $null
    Update-LoginUIState
    $mainGrid.Visibility = [System.Windows.Visibility]::Collapsed
    $entryModal.Visibility = [System.Windows.Visibility]::Collapsed
    $changePassModal.Visibility = [System.Windows.Visibility]::Collapsed
    $loginPanel.Visibility = [System.Windows.Visibility]::Visible
    $txtStatus.Text = $StatusText
}

# --- Event Handlers ---

# PasswordBox Enter key login
$pbMasterPassword.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $btnLogin.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    }
})

# Login / Create Vault Button
$btnLogin.Add_Click({
    $inputPass = $pbMasterPassword.Password
    if ([string]::IsNullOrWhiteSpace($inputPass)) {
        $txtLoginError.Text = $res.EmptyPassError
        return
    }

    try {
        $isFirstRun = -not (Test-VaultExists)
        if ($isFirstRun) {
            $script:VaultEntries = @()
            Save-Vault -Entries $script:VaultEntries -MasterPassword $inputPass
        } else {
            $script:VaultEntries = Load-Vault -MasterPassword $inputPass
        }
        $script:MasterPassword = $inputPass
        $pbMasterPassword.Password = ""
        $txtLoginError.Text = ""

        $loginPanel.Visibility = [System.Windows.Visibility]::Collapsed
        $mainGrid.Visibility = [System.Windows.Visibility]::Visible
        
        $dgEntries.ItemsSource = @($script:VaultEntries)
        if ($isFirstRun) {
            $txtStatus.Text = $res.FirstRunSuccessStatus
        } else {
            $txtStatus.Text = $res.UnlockSuccessStatus -f $script:VaultEntries.Count
        }
        Start-AutoLockTimer
    } catch {
        Write-AppLog -Level ERROR -Message $res.LoginFailLog -Exception $_.Exception
        if (Test-VaultExists) {
            $txtLoginError.Text = $res.LoginFailError
        } else {
            $txtLoginError.Text = "$($res.CreateFailError)$($_.Exception.Message)"
        }
    }
})

# Search text changed
$txtSearch.Add_TextChanged({
    if ($script:VaultEntries) {
        $filtered = Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text
        $dgEntries.ItemsSource = @($filtered)
    }
})

# Lock Button
$btnLock.Add_Click({
    Lock-VaultApp -StatusText $res.LockStatus
})

# Export CSV Button
$btnExportCsv.Add_Click({
    if (-not $script:VaultEntries -or $script:VaultEntries.Count -eq 0) {
        [System.Windows.MessageBox]::Show($res.CsvNoEntriesMsg, $res.CsvNoEntriesTitle, "OK", "Information") | Out-Null
        return
    }

    $confirmRes = [System.Windows.MessageBox]::Show($res.CsvWarningMsg, $res.CsvWarningTitle, "YesNo", "Warning")
    if ($confirmRes -ne "Yes") {
        return
    }

    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = $res.CsvSaveFilter
    $saveFileDialog.FileName = "SimplePASS_Export_$((Get-Date).ToString('yyyyMMdd_HHmmss')).csv"
    $saveFileDialog.Title = $res.CsvSaveTitle

    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            Export-VaultToCsv -Entries $script:VaultEntries -Path $saveFileDialog.FileName
            $txtStatus.Text = $res.StatusCsvSuccess -f $script:VaultEntries.Count
            Write-AppLog -Level INFO -Message "$($res.LogCsvSuccess)$($saveFileDialog.FileName)"
            [System.Windows.MessageBox]::Show($res.MsgCsvSuccess, $res.MsgCsvSuccessTitle, "OK", "Information") | Out-Null
        } catch {
            Write-AppLog -Level ERROR -Message $res.LogCsvFailed -Exception $_.Exception
            [System.Windows.MessageBox]::Show("$($res.MsgCsvFailed)$($_.Exception.Message)", $res.MsgCsvFailedTitle, "OK", "Error") | Out-Null
        }
    }
})

# Change Master Password Button
$btnChangePass.Add_Click({
    $pbCurrentPass.Password = ""
    $pbNewPass.Password = ""
    $pbConfirmNewPass.Password = ""
    $txtChangePassError.Text = ""
    $changePassModal.Visibility = [System.Windows.Visibility]::Visible
})

$btnCancelChangePass.Add_Click({
    $changePassModal.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnSaveNewPass.Add_Click({
    if ($pbCurrentPass.Password -ne $script:MasterPassword) {
        $txtChangePassError.Text = $res.ErrorCurrentPassIncorrect
        return
    }
    if ([string]::IsNullOrWhiteSpace($pbNewPass.Password)) {
        $txtChangePassError.Text = $res.ErrorNewPassEmpty
        return
    }
    if ($pbNewPass.Password -ne $pbConfirmNewPass.Password) {
        $txtChangePassError.Text = $res.ErrorConfirmMismatch
        return
    }

    try {
        $script:MasterPassword = $pbNewPass.Password
        Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
        $changePassModal.Visibility = [System.Windows.Visibility]::Collapsed
        $txtStatus.Text = $res.StatusPassChanged
        Write-AppLog -Level INFO -Message $res.LogPassChanged
    } catch {
        $txtChangePassError.Text = "$($res.ErrorPassChangeFailed)$($_.Exception.Message)"
    }
})

# Add Entry Button
$btnAddEntry.Add_Click({
    $script:EditingEntryId = $null
    $txtModalTitle.Text = $res.ModalTitleAdd
    $txtFormTitle.Text = ""
    $txtFormUrl.Text = ""
    $txtFormUsername.Text = ""
    $pbFormPassword.Password = ""
    $txtFormPassword.Text = ""
    $txtFormNote.Text = ""
    $script:IsPasswordVisible = $false
    $pbFormPassword.Visibility = [System.Windows.Visibility]::Visible
    $txtFormPassword.Visibility = [System.Windows.Visibility]::Collapsed
    $entryModal.Visibility = [System.Windows.Visibility]::Visible
})

# Cancel Modal
$btnCancelModal.Add_Click({
    $entryModal.Visibility = [System.Windows.Visibility]::Collapsed
})

# Password Visibility Toggle
$btnTogglePassVisibility.Add_Click({
    if ($script:IsPasswordVisible) {
        $pbFormPassword.Password = $txtFormPassword.Text
        $txtFormPassword.Visibility = [System.Windows.Visibility]::Collapsed
        $pbFormPassword.Visibility = [System.Windows.Visibility]::Visible
        $script:IsPasswordVisible = $false
    } else {
        $txtFormPassword.Text = $pbFormPassword.Password
        $pbFormPassword.Visibility = [System.Windows.Visibility]::Collapsed
        $txtFormPassword.Visibility = [System.Windows.Visibility]::Visible
        $script:IsPasswordVisible = $true
    }
})

# Generate Password Button
$btnGeneratePass.Add_Click({
    $newPass = New-RandomPassword -Length 16
    $pbFormPassword.Password = $newPass
    $txtFormPassword.Text = $newPass
})

# Save Entry Button
$btnSaveEntry.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtFormTitle.Text)) {
        [System.Windows.MessageBox]::Show($res.ValidationErrorMsg, $res.ValidationErrorTitle, "OK", "Error") | Out-Null
        return
    }

    $passVal = if ($script:IsPasswordVisible) { $txtFormPassword.Text } else { $pbFormPassword.Password }

    if ($script:EditingEntryId) {
        $item = $script:VaultEntries | Where-Object { $_.id -eq $script:EditingEntryId }
        if ($item) {
            $item.title = $txtFormTitle.Text
            $item.url = $txtFormUrl.Text
            $item.username = $txtFormUsername.Text
            $item.password = $passVal
            $item.note = $txtFormNote.Text
            $item.updatedAt = (Get-Date).ToString("o")
        }
    } else {
        $newEntry = New-VaultEntry -Title $txtFormTitle.Text -Url $txtFormUrl.Text -Username $txtFormUsername.Text -Password $passVal -Note $txtFormNote.Text
        $script:VaultEntries = @($script:VaultEntries) + $newEntry
    }

    Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
    $dgEntries.ItemsSource = @(Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text)
    $entryModal.Visibility = [System.Windows.Visibility]::Collapsed
    $txtStatus.Text = $res.StatusSaved -f $script:VaultEntries.Count
})

# DataGrid Row Actions via Event Routing
$window.AddHandler([System.Windows.Documents.Hyperlink]::RequestNavigateEvent, [System.Windows.Navigation.RequestNavigateEventHandler]{
    param($sender, $e)
    try {
        $rawUrl = $e.Uri.OriginalString
        $targetUrl = Format-VaultUrl -Url $rawUrl
        if ([string]::IsNullOrWhiteSpace($targetUrl) -or $targetUrl -notmatch "^https?://" -or $targetUrl -match '[\s"''`]') {
            [System.Windows.MessageBox]::Show($res.UrlBlockMsg, $res.UrlBlockTitle, "OK", "Warning") | Out-Null
            Write-AppLog -Level WARN -Message "$($res.LogUrlBlocked)$rawUrl"
        } else {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $targetUrl
            $psi.UseShellExecute = $true
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            $txtStatus.Text = $res.StatusUrlOpened -f $targetUrl
            Write-AppLog -Level INFO -Message ($res.LogUrlOpened -f $targetUrl)
        }
    } catch {
        Write-AppLog -Level ERROR -Message $res.LogUrlOpenFailed -Exception $_.Exception
        $txtStatus.Text = $res.StatusUrlOpenFailed -f $_.Exception.Message
    }
    $e.Handled = $true
})

$window.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $source = $e.OriginalSource
    if ($null -eq $source -or $source -isnot [System.Windows.Controls.Button]) { return }

    $entry = $source.DataContext

    if ($source.Name -eq "BtnMoveTop" -or $source.Content -eq "🔝") {
        if ($entry -and $entry.id) {
            $script:VaultEntries = @(Move-VaultEntryToTop -Entries $script:VaultEntries -TargetId $entry.id)
            Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
            $dgEntries.ItemsSource = @(Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text)
            $txtStatus.Text = $res.StatusMovedTop
        }
    }
    elseif ($source.Name -eq "BtnCopyPass" -or $source.Content -eq $res.BtnCopyPass) {
        $passToCopy = if ($entry -and $entry.password) { $entry.password } else { $source.Tag }
        if ($passToCopy) {
            [void](Set-ClipboardWithAutoClear -Text $passToCopy -ClearAfterSeconds 30)
            $txtStatus.Text = $res.MsgCopiedPass
            Write-AppLog -Level INFO -Message $res.MsgCopiedPassLog
        }
    }
    elseif ($source.Name -eq "BtnCopyUser" -or $source.Content -eq $res.BtnCopyUser) {
        $userToCopy = if ($entry -and $entry.username) { $entry.username } else { $source.Tag }
        if ($userToCopy) {
            [void](Set-ClipboardWithAutoClear -Text $userToCopy -ClearAfterSeconds 30)
            $txtStatus.Text = $res.MsgCopiedUser
            Write-AppLog -Level INFO -Message $res.MsgCopiedUserLog
        }
    }
    elseif ($source.Name -eq "BtnEditEntry" -or $source.Content -eq $res.BtnEdit) {
        if ($entry) {
            $script:EditingEntryId = $entry.id
            $txtModalTitle.Text = $res.ModalTitleEdit
            $txtFormTitle.Text = $entry.title
            $txtFormUrl.Text = $entry.url
            $txtFormUsername.Text = $entry.username
            $pbFormPassword.Password = $entry.password
            $txtFormPassword.Text = $entry.password
            $txtFormNote.Text = $entry.note
            $script:IsPasswordVisible = $false
            $pbFormPassword.Visibility = [System.Windows.Visibility]::Visible
            $txtFormPassword.Visibility = [System.Windows.Visibility]::Collapsed
            $entryModal.Visibility = [System.Windows.Visibility]::Visible
        }
    }
    elseif ($source.Name -eq "BtnDeleteEntry" -or $source.Content -eq $res.BtnDelete) {
        if ($entry) {
            $resMsg = $res.ConfirmDeleteMsg -f $entry.title
            $resVal = [System.Windows.MessageBox]::Show($resMsg, $res.ConfirmDeleteTitle, "YesNo", "Question")
            if ($resVal -eq "Yes") {
                $targetId = $entry.id
                $script:VaultEntries = @($script:VaultEntries | Where-Object { $_.id -ne $targetId })

                Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
                $dgEntries.ItemsSource = @(Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text)
                $txtStatus.Text = $res.StatusDeleted
            }
        }
    }
})

# Show Dialog
[void]$window.ShowDialog()
