# CryptoModule.psm1 - Best-practice Security Core (PBKDF2-SHA256 + AES-256 + HMAC-SHA256)

Add-Type -AssemblyName System.Security

function New-CryptoSalt {
    [CmdletBinding()]
    param([int]$Length = 32)
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($bytes)
    } finally {
        $rng.Dispose()
    }
    return $bytes
}

function Derive-KeyIVAndHmac {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Password,
        [Parameter(Mandatory=$true)]
        [byte[]]$Salt,
        [int]$Iterations = 100000
    )
    # Generate 80 bytes: 32 (AES-256 Key) + 16 (AES IV) + 32 (HMAC Key) using SHA-256
    $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
        $Password, $Salt, $Iterations,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    try {
        $aesKey  = $pbkdf2.GetBytes(32)
        $aesIV   = $pbkdf2.GetBytes(16)
        $hmacKey = $pbkdf2.GetBytes(32)
        return @{ AesKey = $aesKey; AesIV = $aesIV; HmacKey = $hmacKey }
    } finally {
        $pbkdf2.Dispose()
    }
}

function Protect-DataWithAes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PlainText,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesIV
    )
    $aes = [System.Security.Cryptography.Aes]::Create()
    try {
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $AesKey
        $aes.IV = $AesIV
        $encryptor = $aes.CreateEncryptor()
        try {
            $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
            $cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
            return $cipherBytes
        } finally {
            $encryptor.Dispose()
        }
    } finally {
        $aes.Dispose()
    }
}

function Unprotect-DataWithAes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [byte[]]$CipherBytes,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesKey,
        [Parameter(Mandatory=$true)]
        [byte[]]$AesIV
    )
    $aes = [System.Security.Cryptography.Aes]::Create()
    try {
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
        $aes.Key = $AesKey
        $aes.IV = $AesIV
        $decryptor = $aes.CreateDecryptor()
        try {
            $plainBytes = $decryptor.TransformFinalBlock($CipherBytes, 0, $CipherBytes.Length)
            return [System.Text.Encoding]::UTF8.GetString($plainBytes)
        } finally {
            $decryptor.Dispose()
        }
    } finally {
        $aes.Dispose()
    }
}

function Protect-DataWithDpapi {
    [CmdletBinding()]
    param([byte[]]$Data)
    return [System.Security.Cryptography.ProtectedData]::Protect(
        $Data,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
}

function Unprotect-DataWithDpapi {
    [CmdletBinding()]
    param([byte[]]$EncryptedData)
    return [System.Security.Cryptography.ProtectedData]::Unprotect(
        $EncryptedData,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
}

function Get-HmacSignature {
    param([byte[]]$Data, [byte[]]$HmacKey)
    $hmac = New-Object System.Security.Cryptography.HMACSHA256(@(,$HmacKey))
    try {
        $sig = $hmac.ComputeHash($Data)
        return $sig
    } finally {
        $hmac.Dispose()
    }
}

function ConvertTo-EncryptedVaultData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$JsonText,
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword,
        [switch]$UseDpapi = $false
    )
    $salt = New-CryptoSalt -Length 32
    $derived = Derive-KeyIVAndHmac -Password $MasterPassword -Salt $salt
    $aesCipher = Protect-DataWithAes -PlainText $JsonText -AesKey $derived.AesKey -AesIV $derived.AesIV

    $targetBytes = $aesCipher
    if ($UseDpapi) {
        $targetBytes = Protect-DataWithDpapi -Data $aesCipher
    }

    # HMAC Signature for tampering detection
    $hmacSig = Get-HmacSignature -Data $targetBytes -HmacKey $derived.HmacKey

    return @{
        version  = "2.0"
        useDpapi = [bool]$UseDpapi
        salt     = [Convert]::ToBase64String($salt)
        hmac     = [Convert]::ToBase64String($hmacSig)
        data     = [Convert]::ToBase64String($targetBytes)
    }
}

function ConvertFrom-EncryptedVaultData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$VaultHashtable,
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword
    )
    if (-not $VaultHashtable.salt -or -not $VaultHashtable.data) {
        throw "Vault data format is invalid."
    }

    # 1. Check for HMAC presence (v2.0 requirement)
    if (-not $VaultHashtable.hmac) {
        throw "Vault integrity data (HMAC) is missing. Unsupported vault format or version."
    }

    $salt = [Convert]::FromBase64String($VaultHashtable.salt)
    $rawBytes = [Convert]::FromBase64String($VaultHashtable.data)
    $derived = Derive-KeyIVAndHmac -Password $MasterPassword -Salt $salt

    # Constant-time comparison for HMAC to prevent timing attacks
    $expectedHmac = [Convert]::FromBase64String($VaultHashtable.hmac)
    $actualHmac = Get-HmacSignature -Data $rawBytes -HmacKey $derived.HmacKey
    
    $diff = $expectedHmac.Length -bxor $actualHmac.Length
    $len = [Math]::Min($expectedHmac.Length, $actualHmac.Length)
    for ($i = 0; $i -lt $len; $i++) {
        $diff = $diff -bor ($expectedHmac[$i] -bxor $actualHmac[$i])
    }
    if ($diff -ne 0) {
        throw "Integrity check failed: Data has been tampered with or incorrect Master Password used."
    }

    # 2. DPAPI Unprotect if enabled
    $aesCipher = $rawBytes
    if ($VaultHashtable.useDpapi -eq $true) {
        $aesCipher = Unprotect-DataWithDpapi -EncryptedData $rawBytes
    }

    # 3. AES Decryption
    $jsonText = Unprotect-DataWithAes -CipherBytes $aesCipher -AesKey $derived.AesKey -AesIV $derived.AesIV
    return $jsonText
}

Export-ModuleMember -Function ConvertTo-EncryptedVaultData, ConvertFrom-EncryptedVaultData, New-CryptoSalt, Derive-KeyIVAndHmac, Protect-DataWithAes, Unprotect-DataWithAes, Protect-DataWithDpapi, Unprotect-DataWithDpapi, Get-HmacSignature

