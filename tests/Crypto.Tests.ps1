# Crypto.Tests.ps1 - Best-practice Security & Integrity Test Suite

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-CryptoTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"
    Import-Module (Join-Path $srcDir "CryptoModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: Portable Mode Round-trip encryption and decryption (No DPAPI dependency for OneDrive)
    try {
        $plainJson = '{"testKey":"SecretPassword123!","url":"https://example.com"}'
        $masterPass = "MySuperSecretMasterKey2026!"
        
        $vaultData = ConvertTo-EncryptedVaultData -JsonText $plainJson -MasterPassword $masterPass -UseDpapi:$false
        Assert-True ($null -ne $vaultData.salt) "Salt generated"
        Assert-True ($null -ne $vaultData.hmac) "HMAC signature generated"
        Assert-True ($vaultData.version -eq "2.0") "Vault version is 2.0 (Portable)"
        
        $decrypted = ConvertFrom-EncryptedVaultData -VaultHashtable $vaultData -MasterPassword $masterPass
        Assert-True ($decrypted -eq $plainJson) "Decrypted string matches original plaintext in Portable mode"
        
        $results.Passed++
        $results.Log += "[PASS] Test 1: Portable Mode Round-trip Encryption & Decryption (HMAC+AES-256)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: Portable Mode Encryption & Decryption - $_"
    }

    # Test 2: Strictly fails decryption with incorrect master password
    try {
        $plainJson = '{"password":"ConfidentialData"}'
        $correctPass = "CorrectPassword123"
        $wrongPass   = "WrongPassword456"

        $vaultData = ConvertTo-EncryptedVaultData -JsonText $plainJson -MasterPassword $correctPass

        $failedAsExpected = $false
        try {
            $dummy = ConvertFrom-EncryptedVaultData -VaultHashtable $vaultData -MasterPassword $wrongPass
        } catch {
            $failedAsExpected = $true
        }

        Assert-True $failedAsExpected "Decryption failed as expected when using wrong master password"
        $results.Passed++
        $results.Log += "[PASS] Test 2: Decryption strictly fails with wrong master password"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Wrong master password decryption test - $_"
    }

    # Test 3: Zero plaintext leakage in saved vault output
    try {
        $secretWord = "SuperUniqueSecretWord999"
        $plainJson = '{"title":"Google","password":"' + $secretWord + '"}'
        $masterPass = "Pass123"

        $vaultData = ConvertTo-EncryptedVaultData -JsonText $plainJson -MasterPassword $masterPass
        $jsonOutput = $vaultData | ConvertTo-Json

        Assert-True (-not $jsonOutput.Contains($secretWord)) "Encrypted JSON output does NOT contain any plaintext secret words"
        $results.Passed++
        $results.Log += "[PASS] Test 3: Zero plaintext leak in encrypted format"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Plaintext leak test - $_"
    }

    # Test 4: HMAC Integrity & Tamper Detection
    try {
        $plainJson = '{"data":"test"}'
        $masterPass = "Pass123"
        $vaultData = ConvertTo-EncryptedVaultData -JsonText $plainJson -MasterPassword $masterPass

        # Tamper 1 byte of cipher data
        $rawBytes = [Convert]::FromBase64String($vaultData.data)
        $rawBytes[0] = $rawBytes[0] -bxor 0xFF
        $vaultData.data = [Convert]::ToBase64String($rawBytes)

        $tamperDetected = $false
        try {
            $dummy = ConvertFrom-EncryptedVaultData -VaultHashtable $vaultData -MasterPassword $masterPass
        } catch {
            $tamperDetected = $true
        }

        Assert-True $tamperDetected "HMAC integrity verification correctly detected tampered ciphertext"
        $results.Passed++
        $results.Log += "[PASS] Test 4: HMAC Integrity & Tamper Detection"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: HMAC Tamper detection - $_"
    }

    # Test 5: Rejection of legacy / missing HMAC data (v2.0 strict mode)
    try {
        $legacyVault = @{
            version = "1.0"
            salt    = "L+6A/j8H+HHGR9E5fl4J2A=="
            data    = "AQAAANCMnd8BFdERjHoAwE/Cl+sBAAAA..."
            # missing hmac
        }

        $rejected = $false
        try {
            $dummy = ConvertFrom-EncryptedVaultData -VaultHashtable $legacyVault -MasterPassword "Pass123"
        } catch {
            $rejected = $true
        }

        Assert-True $rejected "Vault data lacking HMAC integrity field strictly rejected"
        $results.Passed++
        $results.Log += "[PASS] Test 5: Strict rejection of legacy / HMAC-less vault format"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 5: Legacy vault rejection test - $_"
    }

    # Test 6: Handling of corrupt or empty salt/data inputs
    try {
        $corruptVault = @{
            version = "2.0"
            salt    = ""
            data    = ""
            hmac    = "dGVzdA=="
        }

        $corruptRejected = $false
        try {
            $dummy = ConvertFrom-EncryptedVaultData -VaultHashtable $corruptVault -MasterPassword "Pass123"
        } catch {
            $corruptRejected = $true
        }

        Assert-True $corruptRejected "Empty salt or data hashtable strictly rejected"
        $results.Passed++
        $results.Log += "[PASS] Test 6: Empty salt/data corrupt vault rejection"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 6: Corrupt vault rejection test - $_"
    }

    # Test 7: Protect-DataWithDpapi and Unprotect-DataWithDpapi cross-platform validation
    try {
        $testBytes = [System.Text.Encoding]::UTF8.GetBytes("DpapiTestDataSecretString123!")

        if ($IsWindows) {
            # On Windows, DPAPI should work successfully for a round-trip
            $protected = Protect-DataWithDpapi -Data $testBytes
            Assert-True ($null -ne $protected) "DPAPI protect output is not null"
            Assert-True ($protected.Length -gt 0) "DPAPI protect output has elements"

            # Ensure it actually encrypted/changed the data
            $isSame = $true
            if ($protected.Length -eq $testBytes.Length) {
                $isSame = $true
                for ($i = 0; $i -lt $testBytes.Length; $i++) {
                    if ($protected[$i] -ne $testBytes[$i]) {
                        $isSame = $false
                        break
                    }
                }
            } else {
                $isSame = $false
            }
            Assert-True (-not $isSame) "DPAPI protect output differs from original plaintext bytes"

            $unprotected = Unprotect-DataWithDpapi -EncryptedData $protected
            Assert-True ($null -ne $unprotected) "DPAPI unprotect output is not null"

            $decryptedString = [System.Text.Encoding]::UTF8.GetString($unprotected)
            Assert-True ($decryptedString -eq "DpapiTestDataSecretString123!") "DPAPI round-trip decrypted string matches original input"

            $results.Passed++
            $results.Log += "[PASS] Test 7: DPAPI Protect/Unprotect Round-trip successful on Windows"
        } else {
            # On non-Windows platforms, DPAPI Protect and Unprotect should throw PlatformNotSupportedException
            $protectFailedWithPlatformNotSupported = $false
            try {
                $dummy = Protect-DataWithDpapi -Data $testBytes
            } catch {
                if ($_.Exception.GetBaseException() -is [System.PlatformNotSupportedException]) {
                    $protectFailedWithPlatformNotSupported = $true
                } else {
                    throw "Expected PlatformNotSupportedException on non-Windows but got: $_"
                }
            }
            Assert-True $protectFailedWithPlatformNotSupported "DPAPI Protect threw PlatformNotSupportedException on non-Windows platform"

            $unprotectFailedWithPlatformNotSupported = $false
            try {
                $dummy = Unprotect-DataWithDpapi -EncryptedData $testBytes
            } catch {
                if ($_.Exception.GetBaseException() -is [System.PlatformNotSupportedException]) {
                    $unprotectFailedWithPlatformNotSupported = $true
                } else {
                    throw "Expected PlatformNotSupportedException on non-Windows but got: $_"
                }
            }
            Assert-True $unprotectFailedWithPlatformNotSupported "DPAPI Unprotect threw PlatformNotSupportedException on non-Windows platform"

            $results.Passed++
            $results.Log += "[PASS] Test 7: DPAPI correctly throws PlatformNotSupportedException on non-Windows platform"
        }
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: DPAPI cross-platform test - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-CryptoTests
}

