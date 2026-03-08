[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$userHome = [Environment]::GetFolderPath('UserProfile')
$configHome = Join-Path $userHome '.config'
$documentsPowerShell = Join-Path $userHome 'Documents\PowerShell'
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')

$script:AppliedCount = 0
$script:SkippedCount = 0

function Write-Info {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ("[info] {0}" -f $Message)
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ("[ok]   {0}" -f $Message)
}

function Write-Warn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ("[warn] {0}" -f $Message)
}

function Get-AbsolutePath {
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Path]::GetFullPath($Path)
}

function Get-LinkTarget {
    param([Parameter(Mandatory)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        return $null
    }

    if (-not ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        return $null
    }

    $target = $item.Target
    if ($null -eq $target) {
        return $null
    }

    if ($target -is [array]) {
        $target = $target[0]
    }

    if (-not [System.IO.Path]::IsPathRooted($target)) {
        $baseDirectory = if ($item.PSIsContainer) {
            $item.FullName
        }
        else {
            Split-Path -Parent $item.FullName
        }
        $target = Join-Path $baseDirectory $target
    }

    return (Get-AbsolutePath $target)
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Create directory')) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Ensure-Link {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    $sourcePath = (Resolve-Path -LiteralPath $Source).Path
    $destinationPath = Get-AbsolutePath $Destination

    Ensure-Directory -Path (Split-Path -Parent $destinationPath)

    $existingItem = Get-Item -LiteralPath $destinationPath -Force -ErrorAction SilentlyContinue
    if ($existingItem) {
        $existingTarget = Get-LinkTarget -Path $destinationPath
        if ($existingTarget -and $existingTarget -eq $sourcePath) {
            Write-Ok ("{0}: {1}" -f $Label, $destinationPath)
            return
        }

        if (-not $Force) {
            $script:SkippedCount += 1
            if ($existingTarget) {
                Write-Warn ("{0}: existing link points elsewhere ({1})" -f $Label, $existingTarget)
            }
            else {
                Write-Warn ("{0}: existing path left in place ({1}); rerun with -Force to replace it" -f $Label, $destinationPath)
            }
            return
        }

        if ($PSCmdlet.ShouldProcess($destinationPath, 'Remove existing path')) {
            Remove-Item -LiteralPath $destinationPath -Recurse -Force
        }
    }

    if ($PSCmdlet.ShouldProcess($destinationPath, ("Link to {0}" -f $sourcePath))) {
        New-Item -ItemType SymbolicLink -Path $destinationPath -Target $sourcePath | Out-Null
        $script:AppliedCount += 1
        Write-Ok ("{0}: {1}" -f $Label, $destinationPath)
    }
}

$powerShellPackage = Join-Path $repoRoot 'powershell\Documents\PowerShell'
$mappings = @(
    @{
        Label = 'PowerShell profile'
        Source = Join-Path $powerShellPackage 'Microsoft.PowerShell_profile.ps1'
        Destination = Join-Path $documentsPowerShell 'Microsoft.PowerShell_profile.ps1'
    }
    @{
        Label = 'PowerShell profile.d'
        Source = Join-Path $powerShellPackage 'profile.d'
        Destination = Join-Path $documentsPowerShell 'profile.d'
    }
    @{
        Label = 'Git config'
        Source = Join-Path $repoRoot 'git\.gitconfig'
        Destination = Join-Path $userHome '.gitconfig'
    }
    @{
        Label = 'Git XDG config'
        Source = Join-Path $repoRoot 'git\.config\git'
        Destination = Join-Path $configHome 'git'
    }
    @{
        Label = 'Neovim config'
        Source = Join-Path $repoRoot 'nvim\.config\nvim'
        Destination = Join-Path $localAppData 'nvim'
    }
    @{
        Label = 'Starship config'
        Source = Join-Path $repoRoot 'shell\.config\starship.toml'
        Destination = Join-Path $configHome 'starship.toml'
    }
)

Write-Info ("Repo root: {0}" -f $repoRoot)
Write-Info 'This script is intentionally narrow. It links the native Windows pieces without trying to rewrite PATH.'

foreach ($mapping in $mappings) {
    Ensure-Link -Label $mapping.Label -Source $mapping.Source -Destination $mapping.Destination
}

Write-Host ''
Write-Host ("Applied: {0}" -f $script:AppliedCount)
Write-Host ("Skipped: {0}" -f $script:SkippedCount)
Write-Host 'Restart PowerShell, Windows Terminal, and editor terminals after PATH changes or new installs.'
