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

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-UtilsTests
}
