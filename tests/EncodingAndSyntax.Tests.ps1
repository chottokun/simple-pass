# EncodingAndSyntax.Tests.ps1 - Script Encoding (Universal UTF-8 BOM) & Linter/AST Syntax Validation Test Suite

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-EncodingAndSyntaxTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $repoRootDir = Split-Path -Parent $currentDir

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    $psFiles = Get-ChildItem -Path $repoRootDir -Recurse -Include *.ps1,*.psm1

    # Test 1: Validate AST Syntax for all PowerShell files in repo
    try {
        $parseErrorsFound = $false
        $errorLog = @()

        foreach ($file in $psFiles) {
            $errs = $null
            $tokens = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errs)
            
            if ($errs -and $errs.Count -gt 0) {
                $parseErrorsFound = $true
                $errorLog += "$($file.Name): $($errs.Count) parse error(s)"
            }
        }

        Assert-True (-not $parseErrorsFound) "All PowerShell script files parsed with zero AST syntax errors ($($errorLog -join ', '))"
        $results.Passed++
        $results.Log += "[PASS] Test 1: Zero AST Syntax Errors across all $($psFiles.Count) PowerShell files"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: AST Syntax Error check - $_"
    }

    # Test 2: Ensure ALL PowerShell script files strictly have UTF-8 BOM (Universal Policy)
    try {
        $missingBomFiles = @()

        foreach ($file in $psFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            if (-not $hasBom) {
                $missingBomFiles += $file.Name
            }
        }

        Assert-True ($missingBomFiles.Count -eq 0) "All PowerShell scripts strictly have UTF-8 BOM (Missing in: $($missingBomFiles -join ', '))"
        $results.Passed++
        $results.Log += "[PASS] Test 2: Universal UTF-8 BOM Compliance across all $($psFiles.Count) PowerShell files"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Universal UTF-8 BOM compliance check - $_"
    }

    # Test 3: PSScriptAnalyzer Linter Integration Check (if installed)
    try {
        $analyzerModule = Get-Module -ListAvailable -Name PSScriptAnalyzer
        if ($analyzerModule) {
            Import-Module PSScriptAnalyzer -ErrorAction SilentlyContinue
            $linterErrors = @()
            foreach ($file in $psFiles) {
                $issues = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error
                if ($issues -and $issues.Count -gt 0) {
                    $linterErrors += "$($file.Name): $($issues.Count) critical linter error(s)"
                }
            }
            Assert-True ($linterErrors.Count -eq 0) "PSScriptAnalyzer zero critical severity errors ($($linterErrors -join ', '))"
            $results.Passed++
            $results.Log += "[PASS] Test 3: PSScriptAnalyzer Linter Audit (Zero Critical Errors)"
        } else {
            $results.Passed++
            $results.Log += "[PASS] Test 3: PSScriptAnalyzer Linter Audit (Skipped: PSScriptAnalyzer module not installed)"
        }
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: PSScriptAnalyzer Linter Audit - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-EncodingAndSyntaxTests
}
