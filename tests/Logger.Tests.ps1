# Logger.Tests.ps1 - Logging & Exception Tracking Test Suite

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-LoggerTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"

    Import-Module (Join-Path $srcDir "LoggerModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: Log file creation and entry formatting
    try {
        $testMsg = "Logger Test Message " + [guid]::NewGuid().ToString()
        Write-AppLog -Level WARN -Message $testMsg

        $logPath = Get-LogFilePath
        Assert-True (Test-Path $logPath) "Log file exists"

        $logContent = Get-Content $logPath -Raw
        Assert-True ($logContent.Contains($testMsg)) "Log file contains recorded test message"
        Assert-True ($logContent.Contains("[WARN]")) "Log level [WARN] correctly formatted"

        $results.Passed++
        $results.Log += "[PASS] Test 1: App Log Recording & File Creation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: App Log Recording - $_"
    }

    # Test 2: Exception Stack Trace Logging
    try {
        $exMsg = "Simulated Critical Failure"
        $recordedEx = $null
        try {
            throw (New-Object System.InvalidOperationException("Simulated Critical Failure"))
        } catch {
            $recordedEx = $_.Exception
            Write-AppLog -Level ERROR -Message "Catch Test Exception" -Exception $recordedEx
        }

        $logContent = Get-Content (Get-LogFilePath) -Raw
        Assert-True ($logContent.Contains("Catch Test Exception")) "Exception message recorded"
        Assert-True ($logContent.Contains("InvalidOperationException")) "Exception class recorded"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Exception StackTrace Logging"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Exception StackTrace Logging - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-LoggerTests
}
