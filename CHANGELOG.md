# Changelog

All notable changes to the **SimplePASS** project will be documented in this file.

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
