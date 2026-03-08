$userHome = [Environment]::GetFolderPath('UserProfile')

$defaults = [ordered]@{
    XDG_CONFIG_HOME = Join-Path $userHome '.config'
    XDG_DATA_HOME   = Join-Path $userHome '.local\share'
    XDG_STATE_HOME  = Join-Path $userHome '.local\state'
}

foreach ($entry in $defaults.GetEnumerator()) {
    if (-not [Environment]::GetEnvironmentVariable($entry.Key, 'Process')) {
        Set-Item -Path ("Env:{0}" -f $entry.Key) -Value $entry.Value
    }
}

$starshipConfig = Join-Path $env:XDG_CONFIG_HOME 'starship.toml'
if ((Test-Path -LiteralPath $starshipConfig) -and -not [Environment]::GetEnvironmentVariable('STARSHIP_CONFIG', 'Process')) {
    Set-Item -Path Env:STARSHIP_CONFIG -Value $starshipConfig
}

if (-not [Environment]::GetEnvironmentVariable('EDITOR', 'Process') -and (Get-Command -Name nvim -ErrorAction SilentlyContinue)) {
    Set-Item -Path Env:EDITOR -Value 'nvim'
}
