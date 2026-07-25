# SimplePASS 🔐

[![SimplePASS CI Workflow](https://github.com/username/SimplePASS/actions/workflows/ci.yml/badge.svg)](https://github.com/username/SimplePASS/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://microsoft.com/powershell)

Windows環境で動作する、ローカル完結型かつ高セキュリティな PowerShell + WPF パスワード管理 GUI アプリケーションです。
外部サーバー通信を一切行わず、スタンドアロンかつポータブルに安全なデータ保管が可能です。

---

## 🌟 特長 (Key Features)

- 🎨 **グラフィカルな操作画面**: PowerShell 5.1 / WPF (XAML) で構築された直感的でモダンな UI & ウィンドウアイコン。
- 🛡 **ゼロトラスト暗号化 (v2.0)**: PBKDF2-SHA256 (100,000回試行) + AES-256-CBC + HMAC-SHA256 改ざん検知による二重保護。
- 🔝 **最上部固定 (Top Pinning)**: よく使うエントリをワンクリックでリストの最上部へ固定・順序保存。
- 🔗 **URLワンクリック起動**: 登録された Web サイトの URL を安全なプロトコルバリデーションのもとデフォルトブラウザで起動。
- 📥 **CSV エクスポート機能**: セキュリティ確認ダイアログのもと、保管庫データを外部 CSV ファイルへ出力可能。
- 🔑 **マスターパスワード変更機能**: アプリ内からいつでも保管庫の暗号化鍵を安全に更新・再暗号化可能。
- 👁 **パスワード表示切替**: マスク表示 (`PasswordBox`) と平文表示 (`TextBox`) のワンクリック切替。
- ⏱ **自動ロック機能**: 5分間の無操作（マウス・キーボード操作なし）を検知して自動的に保管庫をロック。
- 📋 **クリップボード自動保護**: パスワード・ユーザーIDをコピー後、30秒経過でクリップボードを自動消去。

---

## 🛡 セキュリティ仕様 (Security Architecture)

1. **暗号導出 & 暗号化**:
   - **PBKDF2**: SHA-256 ハッシュアルゴリズム、個別の 32 バイト CSPRNG Salt、100,000 イテレーション。
   - **AES-256-CBC**: PKCS7 パディング適用。
2. **改ざん検知 (Integrity Check)**:
   - **HMAC-SHA256**: 暗号文の完全性を定数時間比較 (`FixedTimeEquals`) で検証し、タイミング攻撃を遮断。
3. **URL プロトコルバリデーション**:
   - `http://` および `https://` 以外の不審なスキーム（`file://`, `javascript:`, コマンド実行等）は自動遮断。
4. **メモリ領域の保護**:
   - 保管庫ロック・終了時に暗号化キーおよびマスターパスワードをメモリから解放し、ガベージコレクションを明示実行。

---

## 💻 動作環境 (Requirements)

- **OS**: Windows 10 / Windows 11
- **PowerShell**: PowerShell 5.1 以上 (Windows 標準 PowerShell)
- **.NET Framework**: .NET Framework 4.7.2 以上

---

## 🚀 起動方法 (Quick Start)

リポジトリ直下のバッチファイルをダブルクリック（またはコマンドラインから実行）するだけで起動できます。

### 🇯🇵 日本語版
```cmd
start_JP.bat
```
*(または `SimplePASS_JP.bat`)*

### 🇺🇸 英語版 (English Edition)
```cmd
start.bat
```
*(または `SimplePASS.bat`)*

---

## 📁 ディレクトリ構成 (Directory Structure)

```text
SimplePASS/
├── start.bat                             # 起動用バッチファイル (英語版)
├── start_JP.bat                          # 起動用バッチファイル (日本語版)
├── SimplePASS.bat                        # エリアス用バッチファイル
├── SimplePASS_JP.bat                     # エリアス用バッチファイル
├── README.md                             # 本ドキュメント
├── LICENSE                               # ライセンスファイル (MIT License)
├── SECURITY.md                           # セキュリティポリシー
├── CHANGELOG.md                          # 変更履歴
├── AGENTS.md                             # コーディングルール定義
├── assets/                               # アプリケーションアイコン素材
│   ├── app_icon.ico                      # アプリウィンドウ & タスクバー用アイコン
│   └── app_icon.png                      # 高解像度 PNG アイコン
├── data/                                 # 保管庫データ格納フォルダー (要保護)
│   ├── .gitkeep                          # ディレクトリ構造保持用
│   ├── vault.json                        # 暗号化済み保管庫ファイル (v2.0 / .gitignore対象)
│   └── logs/
│       └── app.log                       # 統合エラーログ (1MB自動ローテーション)
├── src/
│   ├── SimplePASS.ps1                    # メイン GUI アプリケーション (英語版)
│   ├── SimplePASS_JP.ps1                 # メイン GUI アプリケーション (日本語版)
│   ├── CryptoModule.psm1                 # 暗号コアモジュール (PBKDF2-SHA256 + AES-256 + HMAC)
│   ├── VaultModule.psm1                  # 保管庫データ CRUD & 永続化モジュール
│   ├── UtilsModule.psm1                  # クリップボード自動消去 & パスワード生成器
│   └── LoggerModule.psm1                 # エラーログ・例外追跡モジュール
└── tests/
    ├── RunAllTests.ps1                   # 全自動統合テストランナー (全38項目)
    ├── Crypto.Tests.ps1                  # 暗号強度・定数時間HMAC・ネガティブテスト
    ├── Vault.Tests.ps1                   # CRUD・CSV出力・順序操作・URLセキュリティテスト
    ├── Utils.Tests.ps1                   # パスワード生成境界値・クリップボード動作テスト
    ├── GUI.Tests.ps1                     # DataGrid ItemsSource バインディングテスト
    ├── GUI_FullButtons.Tests.ps1         # フル UI ボタンインタラクションテスト
    ├── GUI_CriticalUserOperations.Tests.ps1 # 再認証・0件検索復帰テスト
    ├── GUI_JP.Tests.ps1                 # 日本語版 XAML 解析・コントロール結合テスト
    ├── GUI_NewFeatures.Tests.ps1         # 新機能（Top固定・表示トグル・自動ロック）テスト
    ├── EncodingAndSyntax.Tests.ps1       # 全ファイル UTF-8 BOM & PSScriptAnalyzer リンターテスト
    └── Logger.Tests.ps1                  # ログ記録・例外スタックトレース出力テスト
```

---

## 🧪 テストの実行方法 (Testing)

全38項目の全自動統合テストスイート（AST構文解析・全ファイル UTF-8 BOM 適合検証・`PSScriptAnalyzer` 静的コード解析を含む）が含まれています。

```powershell
powershell -ExecutionPolicy Bypass -File "tests\RunAllTests.ps1"
```

---

## 📜 ライセンス (License)

本プロジェクトは [MIT License](LICENSE) のもとで公開されています。
