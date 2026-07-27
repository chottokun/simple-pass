$moduleDir = $PSScriptRoot
if (-not $moduleDir) { $moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($moduleDir) {
    Import-Module (Join-Path $moduleDir "CryptoModule.psm1") -DisableNameChecking -Force
    Import-Module (Join-Path $moduleDir "LoggerModule.psm1") -DisableNameChecking -Force
}


function Get-DefaultVaultPath {
    $scriptDir = Split-Path -Parent $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = Get-Location
    }
    $dir = Join-Path $scriptDir "data"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return Join-Path $dir "vault.json"
}

function Test-VaultExists {
    [CmdletBinding()]
    param([string]$Path = (Get-DefaultVaultPath))
    return Test-Path $Path
}

function Save-Vault {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$Entries = @(),
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword,
        [string]$Path = (Get-DefaultVaultPath)
    )
    if ($null -eq $Entries -or $Entries.Count -eq 0) {
        $jsonText = "[]"
    } else {
        $jsonText = $Entries | ConvertTo-Json -Depth 5 -Compress
        if (-not $jsonText -or $jsonText -eq "null") {
            $jsonText = "[]"
        }
    }
    $vaultData = ConvertTo-EncryptedVaultData -JsonText $jsonText -MasterPassword $MasterPassword
    $vaultJson = $vaultData | ConvertTo-Json -Depth 3
    
    $parentDir = Split-Path -Parent $Path
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # Automatic Multi-generation Backup (.bak) of existing vault file before overwriting
    if (Test-Path $Path) {
        try {
            $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss_fff")
            $bakPath = "$Path.$timestamp.bak"
            Copy-Item -Path $Path -Destination $bakPath -Force -ErrorAction SilentlyContinue

            # Maintain maximum 5 generations of backups, cleanup older ones
            $dirName = Split-Path -Parent $Path
            $fileName = Split-Path -Leaf $Path
            $oldBackups = Get-ChildItem -Path $dirName -Filter "$fileName.*.bak" | Sort-Object LastWriteTime -Descending
            if ($oldBackups -and $oldBackups.Count -gt 5) {
                $oldBackups | Select-Object -Skip 5 | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-AppLog -Level WARN -Message "Vault backup copy failed: $($_.Exception.Message)"
        }
    }

    [System.IO.File]::WriteAllText($Path, $vaultJson, [System.Text.UTF8Encoding]::new($false))
}

function Load-Vault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$MasterPassword,
        [string]$Path = (Get-DefaultVaultPath)
    )
    if (-not (Test-Path $Path)) {
        throw "Vault file does not exist at path: $Path"
    }

    $rawJson = Get-Content -Path $Path -Raw -Encoding UTF8
    $vaultObj = $rawJson | ConvertFrom-Json
    
    $hashtable = @{
        version  = $vaultObj.version
        salt     = $vaultObj.salt
        data     = $vaultObj.data
        hmac     = $vaultObj.hmac
        useDpapi = $vaultObj.useDpapi
    }

    $jsonText = ConvertFrom-EncryptedVaultData -VaultHashtable $hashtable -MasterPassword $MasterPassword
    if ([string]::IsNullOrWhiteSpace($jsonText) -or $jsonText -eq "[]") {
        return @()
    }

    $entries = $jsonText | ConvertFrom-Json
    if ($entries -isnot [array]) {
        $entries = @($entries)
    }
    return $entries
}

<#
.SYNOPSIS
    Formats and auto-completes URL with http/https scheme, rejecting unsafe protocols.
#>
function Format-VaultUrl {
    [CmdletBinding()]
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) {
        return ""
    }
    $trimmed = $Url.Trim()

    # Reject inherently unsafe / dangerous pseudo-protocols and unsafe characters
    if ($trimmed -match "^(javascript|file|data|vbscript|cmd|powershell|ms-settings|about):" -or $trimmed -match "^\s*\\\\" -or $trimmed -match '[\s"`]') {
        return ""
    }

    if ($trimmed -match "^https?://") {
        return $trimmed
    }

    # If contains another scheme like ftp:// or mailto:, reject unless it is http/https
    if ($trimmed -match "^[a-zA-Z0-9\+\.\-]+://") {
        return ""
    }

    return "https://$trimmed"
}

<#
.SYNOPSIS
    Moves a vault entry up by 1 position in the array.
#>
function Move-VaultEntryUp {
    [CmdletBinding()]
    param(
        [array]$Entries = @(),
        [Parameter(Mandatory=$true)]
        [string]$TargetId
    )
    $list = [System.Collections.Generic.List[Object]]::new([object[]]$Entries)

    $index = -1
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ($list[$i].id -eq $TargetId) {
            $index = $i
            break
        }
    }

    if ($index -gt 0) {
        $temp = $list[$index]
        $list[$index] = $list[$index - 1]
        $list[$index - 1] = $temp
    }

    return @($list.ToArray())
}

<#
.SYNOPSIS
    Moves a vault entry to the top (index 0) of the array.
#>
function Move-VaultEntryToTop {
    [CmdletBinding()]
    param(
        [array]$Entries = @(),
        [Parameter(Mandatory=$true)]
        [string]$TargetId
    )
    $list = [System.Collections.Generic.List[Object]]::new()
    $targetObj = $null

    foreach ($e in $Entries) {
        if ($e.id -eq $TargetId) {
            $targetObj = $e
        } else {
            $list.Add($e)
        }
    }

    if ($targetObj) {
        $list.Insert(0, $targetObj)
    }

    return @($list.ToArray())
}

<#
.SYNOPSIS
    Moves a vault entry down by 1 position in the array.
#>
function Move-VaultEntryDown {
    [CmdletBinding()]
    param(
        [array]$Entries = @(),
        [Parameter(Mandatory=$true)]
        [string]$TargetId
    )
    $list = [System.Collections.Generic.List[Object]]::new([object[]]$Entries)

    $index = -1
    for ($i = 0; $i -lt $list.Count; $i++) {
        if ($list[$i].id -eq $TargetId) {
            $index = $i
            break
        }
    }

    if ($index -ge 0 -and $index -lt ($list.Count - 1)) {
        $temp = $list[$index]
        $list[$index] = $list[$index + 1]
        $list[$index + 1] = $temp
    }

    return @($list.ToArray())
}

<#
.SYNOPSIS
    Creates a new vault entry object.
#>
function New-VaultEntry {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '')]
    param(
        [string]$Title = "",
        [string]$Url = "",
        [string]$Username = "",
        [string]$Password = "",
        [string]$Note = ""
    )
    $formattedUrl = Format-VaultUrl -Url $Url
    return [PSCustomObject]@{
        id        = [guid]::NewGuid().ToString()
        title     = $Title
        url       = $formattedUrl
        username  = $Username
        password  = $Password
        note      = $Note
        updatedAt = (Get-Date).ToString("o")
    }
}

function Get-ObjectPropertyValue {
    param($obj, [string]$propName)
    if ($null -eq $obj) { return "" }
    # Utilizing rapid type casting and direct dot property access for maximum speed
    return [string]$obj.$propName
}

function Search-VaultEntries {
    [CmdletBinding()]
    param(
        [array]$Entries,
        [string]$Keyword
    )
    if ([string]::IsNullOrWhiteSpace($Keyword)) {
        return @($Entries)
    }
    $kw = $Keyword.ToLower()
    $matchedList = [System.Collections.Generic.List[Object]]::new()
    foreach ($entry in $Entries) {
        $t  = ([string]$entry.title).ToLower()
        $u  = ([string]$entry.url).ToLower()
        $un = ([string]$entry.username).ToLower()
        $n  = ([string]$entry.note).ToLower()

        if ($t.Contains($kw) -or $u.Contains($kw) -or $un.Contains($kw) -or $n.Contains($kw)) {
            $matchedList.Add($entry)
        }
    }
    return @($matchedList.ToArray())
}

<#
.SYNOPSIS
    Exports vault password entries to a CSV file.
#>
function Export-VaultToCsv {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '')]
    param(
        [AllowEmptyCollection()]
        [array]$Entries = @(),
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    if ($null -eq $Entries) {
        $Entries = @()
    }

    $exportObjects = [System.Collections.Generic.List[Object]]::new()
    foreach ($entry in $Entries) {
        $exportObjects.Add([PSCustomObject]@{
            Title    = [string]$entry.title
            URL      = [string]$entry.url
            Username = [string]$entry.username
            Password = [string]$entry.password
            Note     = [string]$entry.note
        })
    }

    $parentDir = Split-Path -Parent $Path
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $exportObjects | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Force
}

Export-ModuleMember -Function Get-DefaultVaultPath, Test-VaultExists, Save-Vault, Load-Vault, New-VaultEntry, Search-VaultEntries, Export-VaultToCsv, Format-VaultUrl, Move-VaultEntryUp, Move-VaultEntryDown, Move-VaultEntryToTop, Get-ObjectPropertyValue
