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

    # Test 7: DPAPI Protection and Unprotection (Platform-conditional Behavior)
    try {
        $isWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
        if ($isWindowsPlatform) {
            $originalBytes = [byte[]](65, 66, 67, 68) # "ABCD"
            $protectedBytes = Protect-DataWithDpapi -Data $originalBytes
            Assert-True ($null -ne $protectedBytes) "DPAPI protected data is not null"
            Assert-True ($protectedBytes.Length -gt 0) "DPAPI protected data has length > 0"

            # Ensure protected data is actually encrypted/different
            $isSame = $true
            if ($protectedBytes.Length -eq $originalBytes.Length) {
                $isSame = $true
                for ($i = 0; $i -lt $originalBytes.Length; $i++) {
                    if ($protectedBytes[$i] -ne $originalBytes[$i]) {
                        $isSame = $false
                        break
                    }
                }
            } else {
                $isSame = $false
            }
            Assert-True (-not $isSame) "DPAPI protected bytes are different from original bytes"

            $unprotectedBytes = Unprotect-DataWithDpapi -EncryptedData $protectedBytes
            Assert-True ($null -ne $unprotectedBytes) "DPAPI unprotected data is not null"
            Assert-True ($unprotectedBytes.Length -eq $originalBytes.Length) "DPAPI unprotected length matches original"
            for ($i = 0; $i -lt $originalBytes.Length; $i++) {
                Assert-True ($unprotectedBytes[$i] -eq $originalBytes[$i]) "Byte at index $i matches original"
            }
        } else {
            # On non-Windows, calling DPAPI should throw PlatformNotSupportedException or MethodInvocationException wrapping it
            $thrownProtect = $false
            try {
                $dummy = Protect-DataWithDpapi -Data ([byte[]]@(1, 2, 3))
            } catch {
                $thrownProtect = $true
                Assert-True ($_.Exception.Message -like "*platform*" -or $_.Exception.InnerException.Message -like "*platform*") "Expected platform-not-supported error message"
            }
            Assert-True $thrownProtect "Protect-DataWithDpapi throws platform-not-supported exception on non-Windows"

            $thrownUnprotect = $false
            try {
                $dummy = Unprotect-DataWithDpapi -EncryptedData ([byte[]]@(1, 2, 3))
            } catch {
                $thrownUnprotect = $true
                Assert-True ($_.Exception.Message -like "*platform*" -or $_.Exception.InnerException.Message -like "*platform*") "Expected platform-not-supported error message"
            }
            Assert-True $thrownUnprotect "Unprotect-DataWithDpapi throws platform-not-supported exception on non-Windows"
        }

        $results.Passed++
        $results.Log += "[PASS] Test 7: DPAPI Protection and Unprotection (Platform-conditional Behavior)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: DPAPI Protection and Unprotection - $_"
    }

    # Test 8: DPAPI Edge Cases (Platform-conditional Behavior)
    try {
        $isWindowsPlatform = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
        if ($isWindowsPlatform) {
            # 1. Null argument checks should throw ArgumentNullException or similar
            $thrownNullProtect = $false
            try {
                $dummy = Protect-DataWithDpapi -Data $null
            } catch {
                $thrownNullProtect = $true
            }
            Assert-True $thrownNullProtect "Protect-DataWithDpapi with null input throws exception"

            $thrownNullUnprotect = $false
            try {
                $dummy = Unprotect-DataWithDpapi -EncryptedData $null
            } catch {
                $thrownNullUnprotect = $true
            }
            Assert-True $thrownNullUnprotect "Unprotect-DataWithDpapi with null input throws exception"

            # 2. Invalid/tampered bytes decryption should throw CryptographicException
            $invalidBytes = [byte[]](9, 9, 9, 9, 9, 9, 9, 9)
            $thrownInvalidUnprotect = $false
            try {
                $dummy = Unprotect-DataWithDpapi -EncryptedData $invalidBytes
            } catch {
                $thrownInvalidUnprotect = $true
                Assert-True ($_.Exception.GetType().FullName -like "*Cryptographic*" -or $_.Exception.InnerException.GetType().FullName -like "*Cryptographic*") "Expected CryptographicException"
            }
            Assert-True $thrownInvalidUnprotect "Unprotect-DataWithDpapi with invalid/tampered bytes throws CryptographicException"
        } else {
            # On non-Windows, calling DPAPI even with null should throw PlatformNotSupportedException
            $thrownNullProtect = $false
            try {
                $dummy = Protect-DataWithDpapi -Data $null
            } catch {
                $thrownNullProtect = $true
                Assert-True ($_.Exception.Message -like "*platform*" -or $_.Exception.InnerException.Message -like "*platform*") "Expected platform-not-supported error message"
            }
            Assert-True $thrownNullProtect "Protect-DataWithDpapi with null throws platform-not-supported exception on non-Windows"

            $thrownNullUnprotect = $false
            try {
                $dummy = Unprotect-DataWithDpapi -EncryptedData $null
            } catch {
                $thrownNullUnprotect = $true
                Assert-True ($_.Exception.Message -like "*platform*" -or $_.Exception.InnerException.Message -like "*platform*") "Expected platform-not-supported error message"
            }
            Assert-True $thrownNullUnprotect "Unprotect-DataWithDpapi with null throws platform-not-supported exception on non-Windows"
        }

        $results.Passed++
        $results.Log += "[PASS] Test 8: DPAPI Edge Cases (Platform-conditional Behavior)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 8: DPAPI Edge Cases - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-CryptoTests
}

