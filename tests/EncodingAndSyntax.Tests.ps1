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

    # Test 2: Ensure PowerShell scripts (.ps1, .psm1, .psd1) have UTF-8 BOM, while Batch (.bat) files strictly have NO BOM (cmd.exe compatibility)
    try {
        $missingBomFiles = @()
        $scriptFiles = Get-ChildItem -Path $repoRootDir -Recurse -Include *.ps1,*.psm1,*.psd1
        foreach ($file in $scriptFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            if (-not $hasBom) {
                $missingBomFiles += $file.Name
            }
        }
        Assert-True ($missingBomFiles.Count -eq 0) "All PowerShell scripts (.ps1, .psm1, .psd1) strictly have UTF-8 BOM (Missing in: $($missingBomFiles -join ', '))"

        $unexpectedBomBatFiles = @()
        $batFiles = Get-ChildItem -Path $repoRootDir -Recurse -Include *.bat
        foreach ($file in $batFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
            if ($hasBom) {
                $unexpectedBomBatFiles += $file.Name
            }
        }
        Assert-True ($unexpectedBomBatFiles.Count -eq 0) "All Batch files (.bat) strictly have NO BOM for cmd.exe compatibility (Has BOM in: $($unexpectedBomBatFiles -join ', '))"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Encoding Compliance (PowerShell UTF-8 BOM & Batch No-BOM)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Encoding Compliance check - $_"
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

    # Test 4: Validate all .psd1 localization resource files for Import-PowerShellDataFile parsing
    try {
        $psd1Files = Get-ChildItem -Path $repoRootDir -Recurse -Include *.psd1
        $psd1ParseErrors = @()
        foreach ($file in $psd1Files) {
            try {
                $null = Import-PowerShellDataFile -Path $file.FullName -ErrorAction Stop
            } catch {
                $psd1ParseErrors += "$($file.Name): $($_.Exception.Message)"
            }
        }
        Assert-True ($psd1ParseErrors.Count -eq 0) "All .psd1 files imported without errors ($($psd1ParseErrors -join ', '))"
        $results.Passed++
        $results.Log += "[PASS] Test 4: All .psd1 Data Files Parse Cleanly with Import-PowerShellDataFile"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: .psd1 Data File Import check - $_"
    }

    # Test 5: Validate Batch File Invocation via cmd.exe (Verify no '@echo' error output)
    try {
        $batFiles = Get-ChildItem -Path $repoRootDir -Filter "*.bat"
        foreach ($bat in $batFiles) {
            # Create a lightweight mock copy replacing powershell call with mock exit to avoid GUI blocking
            $tempBat = Join-Path (Get-Location) "test_temp_$($bat.Name)"
            $content = Get-Content $bat.FullName -Raw
            $mockContent = $content -replace "powershell -ExecutionPolicy Bypass.*", "echo BATCH_OK"
            [System.IO.File]::WriteAllText($tempBat, $mockContent, (New-Object System.Text.UTF8Encoding($false)))

            try {
                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                $pinfo.FileName = "cmd.exe"
                $pinfo.Arguments = "/c `"$tempBat`""
                $pinfo.RedirectStandardError = $true
                $pinfo.RedirectStandardOutput = $true
                $pinfo.UseShellExecute = $false
                $pinfo.CreateNoWindow = $true

                $proc = [System.Diagnostics.Process]::Start($pinfo)
                $stdout = $proc.StandardOutput.ReadToEnd()
                $stderr = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit(2000)

                Assert-True ($stdout -match "BATCH_OK") "Batch file $($bat.Name) executed mock script successfully"
                Assert-True ($stderr -notmatch "'・ｿ@echo'" -and $stderr -notmatch "'@echo'") "Batch file $($bat.Name) executes in cmd.exe without BOM command error"
            } finally {
                if (Test-Path $tempBat) { Remove-Item $tempBat -Force -ErrorAction SilentlyContinue }
            }
        }
        $results.Passed++
        $results.Log += "[PASS] Test 5: Batch File Invocation via cmd.exe Validation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 5: Batch File Invocation check - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-EncodingAndSyntaxTests
}
