# SimplePASS 🔐

[![SimplePASS CI Workflow](https://github.com/chottokun/simple-pass/actions/workflows/ci.yml/badge.svg)](https://github.com/chottokun/simple-pass/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://microsoft.com/powershell)

Windows環境で動作する、ローカル完結型の PowerShell + WPF パスワード管理 GUI アプリケーション。
外部サーバー通信は行わず、スタンドアロンかつポータブルに動作する。
英語・日本語の動的ローカリゼーションに対応し、単一のコードベースから両言語版を提供する。

---

## 主な機能

- **WPF GUI**: PowerShell 5.1 / WPF (XAML) による GUI。ウィンドウアイコン付き。
- **動的ローカリゼーション (i18n)**: `-Language` パラメータとリソース辞書による英語/日本語切替。`SimplePASS_JP.ps1` は `SimplePASS.ps1 -Language ja` を呼び出す薄いラッパー。
- **暗号化 (v2.0)**: PBKDF2-SHA256 (100,000回) + AES-256-CBC + HMAC-SHA256 改ざん検知。
- **最上部固定 (Top Pinning)**: エントリをリスト最上部へ固定・順序保存。
- **URLワンクリック起動**: プロトコルホワイトリスト (`http://`, `https://`) バリデーション付き。
- **CSV エクスポート**: 確認ダイアログ付きで保管庫データを CSV 出力。
- **マスターパスワード変更**: アプリ内から保管庫の暗号化鍵を更新・再暗号化。
- **パスワード表示切替**: `PasswordBox` / `TextBox` のトグル切替。
- **自動ロック**: 5分間無操作検知による自動ロック（DispatcherTimer ベース）。
- **クリップボード自動消去**: コピー後30秒でクリップボードを自動クリア。

---

## セキュリティ仕様

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

## 動作環境

- **OS**: Windows 10 / Windows 11
- **PowerShell**: PowerShell 5.1 以上 (Windows 標準 PowerShell)
- **.NET Framework**: .NET Framework 4.7.2 以上

---

## 起動方法

リポジトリ直下のバッチファイルをダブルクリック、またはコマンドラインから実行する。

### 日本語版
```cmd
SimplePASS_JP.bat
```

### 英語版
```cmd
SimplePASS.bat
```

---

## ディレクトリ構成

```text
SimplePASS/
├── SimplePASS.bat                        # 起動用バッチファイル (英語版)
├── SimplePASS_JP.bat                     # 起動用バッチファイル (日本語版)
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
│   ├── SimplePASS.ps1                    # 統合 GUI アプリケーション (-Language en|ja で言語切替)
│   ├── SimplePASS_JP.ps1                 # 日本語版ラッパー (SimplePASS.ps1 -Language ja を呼出)
│   ├── CryptoModule.psm1                 # 暗号コアモジュール (PBKDF2-SHA256 + AES-256 + HMAC)
│   ├── VaultModule.psm1                  # 保管庫データ CRUD & 永続化モジュール
│   ├── UtilsModule.psm1                  # クリップボード自動消去 & パスワード生成器
│   └── LoggerModule.psm1                 # エラーログ・例外追跡モジュール
└── tests/
    ├── RunAllTests.ps1                   # 全自動統合テストランナー (全66項目)
    ├── Crypto.Tests.ps1                  # 暗号 (AES/HMAC/PBKDF2/Salt/DPAPI) 23テスト
    ├── Vault.Tests.ps1                   # CRUD・CSV出力・順序操作・URL/不完全プロパティ耐性 15テスト
    ├── Utils.Tests.ps1                   # パスワード生成・クリップボード非同期消去・リトライ・境界値 6テスト
    ├── GUI.Tests.ps1                     # DataGrid バインディング・XAML パース・LoginUIState 4テスト
    ├── GUI_FullButtons.Tests.ps1         # フル UI ボタンインタラクション 1テスト
    ├── GUI_CriticalUserOperations.Tests.ps1 # 再認証・0件検索復帰 2テスト
    ├── GUI_JP.Tests.ps1                  # 日本語リソース XAML 展開・Lock-VaultApp・LoginUIState 3テスト
    ├── GUI_NewFeatures.Tests.ps1         # パスワード変更・表示トグル・Lock-VaultApp・AutoLockTimer 7テスト
    ├── EncodingAndSyntax.Tests.ps1       # AST構文解析・UTF-8 BOM 適合・PSScriptAnalyzer 3テスト
    └── Logger.Tests.ps1                  # ログ記録・例外スタックトレース出力 2テスト
```

---

## テスト (Testing)

全66項目の自動テストスイートを含む。AST 構文解析・全ファイル UTF-8 BOM 適合検証・`PSScriptAnalyzer` 静的コード解析も実行される。
GitHub Actions CI (`windows-latest`) で push / PR 時に自動実行される。

```powershell
powershell -ExecutionPolicy Bypass -File "tests\RunAllTests.ps1"
```

### テスト内訳

| テストファイル | 項目数 | 対象 |
|---|---|---|
| Crypto.Tests.ps1 | 23 | AES-256, HMAC-SHA256, PBKDF2, Salt, DPAPI |
| Vault.Tests.ps1 | 15 | CRUD, CSV出力, 順序操作, URL/不完全プロパティ耐性 |
| Utils.Tests.ps1 | 6 | パスワード生成, クリップボード非同期消去・リトライ, 境界値 |
| GUI.Tests.ps1 | 4 | DataGrid, XAML パース, LoginUIState |
| GUI_FullButtons.Tests.ps1 | 1 | フル UI ボタンワークフロー |
| GUI_CriticalUserOperations.Tests.ps1 | 2 | 再認証, 0件検索復帰 |
| GUI_JP.Tests.ps1 | 3 | 日本語 XAML 展開, Lock-VaultApp, LoginUIState |
| GUI_NewFeatures.Tests.ps1 | 7 | パスワード変更, 表示トグル, AutoLockTimer |
| EncodingAndSyntax.Tests.ps1 | 3 | AST 構文, UTF-8 BOM, PSScriptAnalyzer |
| Logger.Tests.ps1 | 2 | ログ記録, 例外スタックトレース |
| **合計** | **66** | |

---

## アーキテクチャ補足

### 動的ローカリゼーション (i18n)

`SimplePASS.ps1` は `-Language` パラメータ（デフォルト `en`）を受け取り、言語に応じたリソース辞書 `$res` を生成する。XAML テンプレート内の `$($res.PropertyName)` を `ExpandString` で展開し、WPF コントロールに動的にバインドする。

```
SimplePASS.ps1 -Language en   → 英語リソース辞書で XAML を展開
SimplePASS.ps1 -Language ja   → 日本語リソース辞書で XAML を展開
SimplePASS_JP.ps1             → SimplePASS.ps1 -Language ja を呼び出すラッパー
```

新しい言語を追加する場合は、`SimplePASS.ps1` 内のリソース辞書ブロックに言語分岐を追加する。

---

## ライセンス (License)

[MIT License](LICENSE)
