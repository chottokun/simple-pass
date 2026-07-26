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

    # Test 7: Direct AES Round-trip Encryption & Decryption (Protect-DataWithAes & Unprotect-DataWithAes)
    try {
        $plainText = "This is a highly secret credential string to protect 12345!"
        $aesKey = New-Object byte[] 32
        $aesIV = New-Object byte[] 16

        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($aesKey)
        $rng.GetBytes($aesIV)
        $rng.Dispose()

        $cipherBytes = Protect-DataWithAes -PlainText $plainText -AesKey $aesKey -AesIV $aesIV
        Assert-True ($null -ne $cipherBytes) "Cipher bytes generated"
        Assert-True ($cipherBytes.Length -gt 0) "Cipher bytes are not empty"

        $decrypted = Unprotect-DataWithAes -CipherBytes $cipherBytes -AesKey $aesKey -AesIV $aesIV
        Assert-True ($decrypted -eq $plainText) "Decrypted text matches the original plaintext"

        $results.Passed++
        $results.Log += "[PASS] Test 7: Direct AES Round-trip Encryption & Decryption"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: Direct AES Round-trip Encryption & Decryption - $_"
    }

    # Test 8: Protect-DataWithAes Handling of Special Characters and Empty/Blank Inputs
    try {
        $specialTexts = @(
            "日本語の文字とEmoji 🔐🔑✨",
            "   "
        )
        $aesKey = New-Object byte[] 32
        $aesIV = New-Object byte[] 16

        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($aesKey)
        $rng.GetBytes($aesIV)
        $rng.Dispose()

        foreach ($text in $specialTexts) {
            $cipherBytes = Protect-DataWithAes -PlainText $text -AesKey $aesKey -AesIV $aesIV
            $decrypted = Unprotect-DataWithAes -CipherBytes $cipherBytes -AesKey $aesKey -AesIV $aesIV
            Assert-True ($decrypted -eq $text) "Round-trip matches for special / blank text: '$text'"
        }

        # Validate that empty string (which is mandatory) fails parameter binding / validation
        $emptyStringThrew = $false
        try {
            $dummy = Protect-DataWithAes -PlainText "" -AesKey $aesKey -AesIV $aesIV
        } catch {
            $emptyStringThrew = $true
        }
        Assert-True $emptyStringThrew "Protect-DataWithAes correctly throws when PlainText is an empty string"

        $results.Passed++
        $results.Log += "[PASS] Test 8: Protect-DataWithAes Special Characters & Empty Inputs"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 8: Protect-DataWithAes Special Characters & Empty Inputs - $_"
    }

    # Test 9: AES Encryption Uniqueness (Different IVs produce different ciphertexts)
    try {
        $plainText = "Consistent plaintext that will be encrypted twice"
        $aesKey = New-Object byte[] 32
        $aesIV1 = New-Object byte[] 16
        $aesIV2 = New-Object byte[] 16

        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($aesKey)
        $rng.GetBytes($aesIV1)
        # Ensure IV2 is different from IV1
        do {
            $rng.GetBytes($aesIV2)
        } while ([System.BitConverter]::ToString($aesIV1) -eq [System.BitConverter]::ToString($aesIV2))
        $rng.Dispose()

        $cipherBytes1 = Protect-DataWithAes -PlainText $plainText -AesKey $aesKey -AesIV $aesIV1
        $cipherBytes2 = Protect-DataWithAes -PlainText $plainText -AesKey $aesKey -AesIV $aesIV2

        $hex1 = [System.BitConverter]::ToString($cipherBytes1)
        $hex2 = [System.BitConverter]::ToString($cipherBytes2)

        Assert-True ($hex1 -ne $hex2) "Ciphertexts encrypted with different IVs must be different"
        $results.Passed++
        $results.Log += "[PASS] Test 9: AES Encryption Uniqueness with different IVs"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 9: AES Encryption Uniqueness - $_"
    }

    # Test 10: AES Error Handling (Incorrect Key/IV Sizes)
    try {
        $plainText = "Some plaintext"
        $correctKey = New-Object byte[] 32
        $correctIV = New-Object byte[] 16
        $invalidKey = New-Object byte[] 31 # Invalid size (not 16, 24, or 32)
        $invalidIV = New-Object byte[] 15  # Invalid size (not 16)

        $protectKeyError = $false
        try {
            $dummy = Protect-DataWithAes -PlainText $plainText -AesKey $invalidKey -AesIV $correctIV
        } catch {
            $protectKeyError = $true
        }
        Assert-True $protectKeyError "Protect-DataWithAes throws exception when key size is invalid"

        $protectIVError = $false
        try {
            $dummy = Protect-DataWithAes -PlainText $plainText -AesKey $correctKey -AesIV $invalidIV
        } catch {
            $protectIVError = $true
        }
        Assert-True $protectIVError "Protect-DataWithAes throws exception when IV size is invalid"

        $unprotectKeyError = $false
        try {
            $dummy = Unprotect-DataWithAes -CipherBytes (New-Object byte[] 16) -AesKey $invalidKey -AesIV $correctIV
        } catch {
            $unprotectKeyError = $true
        }
        Assert-True $unprotectKeyError "Unprotect-DataWithAes throws exception when key size is invalid"

        $unprotectIVError = $false
        try {
            $dummy = Unprotect-DataWithAes -CipherBytes (New-Object byte[] 16) -AesKey $correctKey -AesIV $invalidIV
        } catch {
            $unprotectIVError = $true
        }
        Assert-True $unprotectIVError "Unprotect-DataWithAes throws exception when IV size is invalid"

        $results.Passed++
        $results.Log += "[PASS] Test 10: AES Encryption Cryptographic Parameter Validations"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 10: AES Encryption Cryptographic Parameter Validations - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-CryptoTests
}

