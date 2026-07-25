# LoggerModule.psm1 - App-wide Logging & Unhandled Exception Management

function Get-LogFilePath {
    $scriptDir = Split-Path -Parent $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = Get-Location }
    $logDir = Join-Path $scriptDir "data\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    return Join-Path $logDir "app.log"
}

function Write-AppLog {
    [CmdletBinding()]
    param(
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level = "INFO",
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [System.Exception]$Exception = $null
    )
    $logFile = Get-LogFilePath

    # Rotation: if log file > 1MB, rename to app.log.old
    try {
        if ((Test-Path $logFile) -and (Get-Item $logFile).Length -gt 1MB) {
            $oldFile = Join-Path (Split-Path -Parent $logFile) "app.log.old"
            Move-Item -Path $logFile -Destination $oldFile -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logLine = "$timestamp [$Level] $Message"
    if ($null -ne $Exception) {
        $logLine += "`nException: $($Exception.GetType().FullName): $($Exception.Message)"
        if ($Exception.StackTrace) {
            $logLine += "`nStackTrace:`n$($Exception.StackTrace)"
        }
    }

    Add-Content -Path $logFile -Value $logLine -Encoding UTF8
}

Export-ModuleMember -Function Write-AppLog, Get-LogFilePath
