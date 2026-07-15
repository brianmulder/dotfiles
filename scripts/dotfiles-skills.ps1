[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoScript = Join-Path $PSScriptRoot 'dotfiles-skills.py'
$installedScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'libexec\dotfiles-skills.py'
$script = if (Test-Path -LiteralPath $repoScript) { $repoScript } else { $installedScript }

if (-not (Test-Path -LiteralPath $script)) {
    throw "dotfiles-skills.py was not found beside this wrapper or under ~/.local/libexec"
}

& python $script @RemainingArgs
exit $LASTEXITCODE
