function Show-CommandResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string[]]$Name
    )

    process {
        foreach ($commandName in $Name) {
            Write-Output ("== {0} ==" -f $commandName)

            $whereResults = @(& where.exe $commandName 2>$null)
            if ($LASTEXITCODE -eq 0 -and $whereResults.Count -gt 0) {
                Write-Output 'where.exe:'
                $whereResults | ForEach-Object { Write-Output ("  {0}" -f $_) }
            }
            else {
                Write-Output 'where.exe:'
                Write-Output '  <no matches>'
            }

            $commandResults = @(Get-Command -Name $commandName -All -ErrorAction SilentlyContinue)
            if ($commandResults.Count -gt 0) {
                Write-Output 'Get-Command:'
                foreach ($command in $commandResults) {
                    $path = if ($command.Path) { $command.Path } elseif ($command.Source) { $command.Source } else { '<no path>' }
                    Write-Output ("  {0,-16} {1}" -f $command.CommandType, $path)
                }
            }
            else {
                Write-Output 'Get-Command:'
                Write-Output '  <no matches>'
            }

            Write-Output ''
        }
    }
}

Set-Alias -Name whichcmd -Value Show-CommandResolution
