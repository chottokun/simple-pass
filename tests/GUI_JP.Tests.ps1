# GUI_JP.Tests.ps1 - Japanese Edition XAML & Interface Test Suite

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw "ASSERTION FAILED: $message"
    }
}

function Run-GuiJpTests {
    $currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $currentDir) { $currentDir = Get-Location }
    $srcDir = Join-Path (Split-Path -Parent $currentDir) "src"

    $results = @{ Passed = 0; Failed = 0; Log = @() }

    # Test 1: SimplePASS_JP.ps1 XAML Parsing & Control Binding
    try {
        $jpScript = Join-Path $srcDir "SimplePASS_JP.ps1"
        Assert-True (Test-Path $jpScript) "SimplePASS_JP.ps1 exists"

        $scriptContent = [System.IO.File]::ReadAllText($jpScript, [System.Text.Encoding]::UTF8)
        $xamlMatch = [regex]::Match($scriptContent, '(?s)\[xml\]\$xaml\s*=\s*@"(.*?)"@')
        Assert-True $xamlMatch.Success "XAML string extracted from SimplePASS_JP.ps1"

        $xamlStr = $xamlMatch.Groups[1].Value
        [xml]$xmlObj = $xamlStr
        $reader = (New-Object System.Xml.XmlNodeReader $xmlObj)
        $windowObj = [Windows.Markup.XamlReader]::Load($reader)

        Assert-True ($null -ne $windowObj) "SimplePASS_JP XAML loaded without XamlParseException"
        Assert-True ($windowObj.Title.StartsWith("SimplePASS")) "Japanese Window Title loaded"
        Assert-True ($null -ne $windowObj.FindName("LoginPanel")) "LoginPanel found in JP edition"
        Assert-True ($null -ne $windowObj.FindName("DgEntries")) "DgEntries found in JP edition"

        $results.Passed++
        $results.Log += "[PASS] Test 1: SimplePASS_JP.ps1 XAML Parsing & Japanese Controls Binding"
    } catch {
        $results.Failed++
        $results.Log += "[FAIL] Test 1: SimplePASS_JP.ps1 XAML Parsing - $_"
    }

    return $results
}

if ($MyInvocation.InvocationName -ne '.') {
    Run-GuiJpTests
}
