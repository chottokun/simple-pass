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

    # Test 14: Derive-KeyIVAndHmac Happy Path
    try {
        $pwd = "SecureMasterPassword1!"
        $salt = [System.Text.Encoding]::UTF8.GetBytes("SuperSecretSaltValue123456789012")

        $derived = Derive-KeyIVAndHmac -Password $pwd -Salt $salt

        Assert-True ($null -ne $derived) "Derived result is not null"
        Assert-True ($derived.AesKey.Length -eq 32) "AES key length is exactly 32 bytes"
        Assert-True ($derived.AesIV.Length -eq 16) "AES IV length is exactly 16 bytes"
        Assert-True ($derived.HmacKey.Length -eq 32) "HMAC key length is exactly 32 bytes"
        Assert-True ($derived.AesKey -is [byte[]]) "AES key is a byte array"
        Assert-True ($derived.AesIV -is [byte[]]) "AES IV is a byte array"
        Assert-True ($derived.HmacKey -is [byte[]]) "HMAC key is a byte array"

        $results.Passed++
        $results.Log += "[PASS] Test 14: Derive-KeyIVAndHmac Happy Path and Key Lengths"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 14: Derive-KeyIVAndHmac Happy Path - $_"
    }

    # Test 15: Derive-KeyIVAndHmac Determinism
    try {
        $pwd = "DeterministicPwd"
        $salt = [System.Text.Encoding]::UTF8.GetBytes("SomeSaltForDeterminismTesting")

        $derived1 = Derive-KeyIVAndHmac -Password $pwd -Salt $salt
        $derived2 = Derive-KeyIVAndHmac -Password $pwd -Salt $salt

        # Verify AES Key matches
        $keysMatch = $true
        for ($i = 0; $i -lt 32; $i++) {
            if ($derived1.AesKey[$i] -ne $derived2.AesKey[$i]) {
                $keysMatch = $false
            }
        }
        Assert-True $keysMatch "Deterministic AES keys match exactly"

        # Verify AES IV matches
        $ivsMatch = $true
        for ($i = 0; $i -lt 16; $i++) {
            if ($derived1.AesIV[$i] -ne $derived2.AesIV[$i]) {
                $ivsMatch = $false
            }
        }
        Assert-True $ivsMatch "Deterministic AES IVs match exactly"

        # Verify HMAC Key matches
        $hmacKeysMatch = $true
        for ($i = 0; $i -lt 32; $i++) {
            if ($derived1.HmacKey[$i] -ne $derived2.HmacKey[$i]) {
                $hmacKeysMatch = $false
            }
        }
        Assert-True $hmacKeysMatch "Deterministic HMAC keys match exactly"

        $results.Passed++
        $results.Log += "[PASS] Test 15: Derive-KeyIVAndHmac Determinism"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 15: Derive-KeyIVAndHmac Determinism - $_"
    }

    # Test 16: Derive-KeyIVAndHmac Input Sensitivity (Different Inputs produce Different Outputs)
    try {
        $pwd1 = "PasswordOne"
        $pwd2 = "PasswordTwo"
        $salt1 = [System.Text.Encoding]::UTF8.GetBytes("SaltNumberOne")
        $salt2 = [System.Text.Encoding]::UTF8.GetBytes("SaltNumberTwo")

        $derived1 = Derive-KeyIVAndHmac -Password $pwd1 -Salt $salt1
        $derived2 = Derive-KeyIVAndHmac -Password $pwd2 -Salt $salt1
        $derived3 = Derive-KeyIVAndHmac -Password $pwd1 -Salt $salt2

        # Compare pwd1 vs pwd2 with same salt
        $diffPwdKeys = $false
        for ($i = 0; $i -lt 32; $i++) {
            if ($derived1.AesKey[$i] -ne $derived2.AesKey[$i]) {
                $diffPwdKeys = $true
                break
            }
        }
        Assert-True $diffPwdKeys "Different passwords produce different AES keys"

        # Compare salt1 vs salt2 with same password
        $diffSaltKeys = $false
        for ($i = 0; $i -lt 32; $i++) {
            if ($derived1.AesKey[$i] -ne $derived3.AesKey[$i]) {
                $diffSaltKeys = $true
                break
            }
        }
        Assert-True $diffSaltKeys "Different salts produce different AES keys"

        $results.Passed++
        $results.Log += "[PASS] Test 16: Derive-KeyIVAndHmac Input Sensitivity"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 16: Derive-KeyIVAndHmac Input Sensitivity - $_"
    }

    # Test 17: Derive-KeyIVAndHmac Iteration Parameter Sensitivity
    try {
        $pwd = "IterationTestPwd"
        $salt = [System.Text.Encoding]::UTF8.GetBytes("IterationTestSalt")

        $derived1 = Derive-KeyIVAndHmac -Password $pwd -Salt $salt -Iterations 1000
        $derived2 = Derive-KeyIVAndHmac -Password $pwd -Salt $salt -Iterations 2000

        # Verify they produce different outputs due to different iterations
        $diffIterationKeys = $false
        for ($i = 0; $i -lt 32; $i++) {
            if ($derived1.AesKey[$i] -ne $derived2.AesKey[$i]) {
                $diffIterationKeys = $true
                break
            }
        }
        Assert-True $diffIterationKeys "Different iterations produce different AES keys"

        $results.Passed++
        $results.Log += "[PASS] Test 17: Derive-KeyIVAndHmac Iterations Sensitivity"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 17: Derive-KeyIVAndHmac Iterations Sensitivity - $_"
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

