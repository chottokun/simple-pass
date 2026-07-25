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

    # Test 7: New-CryptoSalt default length
    try {
        $salt = [byte[]](New-CryptoSalt)
        Assert-True ($null -ne $salt) "Salt should not be null"
        Assert-True ($salt.GetType().Name -eq "Byte[]") "Salt should be a byte array"
        Assert-True ($salt.Length -eq 32) "Default salt length should be 32"
        $results.Passed++
        $results.Log += "[PASS] Test 7: New-CryptoSalt default length (32 bytes)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: New-CryptoSalt default length - $_"
    }

    # Test 8: New-CryptoSalt custom lengths
    try {
        $salt16 = New-CryptoSalt -Length 16
        Assert-True ($salt16.Length -eq 16) "Salt length should be 16"

        $salt64 = New-CryptoSalt -Length 64
        Assert-True ($salt64.Length -eq 64) "Salt length should be 64"
        $results.Passed++
        $results.Log += "[PASS] Test 8: New-CryptoSalt custom lengths (16, 64 bytes)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 8: New-CryptoSalt custom lengths - $_"
    }

    # Test 9: New-CryptoSalt uniqueness and randomness
    try {
        $saltA = New-CryptoSalt -Length 32
        $saltB = New-CryptoSalt -Length 32

        # Verify that two subsequently generated salts are not identical (highly unlikely to be identical with CSPRNG)
        $areIdentical = $true
        for ($i = 0; $i -lt 32; $i++) {
            if ($saltA[$i] -ne $saltB[$i]) {
                $areIdentical = $false
                break
            }
        }
        Assert-True (-not $areIdentical) "Two generated salts of 32 bytes should be different (randomness verification)"
        $results.Passed++
        $results.Log += "[PASS] Test 9: New-CryptoSalt uniqueness/randomness"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 9: New-CryptoSalt uniqueness/randomness - $_"
    }

    # Test 10: New-CryptoSalt boundary and error cases
    try {
        $failedAsExpected = $false
        try {
            $invalidSalt = New-CryptoSalt -Length -5
        } catch {
            $failedAsExpected = $true
        }
        Assert-True $failedAsExpected "Generating a salt with a negative length should fail/throw"
        $results.Passed++
        $results.Log += "[PASS] Test 10: New-CryptoSalt negative length handling"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 10: New-CryptoSalt negative length handling - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-CryptoTests
}

