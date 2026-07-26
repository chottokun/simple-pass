# SimplePASS - Main GUI Application (Japanese Edition / 日本語版)
[CmdletBinding()]
param()

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

# --- App-wide Exception & Log Management ---
[System.AppDomain]::CurrentDomain.add_UnhandledException([System.UnhandledExceptionEventHandler]{
    param($sender, $e)
    if ($e.ExceptionObject -is [System.Exception]) {
        Write-AppLog -Level FATAL -Message "Unhandled AppDomain Exception (JP)" -Exception $e.ExceptionObject
    }
})

Write-AppLog -Level INFO -Message "SimplePASS 日本語版 Application Started."

# --- XAML UI 定義 ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SimplePASS - パスワード管理ツール" Height="580" Width="900"
        WindowStartupLocation="CenterScreen" Background="#F4F5F7" FontFamily="Meiryo, Segoe UI">
    <Grid>
        <!-- ログイン画面 Panel -->
        <Border x:Name="LoginPanel" Background="#FFFFFF" Width="440" Height="340"
                CornerRadius="8" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Border.Effect>
                <DropShadowEffect BlurRadius="20" Color="#CCCCCC" ShadowDepth="4" Opacity="0.5"/>
            </Border.Effect>
            <StackPanel Margin="30">
                <TextBlock Text="SimplePASS" FontSize="26" FontWeight="Bold" Foreground="#2C3E50" HorizontalAlignment="Center" Margin="0,0,0,10"/>
                <TextBlock x:Name="TxtLoginSubtitle" Text="マスターパスワードを入力して保管庫を解除してください" FontSize="12" Foreground="#7F8C8D" HorizontalAlignment="Center" Margin="0,0,0,25" TextWrapping="Wrap"/>

                <TextBlock Text="マスターパスワード:" FontSize="13" FontWeight="SemiBold" Foreground="#34495E" Margin="0,0,0,5"/>
                <PasswordBox x:Name="PbMasterPassword" Height="38" FontSize="16" Padding="5" Margin="0,0,0,20"/>

                <Button x:Name="BtnLogin" Content="保管庫の解除" Height="40" Background="#3498DB" Foreground="White"
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

        <!-- メイン画面 Dashboard Grid -->
        <Grid x:Name="MainGrid" Visibility="Collapsed" Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- 検索 & ツールバー -->
            <Grid Grid.Row="0" Margin="0,0,0,15">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="TxtSearch" Grid.Column="0" Height="35" FontSize="13" Padding="8,5" VerticalContentAlignment="Center"
                         ToolTip="タイトル、URL、ユーザー名、メモをリアルタイム検索..."/>
                <Button x:Name="BtnAddEntry" Grid.Column="1" Content="+ 新規エントリ追加" Height="35" Width="135" Margin="10,0,0,0"
                        Background="#2ECC71" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
                <Button x:Name="BtnExportCsv" Grid.Column="2" Content="📥 CSV出力" Height="35" Width="110" Margin="10,0,0,0"
                        Background="#34495E" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
                <Button x:Name="BtnChangePass" Grid.Column="3" Content="🔑 パスワード変更" Height="35" Width="135" Margin="10,0,0,0"
                        Background="#F39C12" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
                <Button x:Name="BtnLock" Grid.Column="4" Content="保管庫をロック" Height="35" Width="110" Margin="10,0,0,0"
                        Background="#E74C3C" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
            </Grid>

            <!-- DataGrid 一覧 -->
            <DataGrid x:Name="DgEntries" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True"
                      CanUserAddRows="False" SelectionMode="Single" Background="White" RowHeaderWidth="0" GridLinesVisibility="Horizontal"
                      CanUserSortColumns="True">
                <DataGrid.Columns>
                    <DataGridTemplateColumn Header="最上部" Width="50">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <Button Content="🔝" Tag="{Binding}" x:Name="BtnMoveTop" Margin="2,0" Padding="4,1" Background="#2980B9" Foreground="White" BorderThickness="0" ToolTip="最上部へ固定" FontSize="11" HorizontalAlignment="Center"/>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                    <DataGridTextColumn Header="タイトル" Binding="{Binding title}" Width="140" CanUserSort="True" SortMemberPath="title"/>
                    <DataGridTextColumn Header="ユーザー名 / ID" Binding="{Binding username}" Width="140" CanUserSort="True" SortMemberPath="username"/>
                    <DataGridTemplateColumn Header="URL" Width="170" CanUserSort="True" SortMemberPath="url">
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
                    <DataGridTextColumn Header="メモ" Binding="{Binding note}" Width="120"/>
                    <DataGridTemplateColumn Header="操作" Width="*">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                                    <Button Content="PASSコピー" Tag="{Binding}" x:Name="BtnCopyPass" Margin="2,2" Padding="6,2" Background="#3498DB" Foreground="White" BorderThickness="0"/>
                                    <Button Content="IDコピー" Tag="{Binding}" x:Name="BtnCopyUser" Margin="2,2" Padding="6,2" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                                    <Button Content="編集" Tag="{Binding}" x:Name="BtnEditEntry" Margin="2,2" Padding="6,2" Background="#F39C12" Foreground="White" BorderThickness="0"/>
                                    <Button Content="削除" Tag="{Binding}" x:Name="BtnDeleteEntry" Margin="2,2" Padding="6,2" Background="#E74C3C" Foreground="White" BorderThickness="0"/>
                                </StackPanel>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                </DataGrid.Columns>
            </DataGrid>

            <!-- ステータスバー -->
            <TextBlock x:Name="TxtStatus" Grid.Row="2" Text="準備完了" Foreground="#7F8C8D" Margin="0,10,0,0" FontSize="12"/>
        </Grid>

        <!-- 新規・編集ダイアログ Modal -->
        <Border x:Name="EntryModal" Background="#80000000" Visibility="Collapsed">
            <Border Background="White" Width="460" VerticalAlignment="Center" HorizontalAlignment="Center" CornerRadius="8" Padding="25">
                <StackPanel>
                    <TextBlock x:Name="TxtModalTitle" Text="パスワードエントリの編集" FontSize="18" FontWeight="Bold" Margin="0,0,0,15"/>

                    <TextBlock Text="タイトル / サービス名:" Margin="0,5,0,2"/>
                    <TextBox x:Name="TxtFormTitle" Height="30" Padding="5"/>

                    <TextBlock Text="URL:" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormUrl" Height="30" Padding="5"/>

                    <TextBlock Text="ユーザー名 / ID:" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormUsername" Height="30" Padding="5"/>

                    <Grid Margin="0,8,0,2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="パスワード:" Grid.Column="0"/>
                        <Button x:Name="BtnGeneratePass" Content="⚡ ランダム生成" Grid.Column="1" Background="#9B59B6" Foreground="White" Padding="8,2" BorderThickness="0" Cursor="Hand"/>
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

                    <TextBlock Text="メモ:" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormNote" Height="50" Padding="5" TextWrapping="Wrap" AcceptsReturn="True"/>

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                        <Button x:Name="BtnSaveEntry" Content="保存" Width="80" Height="32" Background="#2ECC71" Foreground="White" FontWeight="Bold" Margin="0,0,10,0" BorderThickness="0"/>
                        <Button x:Name="BtnCancelModal" Content="キャンセル" Width="80" Height="32" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </Border>

        <!-- マスターパスワード変更 Modal -->
        <Border x:Name="ChangePassModal" Background="#80000000" Visibility="Collapsed">
            <Border Background="White" Width="420" VerticalAlignment="Center" HorizontalAlignment="Center" CornerRadius="8" Padding="25">
                <StackPanel>
                    <TextBlock Text="マスターパスワードの変更" FontSize="18" FontWeight="Bold" Margin="0,0,0,15"/>

                    <TextBlock Text="現在のマスターパスワード:" Margin="0,5,0,2"/>
                    <PasswordBox x:Name="PbCurrentPass" Height="30" Padding="5"/>

                    <TextBlock Text="新しいマスターパスワード:" Margin="0,8,0,2"/>
                    <PasswordBox x:Name="PbNewPass" Height="30" Padding="5"/>

                    <TextBlock Text="新しいマスターパスワード (確認):" Margin="0,8,0,2"/>
                    <PasswordBox x:Name="PbConfirmNewPass" Height="30" Padding="5"/>

                    <TextBlock x:Name="TxtChangePassError" Foreground="#E74C3C" FontSize="12" Margin="0,10,0,0" TextWrapping="Wrap"/>

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                        <Button x:Name="BtnSaveNewPass" Content="変更実行" Width="80" Height="32" Background="#F39C12" Foreground="White" FontWeight="Bold" Margin="0,0,10,0" BorderThickness="0"/>
                        <Button x:Name="BtnCancelChangePass" Content="キャンセル" Width="80" Height="32" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </Border>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# アプリ画面 & タスクバーアイコンの設定
$iconPath = Join-Path $scriptDir "..\assets\app_icon.ico"
if (-not (Test-Path $iconPath)) {
    $iconPath = Join-Path (Split-Path -Parent $scriptDir) "assets\app_icon.ico"
}
if (Test-Path $iconPath) {
    $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconPath)
}

# コントロール参照
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
$btnSaveEntry = $window.FindName("BtnSaveEntry")
$btnCancelModal = $window.FindName("BtnCancelModal")

$changePassModal = $window.FindName("ChangePassModal")
$pbCurrentPass = $window.FindName("PbCurrentPass")
$pbNewPass = $window.FindName("PbNewPass")
$pbConfirmNewPass = $window.FindName("PbConfirmNewPass")
$txtChangePassError = $window.FindName("TxtChangePassError")
$btnSaveNewPass = $window.FindName("BtnSaveNewPass")
$btnCancelChangePass = $window.FindName("BtnCancelChangePass")

# アプリ状態変数
$script:MasterPassword = ""
$script:VaultEntries = @()
$script:EditingEntryId = $null
$script:LastActivityTime = [DateTime]::Now
$script:AutoLockTimer = $null
$script:IsPasswordVisible = $false

# 初回起動チェック
function Update-LoginUIState {
    if (-not (Test-VaultExists)) {
        $txtLoginSubtitle.Text = "初回起動を検知しました。マスターパスワードを設定してください。"
        $btnLogin.Content = "保管庫の新規作成"
    } else {
        $txtLoginSubtitle.Text = "マスターパスワードを入力して保管庫を解除してください。"
        $btnLogin.Content = "保管庫の解除"
    }
}

Update-LoginUIState

# --- 自動ロックタイマー設定 ---
function Start-AutoLockTimer {
    if ($null -eq $script:AutoLockTimer) {
        $script:AutoLockTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:AutoLockTimer.Interval = [TimeSpan]::FromSeconds(30)
        $script:AutoLockTimer.Add_Tick({
            if ($mainGrid.Visibility -eq [System.Windows.Visibility]::Visible) {
                $idleTime = [DateTime]::Now - $script:LastActivityTime
                if ($idleTime.TotalMinutes -ge 5) {
                    Lock-VaultApp -StatusText "5分間無操作のため自動ロックされました。"
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
    param([string]$StatusText = "保管庫をロックしました。")
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

# --- イベントハンドラ実装 ---

# PasswordBox で Enter キー押下時にログイン実行
$pbMasterPassword.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $btnLogin.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    }
})

# ログイン / 作成ボタン
$btnLogin.Add_Click({
    $inputPass = $pbMasterPassword.Password
    if ([string]::IsNullOrWhiteSpace($inputPass)) {
        $txtLoginError.Text = "マスターパスワードを入力してください。"
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
            $txtStatus.Text = "マスターパスワードが登録され、保管庫が初期化されました。"
        } else {
            $txtStatus.Text = "認証成功: $($script:VaultEntries.Count) 件のエントリを読み込みました。"
        }
        Start-AutoLockTimer
    } catch {
        Write-AppLog -Level ERROR -Message "JP Login / Vault creation failed" -Exception $_.Exception
        if (Test-VaultExists) {
            $txtLoginError.Text = "マスターパスワードが正しくないか、データ破損、または旧v1.0形式です。"
        } else {
            $txtLoginError.Text = "保管庫の作成に失敗しました: $($_.Exception.Message)"
        }
    }
})

# 検索入力イベント
$txtSearch.Add_TextChanged({
    if ($script:VaultEntries) {
        $filtered = Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text
        $dgEntries.ItemsSource = @($filtered)
    }
})

# ロックボタン
$btnLock.Add_Click({
    Lock-VaultApp -StatusText "保管庫をロックしました。"
})

# CSV出力ボタン
$btnExportCsv.Add_Click({
    if (-not $script:VaultEntries -or $script:VaultEntries.Count -eq 0) {
        [System.Windows.MessageBox]::Show("出力できるエントリがありません。", "CSV出力", "OK", "Information") | Out-Null
        return
    }

    $confirmRes = [System.Windows.MessageBox]::Show("【セキュリティ上の注意】`nエクスポートされるCSVファイルには暗号化されていない平文のパスワードが含まれます。ファイルの使用後は確実に削除するか、安全な場所へ保管してください。`n`nエクスポートを実行しますか？", "セキュリティ確認", "YesNo", "Warning")
    if ($confirmRes -ne "Yes") {
        return
    }

    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSVファイル (*.csv)|*.csv|すべてのファイル (*.*)|*.*"
    $saveFileDialog.FileName = "SimplePASS_Export_$((Get-Date).ToString('yyyyMMdd_HHmmss')).csv"
    $saveFileDialog.Title = "保管庫エントリをCSVファイルに出力"

    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        try {
            Export-VaultToCsv -Entries $script:VaultEntries -Path $saveFileDialog.FileName
            $txtStatus.Text = "$($script:VaultEntries.Count) 件のエントリをCSVファイルに出力しました。"
            Write-AppLog -Level INFO -Message "Vault entries exported to CSV (JP): $($saveFileDialog.FileName)"
            [System.Windows.MessageBox]::Show("CSV出力が正常に完了しました。", "CSV出力完了", "OK", "Information") | Out-Null
        } catch {
            Write-AppLog -Level ERROR -Message "JP CSV Export failed" -Exception $_.Exception
            [System.Windows.MessageBox]::Show("CSV出力に失敗しました: $($_.Exception.Message)", "出力エラー", "OK", "Error") | Out-Null
        }
    }
})

# パスワード変更ボタン
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
        $txtChangePassError.Text = "現在のマスターパスワードが正しくありません。"
        return
    }
    if ([string]::IsNullOrWhiteSpace($pbNewPass.Password)) {
        $txtChangePassError.Text = "新しいマスターパスワードを入力してください。"
        return
    }
    if ($pbNewPass.Password -ne $pbConfirmNewPass.Password) {
        $txtChangePassError.Text = "新しいマスターパスワード（確認）が一致しません。"
        return
    }

    try {
        $script:MasterPassword = $pbNewPass.Password
        Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
        $changePassModal.Visibility = [System.Windows.Visibility]::Collapsed
        $txtStatus.Text = "マスターパスワードを変更しました。"
        Write-AppLog -Level INFO -Message "Master Password changed (JP)."
    } catch {
        $txtChangePassError.Text = "マスターパスワードの変更に失敗しました: $($_.Exception.Message)"
    }
})

# 新規追加ボタン
$btnAddEntry.Add_Click({
    $script:EditingEntryId = $null
    $txtModalTitle.Text = "新規パスワード登録"
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

# モーダルキャンセル
$btnCancelModal.Add_Click({
    $entryModal.Visibility = [System.Windows.Visibility]::Collapsed
})

# パスワード表示切替
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

# パスワードランダム生成
$btnGeneratePass.Add_Click({
    $newPass = New-RandomPassword -Length 16
    $pbFormPassword.Password = $newPass
    $txtFormPassword.Text = $newPass
})

# 保存ボタン
$btnSaveEntry.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtFormTitle.Text)) {
        [System.Windows.MessageBox]::Show("タイトルを入力してください。", "入力エラー", "OK", "Error") | Out-Null
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
    $txtStatus.Text = "エントリを保存しました。 (合計: $($script:VaultEntries.Count) 件)"
})

# DataGrid 行内ボタン操作
$window.AddHandler([System.Windows.Documents.Hyperlink]::RequestNavigateEvent, [System.Windows.Navigation.RequestNavigateEventHandler]{
    param($sender, $e)
    try {
        $rawUrl = $e.Uri.OriginalString
        $targetUrl = Format-VaultUrl -Url $rawUrl
        if ([string]::IsNullOrWhiteSpace($targetUrl) -or $targetUrl -notmatch "^https?://" -or $targetUrl -match '[\s''"`]') {
            [System.Windows.MessageBox]::Show("セキュリティ上の理由により、このURLの起動はブロックされました。http:// および https:// のURLのみ許可されています。", "セキュリティ警告", "OK", "Warning") | Out-Null
            Write-AppLog -Level WARN -Message "Blocked launching unsafe URL (JP): $rawUrl"
        } else {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $targetUrl
            $psi.UseShellExecute = $true
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            $txtStatus.Text = "ブラウザでURLを開きました: $targetUrl"
            Write-AppLog -Level INFO -Message "Opened URL in default browser (JP): $targetUrl"
        }
    } catch {
        Write-AppLog -Level ERROR -Message "Failed to open URL in browser (JP)" -Exception $_.Exception
        $txtStatus.Text = "URLの起動に失敗しました: $($_.Exception.Message)"
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
            $txtStatus.Text = "エントリを最上部に移動しました。"
        }
    }
    elseif ($source.Name -eq "BtnCopyPass" -or $source.Content -eq "PASSコピー") {
        $passToCopy = if ($entry -and $entry.password) { $entry.password } else { $source.Tag }
        if ($passToCopy) {
            [void](Set-ClipboardWithAutoClear -Text $passToCopy -ClearAfterSeconds 30)
            $txtStatus.Text = "パスワードをクリップボードにコピーしました (30秒後に自動クリアされます)。"
            Write-AppLog -Level INFO -Message "Password copied to clipboard (JP)"
        }
    }
    elseif ($source.Name -eq "BtnCopyUser" -or $source.Content -eq "IDコピー") {
        $userToCopy = if ($entry -and $entry.username) { $entry.username } else { $source.Tag }
        if ($userToCopy) {
            [void](Set-ClipboardWithAutoClear -Text $userToCopy -ClearAfterSeconds 30)
            $txtStatus.Text = "ユーザーIDをクリップボードにコピーしました。"
            Write-AppLog -Level INFO -Message "Username copied to clipboard (JP)"
        }
    }
    elseif ($source.Name -eq "BtnEditEntry" -or $source.Content -eq "編集") {
        if ($entry) {
            $script:EditingEntryId = $entry.id
            $txtModalTitle.Text = "エントリの編集"
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
    elseif ($source.Name -eq "BtnDeleteEntry" -or $source.Content -eq "削除") {
        if ($entry) {
            $res = [System.Windows.MessageBox]::Show("'$($entry.title)' を削除してもよろしいですか？", "削除確認", "YesNo", "Question")
            if ($res -eq "Yes") {
                $targetId = $entry.id
                $script:VaultEntries = @($script:VaultEntries | Where-Object { $_.id -ne $targetId })

                Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
                $dgEntries.ItemsSource = @(Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text)
                $txtStatus.Text = "エントリを削除しました。"
            }
        }
    }
})

# ウィンドウ表示
[void]$window.ShowDialog()
