# Vault.Tests.ps1 - Critical Data Persistence & Folder-based Storage Test Suite

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-VaultTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"
    Import-Module (Join-Path $srcDir "CryptoModule.psm1") -DisableNameChecking -Force -Global
    Import-Module (Join-Path $srcDir "VaultModule.psm1") -DisableNameChecking -Force -Global

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Temporary vault file
    $tempFile = [System.IO.Path]::GetTempFileName()
    $masterPass = "TestMasterPassword!2026"

    try {
        # Test 1: Vault Save & Load
        $entry1 = New-VaultEntry -Title "GitHub" -Url "https://github.com" -Username "octocat" -Password "OctoPass123" -Note "Dev Account"
        $entry2 = New-VaultEntry -Title "Google" -Url "https://google.com" -Username "user@gmail.com" -Password "GPass456" -Note "Personal"

        Save-Vault -Entries @($entry1, $entry2) -MasterPassword $masterPass -Path $tempFile

        $loadedEntries = Load-Vault -MasterPassword $masterPass -Path $tempFile
        Assert-True ($loadedEntries.Count -eq 2) "Loaded entry count is 2"
        Assert-True ($loadedEntries[0].title -eq "GitHub") "Entry 1 title matches"
        Assert-True ($loadedEntries[1].password -eq "GPass456") "Entry 2 password matches"

        $results.Passed++
        $results.Log += "[PASS] Test 1: Save & Load Vault data"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: Save & Load Vault data - $_"
    }

    # Test 2: Search functionality
    try {
        $found = @(Search-VaultEntries -Entries $loadedEntries -Keyword "git")
        Assert-True ($found.Count -eq 1) "Keyword 'git' matches exactly 1 entry"
        Assert-True ($found[0].title -eq "GitHub") "Matched entry is GitHub"

        $results.Passed++
        $results.Log += "[PASS] Test 2: Search functionality"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 2: Search functionality - $_"
    }

    # Test 3: Special characters & Symbols
    try {
        $complexPass = 'P@ssw0rd!#%^&*()_+-=[]{}|;:,.<>?'
        $unicodeEntry = New-VaultEntry -Title "Portal" -Url "https://portal.internal" -Username "user_test" -Password $complexPass -Note "Complex Password Test"
        Save-Vault -Entries @($unicodeEntry) -MasterPassword $masterPass -Path $tempFile
        $reloaded = Load-Vault -MasterPassword $masterPass -Path $tempFile

        Assert-True ($reloaded[0].password -eq $complexPass) "Complex special symbols in password correctly preserved"

        $results.Passed++
        $results.Log += "[PASS] Test 3: Special characters & symbol handling"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 3: Special characters handling - $_"
    }

    # Test 4: Dynamic entry addition and deletion
    try {
        $entries = @()
        $e1 = New-VaultEntry -Title "Test1" -Password "P1"
        $e2 = New-VaultEntry -Title "Test2" -Password "P2"

        $entries = @($entries) + $e1
        $entries = @($entries) + $e2
        Assert-True ($entries.Count -eq 2) "Dynamic array addition succeeded"

        $deleteId = $e1.id
        $entries = @($entries | Where-Object { $_.id -ne $deleteId })
        Assert-True ($entries.Count -eq 1) "Dynamic array deletion succeeded"
        Assert-True ($entries[0].title -eq "Test2") "Remaining entry is Test2"

        $results.Passed++
        $results.Log += "[PASS] Test 4: Dynamic entry array manipulation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 4: Dynamic entry array manipulation - $_"
    }

    # Test 5: Critical: Newline, Quotes & JSON-Injection Attack Resistance
    try {
        $trickyNote = 'Line1' + "`r`n" + 'Line2' + "`t" + 'Tabbed "Quoted" {"jsonKey":"jsonValue"}'
        $injectionEntry = New-VaultEntry -Title "Injection<Script>" -Url "http://test.com/'or'1'='1" -Username "user`nname" -Password "P@ss`"word" -Note $trickyNote
        Save-Vault -Entries @($injectionEntry) -MasterPassword $masterPass -Path $tempFile

        $reloadedInj = Load-Vault -MasterPassword $masterPass -Path $tempFile
        Assert-True ($reloadedInj[0].note -eq $trickyNote) "Newlines and JSON injection symbols strictly preserved"
        Assert-True ($reloadedInj[0].url -eq "http://test.com/'or'1'='1") "SQL-like string preserved"

        $results.Passed++
        $results.Log += "[PASS] Test 5: Critical: JSON-injection & control character preservation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 5: Injection resistance - $_"
    }

    # Test 6: Critical: Folder-relative Storage Path Creation Test
    try {
        $defaultPath = Get-DefaultVaultPath
        Assert-True ($defaultPath.Contains("data")) "Default vault path uses folder-relative data directory"

        $dataDir = Split-Path -Parent $defaultPath
        Assert-True (Test-Path $dataDir) "Data directory exists / auto-created"

        $results.Passed++
        $results.Log += "[PASS] Test 6: Critical: Folder-relative storage path resolution"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 6: Folder-relative path resolution - $_"
    }

    # Test 7: Corrupt / Non-JSON file handling
    try {
        $corruptFile = [System.IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $corruptFile -Value "INVALID_NON_JSON_CONTENT_123" -Encoding UTF8
            
            $corruptFailed = $false
            try {
                $dummy = Load-Vault -MasterPassword "Pass123" -Path $corruptFile
            } catch {
                $corruptFailed = $true
            }

            Assert-True $corruptFailed "Corrupt non-JSON file load strictly throws exception"
            $results.Passed++
            $results.Log += "[PASS] Test 7: Corrupt non-JSON file exception handling"
        } finally {
            if (Test-Path $corruptFile) { Remove-Item $corruptFile -Force -ErrorAction SilentlyContinue }
        }
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 7: Corrupt non-JSON file test - $_"
    }

    # Test 8: TDD - Vault CSV Export Functionality
    try {
        $csvFile = [System.IO.Path]::GetTempFileName() + ".csv"
        try {
            $e1 = New-VaultEntry -Title "GitHub" -Url "https://github.com" -Username "octocat" -Password "Secret123!" -Note "Dev"
            $e2 = New-VaultEntry -Title "Google" -Url "https://google.com" -Username "user@gmail.com" -Password "Secret456!" -Note "Personal"

            # Call Export-VaultToCsv
            Export-VaultToCsv -Entries @($e1, $e2) -Path $csvFile

            Assert-True (Test-Path $csvFile) "CSV file exported and created successfully"
            $csvContent = Get-Content -Path $csvFile -Raw -Encoding UTF8
            Assert-True ($csvContent.Contains("GitHub")) "CSV contains Title GitHub"
            Assert-True ($csvContent.Contains("octocat")) "CSV contains Username octocat"
            Assert-True ($csvContent.Contains("Secret123!")) "CSV contains decrypted Password Secret123!"
            Assert-True ($csvContent.Contains("Google")) "CSV contains Title Google"

            $results.Passed++
            $results.Log += "[PASS] Test 8: TDD - Vault CSV Export Functionality"
        } finally {
            if (Test-Path $csvFile) { Remove-Item $csvFile -Force -ErrorAction SilentlyContinue }
        }
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 8: TDD - Vault CSV Export Functionality - $_"
    }

    # Test 9: TDD - URL Scheme Auto-Completion
    try {
        $url1 = Format-VaultUrl -Url "example.com"
        Assert-True ($url1 -eq "https://example.com") "Appends https:// to plain domain"

        $url2 = Format-VaultUrl -Url "http://http-site.org"
        Assert-True ($url2 -eq "http://http-site.org") "Preserves existing http:// scheme"

        $url3 = Format-VaultUrl -Url "https://secure-site.com"
        Assert-True ($url3 -eq "https://secure-site.com") "Preserves existing https:// scheme"

        $results.Passed++
        $results.Log += "[PASS] Test 9: TDD - URL Scheme Auto-Completion"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 9: TDD - URL Scheme Auto-Completion - $_"
    }

    # Test 10: TDD - Entry Custom Order Swap (Up / Down)
    try {
        $e1 = New-VaultEntry -Title "First"
        $e2 = New-VaultEntry -Title "Second"
        $e3 = New-VaultEntry -Title "Third"
        $list = @($e1, $e2, $e3)

        # Move "Second" Up -> Result: Second, First, Third
        $movedUp = Move-VaultEntryUp -Entries $list -TargetId $e2.id
        Assert-True ($movedUp[0].title -eq "Second") "Second moved to index 0 when moved up"
        Assert-True ($movedUp[1].title -eq "First") "First shifted to index 1"

        # Move "First" Down -> Result: Second, Third, First
        $movedDown = Move-VaultEntryDown -Entries $movedUp -TargetId $movedUp[1].id
        Assert-True ($movedDown[2].title -eq "First") "First moved to index 2 when moved down"

        $results.Passed++
        $results.Log += "[PASS] Test 10: TDD - Entry Custom Order Swap"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 10: TDD - Entry Custom Order Swap - $_"
    }

    # Test 11: TDD - URL Protocol Whitelist Security Test
    try {
        $secUrl1 = Format-VaultUrl -Url "javascript:alert(1)"
        Assert-True ($secUrl1 -eq "") "Rejects unsafe javascript: scheme"

        $secUrl2 = Format-VaultUrl -Url "file:///C:/Windows/System32/cmd.exe"
        Assert-True ($secUrl2 -eq "") "Rejects unsafe file:// scheme"

        $secUrl3 = Format-VaultUrl -Url "https://valid-site.com"
        Assert-True ($secUrl3 -eq "https://valid-site.com") "Allows valid https:// scheme"

        # Additional URL injection and unsafe character tests
        $secUrl4 = Format-VaultUrl -Url "https://valid-site.com/search?q=foo bar"
        Assert-True ($secUrl4 -eq "") "Rejects URLs containing whitespace"

        $secUrl5 = Format-VaultUrl -Url "https://valid-site.com/search?q=foo'bar"
        Assert-True ($secUrl5 -eq "https://valid-site.com/search?q=foo'bar") "Allows URLs containing single quote (as per RFC 3986 sub-delims)"

        $secUrl6 = Format-VaultUrl -Url 'https://valid-site.com/search?q=foo"bar'
        Assert-True ($secUrl6 -eq "") "Rejects URLs containing double quote"

        $secUrl7 = Format-VaultUrl -Url 'https://valid-site.com/search?q=foo`bar'
        Assert-True ($secUrl7 -eq "") "Rejects URLs containing backtick"

        $results.Passed++
        $results.Log += "[PASS] Test 11: TDD - URL Protocol Whitelist Security Test"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 11: TDD - URL Protocol Whitelist Security Test - $_"
    }

    # Test 12: TDD - Entry Move To Top (Top Pinning)
    try {
        $e1 = New-VaultEntry -Title "First"
        $e2 = New-VaultEntry -Title "Second"
        $e3 = New-VaultEntry -Title "Third"
        $list = @($e1, $e2, $e3)

        # Move "Third" to Top -> Result: Third, First, Second
        $movedTop = Move-VaultEntryToTop -Entries $list -TargetId $e3.id
        Assert-True ($movedTop[0].title -eq "Third") "Third moved to index 0 (top)"
        Assert-True ($movedTop[1].title -eq "First") "First shifted to index 1"
        Assert-True ($movedTop[2].title -eq "Second") "Second shifted to index 2"

        $results.Passed++
        $results.Log += "[PASS] Test 12: TDD - Entry Move To Top (Top Pinning)"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 12: TDD - Entry Move To Top - $_"
    }

    # Test 13: Test-VaultExists Implementation Tests
    try {
        # 1. Existing file path
        $existingPath = [System.IO.Path]::GetTempFileName()
        try {
            Set-Content -Path $existingPath -Value "dummy content"
            $exists = Test-VaultExists -Path $existingPath
            Assert-True $exists "Test-VaultExists returns true when file exists"
        } finally {
            if (Test-Path $existingPath) { Remove-Item $existingPath -Force -ErrorAction SilentlyContinue }
        }

        # 2. Non-existing file path
        $nonExistingPath = Join-Path ([System.IO.Path]::GetTempPath()) "non_existing_file_$([guid]::NewGuid()).json"
        $exists2 = Test-VaultExists -Path $nonExistingPath
        Assert-True (-not $exists2) "Test-VaultExists returns false when file does not exist"

        # 3. Default path (should match the existence of Get-DefaultVaultPath)
        $defaultPath = Get-DefaultVaultPath
        $defaultExistsExpected = Test-Path $defaultPath
        $defaultExistsActual = Test-VaultExists
        Assert-True ($defaultExistsActual -eq $defaultExistsExpected) "Test-VaultExists with default parameter matches actual existence of default vault path"

        $results.Passed++
        $results.Log += "[PASS] Test 13: Test-VaultExists validation"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 13: Test-VaultExists validation - $_"
    }

    # Test 14: Get-ObjectPropertyValue tests (Coverage Improvement)
    try {
        # 14a: Null object input
        $nullVal = Get-ObjectPropertyValue -obj $null -propName "anyProp"
        Assert-True ($nullVal -eq "") "Null object input returns empty string"

        # 14b: PSCustomObject
        $psObj = [PSCustomObject]@{
            testKey    = "testVal"
            nullKey    = $null
            intKey     = 42
        }
        Assert-True ((Get-ObjectPropertyValue -obj $psObj -propName "testKey") -eq "testVal") "PSCustomObject valid string property"
        Assert-True ((Get-ObjectPropertyValue -obj $psObj -propName "nullKey") -eq "") "PSCustomObject null property value returns empty string"
        Assert-True ((Get-ObjectPropertyValue -obj $psObj -propName "nonExistent") -eq "") "PSCustomObject non-existent property returns empty string"
        Assert-True ((Get-ObjectPropertyValue -obj $psObj -propName "intKey") -eq "42") "PSCustomObject non-string value converted to string"

        # 14c: Hashtable
        $hash = @{
            hashKey   = "hashVal"
            nullKey   = $null
            boolKey   = $true
        }
        Assert-True ((Get-ObjectPropertyValue -obj $hash -propName "hashKey") -eq "hashVal") "Hashtable valid string property"
        Assert-True ((Get-ObjectPropertyValue -obj $hash -propName "nullKey") -eq "") "Hashtable null value returns empty string"
        Assert-True ((Get-ObjectPropertyValue -obj $hash -propName "nonExistent") -eq "") "Hashtable non-existent key returns empty string"
        Assert-True ((Get-ObjectPropertyValue -obj $hash -propName "boolKey") -eq "True") "Hashtable boolean value converted to string"

        # 14d: Standard .NET Object
        $uri = [System.Uri]::new("https://github.com/abc")
        Assert-True ((Get-ObjectPropertyValue -obj $uri -propName "Host") -eq "github.com") "Standard .NET object valid string property"
        Assert-True ((Get-ObjectPropertyValue -obj $uri -propName "NonExistentProp") -eq "") "Standard .NET object non-existent property returns empty string"

        $results.Passed++
        $results.Log += "[PASS] Test 14: Get-ObjectPropertyValue coverage and correctness"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 14: Get-ObjectPropertyValue - $_"
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-VaultTests
}

