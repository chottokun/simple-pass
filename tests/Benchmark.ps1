# Benchmark.ps1
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $currentDir) { $currentDir = Get-Location }
$srcDir = Join-Path (Split-Path -Parent $currentDir) "src"
Import-Module (Join-Path $srcDir "VaultModule.psm1") -DisableNameChecking -Force

# Generate 10000 dummy entries
Write-Host "Generating 10,000 entries..."
$entries = [System.Collections.Generic.List[Object]]::new()
for ($i = 0; $i -lt 10000; $i++) {
    $entries.Add([PSCustomObject]@{
        id       = $i.ToString()
        title    = "Title $i"
        url      = "https://example.com/$i"
        username = "user$i"
        password = "password$i"
        note     = "note $i"
    })
}

$tempFile = [System.IO.Path]::GetTempFileName() + ".csv"

Write-Host "Running Export-VaultToCsv benchmark..."
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Export-VaultToCsv -Entries @($entries.ToArray()) -Path $tempFile
$stopwatch.Stop()

Write-Host "Time elapsed: $($stopwatch.ElapsedMilliseconds) ms"

if (Test-Path $tempFile) {
    Remove-Item $tempFile -Force
}
