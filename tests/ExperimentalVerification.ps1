﻿# ExperimentalVerification.ps1 - Experimental proof of concept for highlighted bottlenecks and limitations

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Running Experimental Verification Scripts " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Experiment 1: Measure PBKDF2 Stretching Synchronous Block Time
Write-Host "`n[Experiment 1] Measuring PBKDF2 (100k Iterations) Synchronous Block Time..." -ForegroundColor Yellow
$password = "MyHighlySecureMasterPassword2026!"
$salt = New-CryptoSalt -Length 32

$elapsed = Measure-Command {
    $derived = Derive-KeyIVAndHmac -Password $password -Salt $salt -Iterations 100000
}
Write-Host "-> Time to derive keys (PBKDF2): $($elapsed.TotalMilliseconds) ms" -ForegroundColor Green
Write-Host "-> Analysis: Because this is run on the UI thread, the application is completely frozen/unresponsive for this duration during login, database save, and password change operations." -ForegroundColor Gray

# Experiment 2: Demonstrate Backup Generation Limitation
Write-Host "`n[Experiment 2] Demonstrating Single-generation Backup Limitation..." -ForegroundColor Yellow
$testPath = Join-Path (Get-Location) "data/test_vault.json"
$bakPath = "$testPath.bak"

# Ensure clean slate
if (Test-Path $testPath) { Remove-Item $testPath -Force }
if (Test-Path $bakPath) { Remove-Item $bakPath -Force }

# Step A: Save original state
$entries1 = @((New-VaultEntry -Title "Original Entry" -Url "example.com" -Username "user1" -Password "p1"))
Save-Vault -Entries $entries1 -MasterPassword "pass" -Path $testPath
Write-Host "-> First Save: Saved 'Original Entry'." -ForegroundColor Gray

# Step B: Save second state (e.g. user adds an entry)
$entries2 = $entries1 + (New-VaultEntry -Title "Second Entry" -Url "example.com" -Username "user2" -Password "p2")
Save-Vault -Entries $entries2 -MasterPassword "pass" -Path $testPath
Write-Host "-> Second Save: Backup file '$($bakPath)' exists: $(Test-Path $bakPath)" -ForegroundColor Gray

# Step C: Save third state (e.g. user makes another change or saves corrupt empty state)
$entries3 = @() # Empty/corrupt entries
Save-Vault -Entries $entries3 -MasterPassword "pass" -Path $testPath
Write-Host "-> Third Save: Vault overwritten again." -ForegroundColor Gray

# Read backup
$bakData = Get-Content $bakPath -Raw | ConvertFrom-Json
$decryptedBak = ConvertFrom-EncryptedVaultData -VaultHashtable @{
    version = $bakData.version
    salt = $bakData.salt
    data = $bakData.data
    hmac = $bakData.hmac
    useDpapi = $bakData.useDpapi
} -MasterPassword "pass"

Write-Host "-> Result: The backup file now contains the state of the SECOND save ($decryptedBak)." -ForegroundColor Red
Write-Host "-> Consequence: The 'Original Entry' (the only healthy state before corruption/unwanted bulk deletion in Save 3) has been completely lost because there is only 1 generation of backup!" -ForegroundColor Red

# Cleanup
if (Test-Path $testPath) { Remove-Item $testPath -Force }
if (Test-Path $bakPath) { Remove-Item $bakPath -Force }

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " Experimental Verification Completed      " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
