# BenchmarkSearch.ps1 - Benchmarks the Search-VaultEntries performance improvement

$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) "src\VaultModule.psm1"
Import-Module $modulePath -Force

# 1. Generate large dataset (5,000 entries)
Write-Output "Generating 5,000 mock vault entries..."
$entries = [System.Collections.Generic.List[Object]]::new()
for ($i = 0; $i -lt 5000; $i++) {
    $entries.Add([PSCustomObject]@{
        id       = [guid]::NewGuid().ToString()
        title    = "My Site $i"
        url      = "https://example$i.com"
        username = "user_name_$i"
        note     = "This is some note about site $i"
    })
}
$entriesArray = $entries.ToArray()

# 2. Run benchmark search (1,000 search iterations)
Write-Output "Running search benchmark (1,000 search iterations)..."
$elapsed = Measure-Command {
    for ($j = 0; $j -lt 1000; $j++) {
        # Search for a term that matches some entries and performs ordinal case insensitive searches
        $null = Search-VaultEntries -Entries $entriesArray -Keyword "site 499"
    }
}

Write-Output "Benchmark complete!"
Write-Output "Total time: $($elapsed.TotalMilliseconds) ms"
Write-Output "Average time per search: $($elapsed.TotalMilliseconds / 1000) ms"
