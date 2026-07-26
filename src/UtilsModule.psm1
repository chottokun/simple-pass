Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Windows.Forms

function Get-SecureRandomInt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Max
    )

    if ($Max -le 0) {
        throw "Max must be greater than 0."
    }

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = [byte[]]::new(4)
        $limit = [uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$Max)

        while ($true) {
            $rng.GetBytes($bytes)
            $val = [BitConverter]::ToUInt32($bytes, 0)
            if ($val -lt $limit) {
                return [int]($val % [uint32]$Max)
            }
        }
    } finally {
        $rng.Dispose()
    }
}

function New-RandomPassword {
    [CmdletBinding()]
    param(
        [int]$Length = 16,
        [switch]$IncludeUppercase = $true,
        [switch]$IncludeLowercase = $true,
        [switch]$IncludeNumbers = $true,
        [switch]$IncludeSymbols = $true
    )

    $upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lower = "abcdefghijklmnopqrstuvwxyz"
    $digits = "0123456789"
    $symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"

    $charPool = ""
    $mandatoryChars = [System.Collections.Generic.List[char]]::new()

    function Get-RandomCharFrom([string]$source) {
        $index = Get-SecureRandomInt -Max $source.Length
        return $source[$index]
    }

    if ($IncludeUppercase) {
        $charPool += $upper
        $mandatoryChars.Add((Get-RandomCharFrom $upper))
    }
    if ($IncludeLowercase) {
        $charPool += $lower
        $mandatoryChars.Add((Get-RandomCharFrom $lower))
    }
    if ($IncludeNumbers) {
        $charPool += $digits
        $mandatoryChars.Add((Get-RandomCharFrom $digits))
    }
    if ($IncludeSymbols) {
        $charPool += $symbols
        $mandatoryChars.Add((Get-RandomCharFrom $symbols))
    }

    if ([string]::IsNullOrEmpty($charPool)) {
        throw "At least one character set must be selected."
    }

    $passChars = [System.Collections.Generic.List[char]]::new()
    foreach ($c in $mandatoryChars) {
        $passChars.Add($c)
    }

    while ($passChars.Count -lt $Length) {
        $passChars.Add((Get-RandomCharFrom $charPool))
    }

    # Fisher-Yates shuffle
    for ($i = $passChars.Count - 1; $i -gt 0; $i--) {
        $j = Get-SecureRandomInt -Max ($i + 1)
        $temp = $passChars[$i]
        $passChars[$i] = $passChars[$j]
        $passChars[$j] = $temp
    }

    return -join $passChars
}

function Set-ClipboardWithAutoClear {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        [int]$ClearAfterSeconds = 30
    )
    
    # Try WPF Clipboard first, fallback to Windows Forms with retry resilience for transient lock handling
    $setSuccess = $false
    for ($retry = 0; $retry -lt 3; $retry++) {
        try {
            [System.Windows.Clipboard]::SetText($Text)
            $setSuccess = $true
            break
        } catch {
            try {
                [System.Windows.Forms.Clipboard]::SetText($Text)
                $setSuccess = $true
                break
            } catch {
                Start-Sleep -Milliseconds 50
            }
        }
    }

    if ($ClearAfterSeconds -gt 0 -and $setSuccess) {
        $clearScript = {
            param([string]$copiedText, [int]$delaySec)
            Start-Sleep -Seconds $delaySec
            Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            try {
                if ([System.Windows.Clipboard]::GetText() -eq $copiedText) {
                    [System.Windows.Clipboard]::Clear()
                }
            } catch {
                try {
                    if ([System.Windows.Forms.Clipboard]::GetText() -eq $copiedText) {
                        [System.Windows.Forms.Clipboard]::Clear()
                    }
                } catch {}
            }
        }

        # Use an asynchronous STA background runspace and PowerShell instance to correctly run WPF clipboard functions
        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = "STA"
        $rs.ThreadOptions = "UseNewThread"
        $rs.Open()

        $p = [powershell]::Create()
        $p.Runspace = $rs
        [void]$p.AddScript($clearScript)
        [void]$p.AddArgument($Text)
        [void]$p.AddArgument($ClearAfterSeconds)

        $callback = [AsyncCallback]{
            param($ar)
            $stateObj = $ar.AsyncState
            $p_inst = $stateObj.PowerShell
            $rs_inst = $stateObj.Runspace
            try {
                $null = $p_inst.EndInvoke($ar)
            } catch {}
            try { $p_inst.Dispose() } catch {}
            try { $rs_inst.Close() } catch {}
            try { $rs_inst.Dispose() } catch {}
        }

        $stateObj = [PSCustomObject]@{ PowerShell = $p; Runspace = $rs }
        [void]$p.BeginInvoke([System.Management.Automation.PSDataCollection[System.Management.Automation.PSObject]]::new(), [System.Management.Automation.PSInvocationSettings]::new(), $callback, $stateObj)
    }

    return $setSuccess
}

Export-ModuleMember -Function New-RandomPassword, Set-ClipboardWithAutoClear, Get-SecureRandomInt
