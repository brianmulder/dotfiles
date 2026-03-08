$profileRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$profileScripts = Join-Path $profileRoot 'profile.d'

if (Test-Path -LiteralPath $profileScripts) {
    Get-ChildItem -LiteralPath $profileScripts -Filter '*.ps1' -File |
        Sort-Object -Property Name |
        ForEach-Object {
            try {
                . $_.FullName
            }
            catch {
                Write-Warning ("Failed to load profile script {0}: {1}" -f $_.Name, $_.Exception.Message)
            }
        }
}

if (Get-Command -Name starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (& starship init powershell)
}
