[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:OkCount = 0
$script:WarnCount = 0
$script:FailCount = 0

function Add-Ok {
    param([Parameter(Mandatory)][string]$Message)
    $script:OkCount += 1
    Write-Host ("OK   {0}" -f $Message)
}

function Add-Warn {
    param([Parameter(Mandatory)][string]$Message)
    $script:WarnCount += 1
    Write-Host ("WARN {0}" -f $Message)
}

function Add-Fail {
    param([Parameter(Mandatory)][string]$Message)
    $script:FailCount += 1
    Write-Host ("FAIL {0}" -f $Message)
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host ("== {0} ==" -f $Title)
}

function Get-AbsolutePath {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Path]::GetFullPath($Path)
}

function Get-WhereResults {
    param([Parameter(Mandatory)][string]$Name)

    $results = @(& where.exe $Name 2>$null)
    if ($LASTEXITCODE -eq 0) {
        return $results
    }

    return @()
}

function Show-CommandAudit {
    param([Parameter(Mandatory)][string]$Name)

    $whereResults = @(Get-WhereResults -Name $Name)
    if ($whereResults.Count -gt 0) {
        Add-Ok ("where.exe {0}" -f $Name)
        $whereResults | ForEach-Object { Write-Host ("  {0}" -f $_) }
    }
    else {
        Add-Warn ("where.exe {0}: no matches" -f $Name)
    }

    $commandResults = @(Get-Command -Name $Name -All -ErrorAction SilentlyContinue)
    if ($commandResults.Count -gt 0) {
        Add-Ok ("Get-Command {0}" -f $Name)
        foreach ($command in $commandResults) {
            $path = if ($command.Path) { $command.Path } elseif ($command.Source) { $command.Source } else { '<no path>' }
            Write-Host ("  {0,-16} {1}" -f $command.CommandType, $path)
        }
    }
    else {
        Add-Warn ("Get-Command {0}: no matches" -f $Name)
    }

    $windowsAppsHits = @($whereResults | Where-Object { $_ -match '\\WindowsApps\\' })
    if ($windowsAppsHits.Count -gt 0) {
        if ($whereResults[0] -match '\\WindowsApps\\') {
            Add-Warn ("{0}: WindowsApps is first in PATH resolution ({1})" -f $Name, $whereResults[0])
        }
        else {
            Add-Warn ("{0}: WindowsApps shim also exists ({1})" -f $Name, ($windowsAppsHits -join ', '))
        }
    }

    if ($Name -eq 'codex' -and $whereResults.Count -gt 0) {
        $expectedCodexPrefix = Join-Path $env:APPDATA 'npm\codex'
        if ($whereResults[0] -like "$expectedCodexPrefix*") {
            Add-Ok ("codex resolves from %APPDATA%\\npm ({0})" -f $whereResults[0])
        }
        else {
            Add-Warn ("codex should prefer %APPDATA%\\npm\\codex, but first match is {0}" -f $whereResults[0])
        }
    }

    return [pscustomobject]@{
        Name         = $Name
        WhereResults = $whereResults
        Commands     = $commandResults
    }
}

function Get-PythonProbe {
    param([Parameter(Mandatory)][string]$Launcher)

    $probe = 'import sys; print(sys.executable); print(sys.version.split()[0])'
    try {
        $output = @(& $Launcher -c $probe 2>$null)
    }
    catch {
        return $null
    }

    if ($LASTEXITCODE -ne 0 -or $output.Count -lt 2) {
        return $null
    }

    return [pscustomobject]@{
        Launcher   = $Launcher
        Executable = $output[0]
        Version    = $output[1]
    }
}

function Get-PipVersionLine {
    param([Parameter(Mandatory)][string[]]$Command)

    try {
        if ($Command.Count -eq 1) {
            $output = @(& $Command[0] 2>$null)
        }
        else {
            $arguments = $Command[1..($Command.Count - 1)]
            $output = @(& $Command[0] $arguments 2>$null)
        }
    }
    catch {
        return $null
    }

    if ($LASTEXITCODE -ne 0 -or $output.Count -eq 0) {
        return $null
    }

    return $output[0]
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Write-Section 'Repo'
if (Test-Path -LiteralPath (Join-Path $repoRoot '.git')) {
    Add-Ok ("repo: {0}" -f $repoRoot)
}
else {
    Add-Fail ("repo: missing .git at {0}" -f $repoRoot)
}

Write-Section 'Command resolution'
foreach ($name in 'node', 'npm', 'codex', 'python', 'pip', 'py') {
    Write-Host ("-- {0} --" -f $name)
    Show-CommandAudit -Name $name | Out-Null
    Write-Host ''
}

Write-Section 'PATH order'
$pathEntries = @($env:PATH -split ';' | Where-Object { $_ })
$appDataNpm = Join-Path $env:APPDATA 'npm'
$windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
$npmIndex = [Array]::IndexOf($pathEntries, $appDataNpm)
$windowsAppsIndex = [Array]::IndexOf($pathEntries, $windowsApps)

if ($npmIndex -ge 0) {
    Add-Ok ("%APPDATA%\\npm is on PATH at index {0}" -f $npmIndex)
}
else {
    Add-Warn '%APPDATA%\npm is not on PATH; npm-installed CLIs like codex may not win resolution'
}

if ($windowsAppsIndex -ge 0) {
    Add-Ok ("WindowsApps is on PATH at index {0}" -f $windowsAppsIndex)
    if ($npmIndex -ge 0 -and $windowsAppsIndex -lt $npmIndex) {
        Add-Warn 'WindowsApps appears before %APPDATA%\npm; App Installer shims can shadow real CLIs'
    }
}

Write-Section 'Python defaults'
$pythonProbe = Get-PythonProbe -Launcher 'python'
$pyProbe = Get-PythonProbe -Launcher 'py'

if ($pythonProbe) {
    Add-Ok ("python -> {0} [{1}]" -f $pythonProbe.Executable, $pythonProbe.Version)
    if ($pythonProbe.Version.StartsWith('3.12.')) {
        Add-Ok 'python default is Python 3.12'
    }
    else {
        Add-Warn ("python default is {0}; expected Python 3.12" -f $pythonProbe.Version)
    }
}
else {
    Add-Warn 'python probe failed'
}

if ($pyProbe) {
    Add-Ok ("py -> {0} [{1}]" -f $pyProbe.Executable, $pyProbe.Version)
}
else {
    Add-Warn 'py probe failed'
}

if ($pythonProbe -and $pyProbe) {
    if ((Get-AbsolutePath $pythonProbe.Executable) -eq (Get-AbsolutePath $pyProbe.Executable) -and $pythonProbe.Version -eq $pyProbe.Version) {
        Add-Ok 'python and py agree on the default interpreter'
    }
    else {
        Add-Warn ("python and py disagree: python={0} ({1}), py={2} ({3})" -f $pythonProbe.Executable, $pythonProbe.Version, $pyProbe.Executable, $pyProbe.Version)
    }
}

$pipLine = Get-PipVersionLine -Command @('pip', '--version')
if ($pipLine) {
    Add-Ok ("pip -> {0}" -f $pipLine)
    if ($pipLine -match '\(python (?<Version>[^)]+)\)') {
        $pipPythonVersion = $Matches.Version
        if ($pipPythonVersion.StartsWith('3.12')) {
            Add-Ok 'pip default targets Python 3.12'
        }
        else {
            Add-Warn ("pip default targets Python {0}; expected Python 3.12" -f $pipPythonVersion)
        }
    }
}
else {
    Add-Warn 'pip probe failed'
}

$pythonModulePipLine = Get-PipVersionLine -Command @('python', '-m', 'pip', '--version')
if ($pythonModulePipLine) {
    Add-Ok ("python -m pip -> {0}" -f $pythonModulePipLine)
    if ($pipLine -and $pipLine -ne $pythonModulePipLine) {
        Add-Warn 'pip and python -m pip report different targets; prefer python -m pip'
    }
}
else {
    Add-Warn 'python -m pip probe failed'
}

Write-Section 'Conda'
$condaPaths = @($pathEntries | Where-Object { $_ -match '(?i)(miniconda|anaconda|condabin|\\conda\\)' })
if ($condaPaths.Count -gt 0) {
    Add-Warn 'Conda-related paths are present on PATH'
    $condaPaths | ForEach-Object { Write-Host ("  {0}" -f $_) }
}
else {
    Add-Ok 'No Conda-related PATH entries detected'
}

if ($env:CONDA_PREFIX -or $env:CONDA_DEFAULT_ENV) {
    Add-Warn ("Conda appears active (CONDA_PREFIX={0}; CONDA_DEFAULT_ENV={1})" -f $env:CONDA_PREFIX, $env:CONDA_DEFAULT_ENV)
}
else {
    Add-Ok 'No active Conda environment detected'
}

Write-Host ''
Write-Host ("Summary: {0} ok, {1} warn, {2} fail" -f $script:OkCount, $script:WarnCount, $script:FailCount)
if ($script:FailCount -gt 0) {
    exit 1
}
