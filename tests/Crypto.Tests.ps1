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

    # Test 7: Get-HmacSignature - Happy path / Known vector validation
    try {
        $testData = [byte[]]@(10, 11, 12)
        $testKey = [byte[]]@(1, 2, 3)
        $sig = Get-HmacSignature -Data $testData -HmacKey $testKey

        $sigBase64 = [Convert]::ToBase64String($sig)
        $expectedBase64 = "7A7u7vnHiED1Ij9vlkHt8YmaqnylTtkbeGWteOzRnMY="
        Assert-True ($sigBase64 -eq $expectedBase64) "HMAC signature matches expected test vector"
        $results.Passed++
        $results.Log += "[PASS] Test 7: Get-HmacSignature - Happy path / Known vector validation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: Get-HmacSignature happy path test - $_"
    }

    # Test 8: Get-HmacSignature - Different inputs or keys produce distinct signatures
    try {
        $testData1 = [byte[]]@(10, 11, 12)
        $testData2 = [byte[]]@(10, 11, 13)
        $testKey1 = [byte[]]@(1, 2, 3)
        $testKey2 = [byte[]]@(1, 2, 4)

        $sig1 = Get-HmacSignature -Data $testData1 -HmacKey $testKey1
        $sig2 = Get-HmacSignature -Data $testData2 -HmacKey $testKey1
        $sig3 = Get-HmacSignature -Data $testData1 -HmacKey $testKey2

        $sig1Base64 = [Convert]::ToBase64String($sig1)
        $sig2Base64 = [Convert]::ToBase64String($sig2)
        $sig3Base64 = [Convert]::ToBase64String($sig3)

        Assert-True ($sig1Base64 -ne $sig2Base64) "Different input data yields different HMAC signature"
        Assert-True ($sig1Base64 -ne $sig3Base64) "Different key yields different HMAC signature"
        $results.Passed++
        $results.Log += "[PASS] Test 8: Get-HmacSignature - Different inputs or keys produce distinct signatures"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 8: Get-HmacSignature distinct signatures test - $_"
    }

    # Test 9: Get-HmacSignature - Edge cases (empty data or empty key)
    try {
        $emptyData = [byte[]]@()
        $emptyKey = [byte[]]@()
        $testData = [byte[]]@(10, 11, 12)
        $testKey = [byte[]]@(1, 2, 3)

        $sigEmptyBoth = Get-HmacSignature -Data $emptyData -HmacKey $emptyKey
        $sigEmptyData = Get-HmacSignature -Data $emptyData -HmacKey $testKey
        $sigEmptyKey = Get-HmacSignature -Data $testData -HmacKey $emptyKey

        Assert-True ($null -ne $sigEmptyBoth) "HMAC signature computed with empty data and key is not null"
        Assert-True ($null -ne $sigEmptyData) "HMAC signature computed with empty data is not null"
        Assert-True ($null -ne $sigEmptyKey) "HMAC signature computed with empty key is not null"

        # Verify changing key with empty data also changes signature
        $sigEmptyDataOtherKey = Get-HmacSignature -Data $emptyData -HmacKey ([byte[]]@(4, 5, 6))
        Assert-True ([Convert]::ToBase64String($sigEmptyData) -ne [Convert]::ToBase64String($sigEmptyDataOtherKey)) "HMAC of empty data with different keys are distinct"

        $results.Passed++
        $results.Log += "[PASS] Test 9: Get-HmacSignature - Edge cases (empty data or empty key)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 9: Get-HmacSignature edge cases test - $_"
    }

    # Test 10: New-CryptoSalt default length
    try {
        $salt = New-CryptoSalt
        Assert-True ($null -ne $salt) "Salt should not be null"
        Assert-True ($salt.Count -eq 32) "Default salt length should be 32 bytes"
        Assert-True ($salt[0].GetType().FullName -eq "System.Byte") "Salt should be an array of bytes"
        $results.Passed++
        $results.Log += "[PASS] Test 10: New-CryptoSalt default length is 32 bytes"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 10: New-CryptoSalt default length - $_"
    }

    # Test 11: New-CryptoSalt custom lengths
    try {
        $salt16 = New-CryptoSalt -Length 16
        Assert-True ($salt16.Count -eq 16) "Custom salt length 16 bytes"

        $salt64 = New-CryptoSalt -Length 64
        Assert-True ($salt64.Count -eq 64) "Custom salt length 64 bytes"

        $salt0 = New-CryptoSalt -Length 0
        Assert-True ($salt0.Count -eq 0) "Custom salt length 0 bytes"

        $results.Passed++
        $results.Log += "[PASS] Test 11: New-CryptoSalt supports custom lengths (0, 16, 64)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 11: New-CryptoSalt custom lengths - $_"
    }

    # Test 12: New-CryptoSalt uniqueness and randomness
    try {
        $saltA = New-CryptoSalt -Length 32
        $saltB = New-CryptoSalt -Length 32

        # Check that they are not identical
        $areIdentical = $true
        for ($i = 0; $i -lt 32; $i++) {
            if ($saltA[$i] -ne $saltB[$i]) {
                $areIdentical = $false
                break
            }
        }
        Assert-True (-not $areIdentical) "Consecutive salt values must be unique/random"

        $results.Passed++
        $results.Log += "[PASS] Test 12: New-CryptoSalt consecutive outputs are unique and random"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 12: New-CryptoSalt uniqueness - $_"
    }

    # Test 13: New-CryptoSalt invalid inputs (negative length)
    try {
        $failedAsExpected = $false
        try {
            $invalidSalt = New-CryptoSalt -Length -5
        } catch {
            $failedAsExpected = $true
        }
        Assert-True $failedAsExpected "New-CryptoSalt should fail with negative length"

        $results.Passed++
        $results.Log += "[PASS] Test 13: New-CryptoSalt handles negative length error cleanly"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 13: New-CryptoSalt invalid inputs - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-CryptoTests
}

