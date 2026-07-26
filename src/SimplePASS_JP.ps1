# SimplePASS - Main GUI Application (Japanese Edition / 日本語版 Wrapper)
# Universal UTF-8 BOM compliance required.
[CmdletBinding()]
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = Get-Location }

# Invoke the unified main script with Japanese language parameter
& (Join-Path $scriptDir "SimplePASS.ps1") -Language "ja"
