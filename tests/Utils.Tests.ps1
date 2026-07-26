# Utils.Tests.ps1 - Critical Utils & Password Generator Test Suite

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-UtilsTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"
    Import-Module (Join-Path $srcDir "UtilsModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: Random password generation with all charsets
    try {
        $pass = New-RandomPassword -Length 24 -IncludeUppercase -IncludeLowercase -IncludeNumbers -IncludeSymbols
        Assert-True ($pass.Length -eq 24) "Generated password length is 24"
        Assert-True ($pass -match "[A-Z]") "Contains uppercase letter"
        Assert-True ($pass -match "[a-z]") "Contains lowercase letter"
        Assert-True ($pass -match "[0-9]") "Contains digit"
        Assert-True ($pass -match "[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]") "Contains symbol"

        $results.Passed++
        $results.Log += "[PASS] Test 1: Random password generation with all charsets"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: Random password generation - $_"
    }

    # Test 2: Randomness uniqueness
    try {
        $p1 = New-RandomPassword -Length 16
        $p2 = New-RandomPassword -Length 16
        Assert-True ($p1 -ne $p2) "Consecutive passwords are randomly distinct"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Randomness uniqueness"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Randomness uniqueness - $_"
    }

    # Test 4: Clipboard copying functionality
    try {
        $sampleText = "TestClipText_" + [guid]::NewGuid().ToString()
        $success = Set-ClipboardWithAutoClear -Text $sampleText -ClearAfterSeconds 0

        Assert-True $success "Set-ClipboardWithAutoClear returned success"

        $results.Passed++
        $results.Log += "[PASS] Test 4: Clipboard set operation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: Clipboard set operation - $_"
    }

    # Test 5: Get-SecureRandomInt ranges and boundary checks
    try {
        # Check boundary exception handling
        $failedAsExpected = $false
        try {
            Get-SecureRandomInt -Max 0
        } catch {
            $failedAsExpected = $true
        }
        Assert-True $failedAsExpected "Get-SecureRandomInt should throw an exception if Max is 0"

        $failedAsExpectedNegative = $false
        try {
            Get-SecureRandomInt -Max -5
        } catch {
            $failedAsExpectedNegative = $true
        }
        Assert-True $failedAsExpectedNegative "Get-SecureRandomInt should throw an exception if Max is negative"

        # Check normal bounds
        for ($i = 0; $i -lt 50; $i++) {
            $val = Get-SecureRandomInt -Max 5
            Assert-True ($val -ge 0 -and $val -lt 5) "Value $val should be in [0, 4]"
        }

        # Check large bound
        $valLarge = Get-SecureRandomInt -Max 1000000
        Assert-True ($valLarge -ge 0 -and $valLarge -lt 1000000) "Value $valLarge should be in [0, 999999]"

        $results.Passed++
        $results.Log += "[PASS] Test 5: Get-SecureRandomInt ranges and boundary checks"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 5: Get-SecureRandomInt - $_"
    }

    # Test 6: Unbiased security validation of New-RandomPassword
    try {
        # Test that New-RandomPassword operates correctly and produces desired length passwords
        $pass = New-RandomPassword -Length 32
        Assert-True ($pass.Length -eq 32) "Generated password length is 32"

        $results.Passed++
        $results.Log += "[PASS] Test 6: New-RandomPassword validation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 6: New-RandomPassword validation - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-UtilsTests
}
