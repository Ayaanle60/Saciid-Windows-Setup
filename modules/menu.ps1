# ==============================================================================
# SACIID WINDOWS SETUP - INTERACTIVE MENU MODULE
# File: modules/menu.ps1
# Description: Displays the main ASCII numbered menu, supports multiple
#              comma-separated selections, and dispatches actions to modules.
# ==============================================================================

<#
.SYNOPSIS
    Renders the interactive text menu and routes user selections to modules.
#>
function Show-Menu {
    [CmdletBinding()]
    param ()

    while ($true) {
        Clear-Host
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "                              SACIID WINDOWS SETUP                            " -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1. Install Everything" -ForegroundColor Yellow
        Write-Host "  2. AnyDesk" -ForegroundColor White
        Write-Host "  3. WinRAR" -ForegroundColor White
        Write-Host "  4. Microsoft 365" -ForegroundColor White
        Write-Host "  5. Google Chrome" -ForegroundColor White
        Write-Host "  6. VLC" -ForegroundColor White
        Write-Host "  7. Browser Extensions" -ForegroundColor White
        Write-Host "  8. Windows Tweaks" -ForegroundColor White
        Write-Host "  9. LTSC Apps" -ForegroundColor White
        Write-Host " 10. Winget Repair" -ForegroundColor White
        Write-Host " 11. Exit" -ForegroundColor Red
        Write-Host ""
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " Enter your selection(s) separated by commas (e.g., 1,4,7 or 2,5,8)" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""

        $inputString = Read-Host " Selection"
        if (-not $inputString -or $inputString.Trim() -eq "") {
            continue
        }

        # Parse selections
        $rawChoices = $inputString.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        $choices = [System.Collections.Generic.List[int]]::new()

        foreach ($item in $rawChoices) {
            if ($item -match '^\d+$') {
                $num = [int]$item
                if ($num -ge 1 -and $num -le 11 -and -not $choices.Contains($num)) {
                    $choices.Add($num)
                }
            }
        }

        if ($choices.Count -eq 0) {
            Write-Host " [!] Invalid selection ($inputString). Please enter numbers between 1 and 11." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            continue
        }

        # Handle Exit choice immediately if it's the only choice or chosen
        if ($choices.Contains(11)) {
            Write-Host " Exiting Saciid Windows Setup..." -ForegroundColor Cyan
            break
        }

        # Clear tracking collections for new execution batch
        $global:InstalledApps.Clear()
        $global:SkippedApps.Clear()
        $global:FailedApps.Clear()

        # If option 1 (Install Everything) is selected, expand to all tasks
        if ($choices.Contains(1)) {
            Write-Log -Message "Option 1 selected: Executing complete deployment pipeline..." -Level "INFO"
            $choices = [System.Collections.Generic.List[int]]::new()
            # Sequence: AnyDesk(2), WinRAR(3), Office(4), Chrome(5), VLC(6), Extensions(7), Tweaks(8), LTSC(9), Winget(10)
            foreach ($i in 2..10) { $choices.Add($i) }
        }

        # Sort options sequentially for orderly execution
        $sortedChoices = $choices | Sort-Object

        foreach ($option in $sortedChoices) {
            switch ($option) {
                2  { Install-AnyDesk }
                3  { Install-WinRAR }
                4  { Install-Microsoft365 }
                5  { Install-GoogleChrome }
                6  { Install-VLC }
                7  { Configure-Browsers }
                8  { Invoke-WindowsTweaks }
                9  { Install-LtscApps }
                10 { Repair-WingetSystem }
            }
        }

        # Perform cleanup and display report
        Remove-TempFiles
        Show-FinalReport

        Write-Host ""
        $returnMenu = Read-Host "Press [Enter] to return to the main menu, or type 'Q' to quit"
        if ($returnMenu -match '^[Qq]$') {
            break
        }
    }
}
