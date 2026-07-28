# Changelog

All notable changes to the **SimplePASS** project will be documented in this file.

## [2.2.0] - 2026-07-28

### Added
- **Vault Data Recovery Guidance**: Added automatic detection of `.bak` backup files on login failure or data corruption with user recovery instructions and prompt.
- **Save-Vault UTF-8 BOM Control**: Enhanced `Save-Vault` using `[System.IO.File]::WriteAllText` and `-NoBOM` switch for cross-platform UTF-8 encoding stability across PowerShell 5.1 and Core 7+.
- **Expanded Test Suite (77 Tests)**: Added TDD unit tests for backup recovery guidance, XAML form field validation, password strength rules, URL scheme security whitelisting, multilingual resource key parity (`en.psd1` vs `ja.psd1`), and background clipboard integration.

### Refactored
- **Clipboard Clear Refactoring**: Extracted private helper function `Start-AsynchronousClipboardClear` in `UtilsModule.psm1` for cleaner code organization.

## [2.1.0] - 2026-07-26


### Performance & Optimization
- **Native .NET Cryptographic Constructors**: Refactored `CryptoModule` to use direct `[Type]::new()` constructors for `byte[]`, `Rfc2898DeriveBytes`, and `HMACSHA256`, eliminating reflection and COM overhead.
- **Asynchronous STA Runspace Clipboard Clearing**: Replaced process-heavy `Start-Job` calls in `UtilsModule` with lightweight background STA Runspaces for clipboard auto-clearing.
- **Fast Dot-Notation Property Access**: Optimized object property resolution in `VaultModule` for `Search-VaultEntries` and `Export-VaultToCsv`.

### Resilience & Testing Enhancements
- **Transient Clipboard Lock Retry**: Implemented a 3-attempt retry loop with 50ms intervals in `Set-ClipboardWithAutoClear` to handle background thread and system clipboard locking seamlessly.
- **Incomplete Object Property Resilience**: Added TDD test coverage (`Vault.Tests.ps1` Test 15) ensuring graceful handling of partial PSCustomObjects and Hashtables with missing properties.
- **Async Runspace Non-blocking Test**: Added TDD test coverage (`Utils.Tests.ps1` Test 6) for background STA runspace execution without UI thread blocking.
- **Expanded Test Suite**: Total automated test suite expanded to 66 tests (100% pass rate).

## [2.0.0] - 2026-07-25

### Added
- **Master Password Change**: Added an in-app feature to change the Master Password and re-encrypt the entire vault.
- **Password Visibility Toggle (👁)**: Added a toggle button in the entry modal to switch between masked (`PasswordBox`) and plain text (`TextBox`) password views.
- **Auto-Lock Mechanism**: Introduced a 5-minute inactivity auto-lock timer to clear state and lock the vault automatically.
- **Comprehensive Test Suite Expansion**: Expanded automated tests to 28 tests covering new UX features, edge cases, corrupt files, and legacy rejection.

### Security & Architecture (v2.0 Breaking Changes)
- **PBKDF2 SHA-256**: Upgraded key derivation to use `SHA-256` explicitly.
- **Strict HMAC Verification**: Mandatory HMAC-SHA256 integrity checks with constant-time comparison to prevent timing attacks.
- **Deprecation of v1.0 Format**: Dropped support for legacy HMAC-less v1.0 vault files for enhanced security.
- **Memory Protection**: Immediate GC collection and nullification of Master Password in memory on vault lock.
