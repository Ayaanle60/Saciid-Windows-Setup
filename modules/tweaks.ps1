# ==============================================================================
# SACIID WINDOWS SETUP - WINDOWS TWEAKS MODULE
# File: modules/tweaks.ps1
# Description: Applies production-grade registry adjustments and system tweaks:
#              Explorer settings, Dark Mode, High Performance power scheme,
#              disabling Bing search/Tips/Widgets/Chat, and taskbar debloating.
# ==============================================================================

<#
.SYNOPSIS
    Applies all core Windows tweaks and restarts Explorer to reflect changes immediately.
#>
function Invoke-WindowsTweaks {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                          APPLYING WINDOWS SYSTEM TWEAKS                      " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Ensure required registry paths exist
    $pathsToEnsure = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer",
        "HKLM:\SOFTWARE\Policies\Microsoft\Dsh",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat"
    )

    foreach ($path in $pathsToEnsure) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
    }

    $tweaksApplied = 0

    # 1. Show File Extensions
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -Force | Out-Null
        Write-Log -Message "Enabled showing file extensions in File Explorer." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to set HideFileExt: $($_.Exception.Message)" -Level "WARN" }

    # 2. Open Explorer to This PC (LaunchTo = 1)
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Type DWord -Force | Out-Null
        Write-Log -Message "Configured File Explorer to open directly to This PC." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to set LaunchTo: $($_.Exception.Message)" -Level "WARN" }

    # 3. Disable Windows Tips & Spotlight recommendations
    try {
        $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        $tipPolicies = @(
            "SubscribedContent-338389Enabled", "SubscribedContent-310093Enabled",
            "SubscribedContent-338388Enabled", "SubscribedContent-353698Enabled",
            "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled",
            "SoftLandingEnabled", "SystemPaneSuggestionsEnabled"
        )
        foreach ($policy in $tipPolicies) {
            Set-ItemProperty -Path $cdmPath -Name $policy -Value 0 -Type DWord -Force | Out-Null
        }
        Write-Log -Message "Disabled Windows tips, suggestions, and lockscreen spotlight ads." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to disable Windows tips: $($_.Exception.Message)" -Level "WARN" }

    # 4. Disable Bing Start Search & Cortana Consent
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force | Out-Null
        Write-Log -Message "Disabled web suggestions and Bing Start Menu search integration." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to disable Bing Start Search: $($_.Exception.Message)" -Level "WARN" }

    # 5. Remove Widgets (Windows 11 News & Interests)
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force | Out-Null
        Write-Log -Message "Removed Taskbar Widgets and disabled News & Interests integration." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to remove Widgets: $($_.Exception.Message)" -Level "WARN" }

    # 6. Remove Chat Icon (Windows 11 Teams Chat)
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" -Name "ChatIcon" -Value 3 -Type DWord -Force | Out-Null
        Write-Log -Message "Removed Windows 11 Taskbar Chat icon." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to remove Chat icon: $($_.Exception.Message)" -Level "WARN" }

    # 7. Enable High Performance Power Plan
    try {
        $powerProc = [System.Diagnostics.Process]::Start("powercfg.exe", "-setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c")
        $powerProc.WaitForExit()
        if ($powerProc.ExitCode -eq 0) {
            Write-Log -Message "Activated High Performance system power scheme." -Level "SUCCESS"
            $tweaksApplied++
        }
        else {
            Write-Log -Message "Powercfg returned non-zero exit code when setting High Performance scheme." -Level "WARN"
        }
    } catch { Write-Log -Message "Failed to set High Performance power plan: $($_.Exception.Message)" -Level "WARN" }

    # 8. Enable Dark Mode (Apps & System)
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUseLightTheme" -Value 0 -Type DWord -Force | Out-Null
        Write-Log -Message "Enabled Dark Mode for Windows apps and system theme." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to enable Dark Mode: $($_.Exception.Message)" -Level "WARN" }

    # 9. Remove Unnecessary Taskbar Clutter (Search Box -> Icon only, Hide TaskView)
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force | Out-Null
        Write-Log -Message "Cleaned taskbar clutter (minimized Search box and hid Task View button)." -Level "SUCCESS"
        $tweaksApplied++
    } catch { Write-Log -Message "Failed to clean taskbar clutter: $($_.Exception.Message)" -Level "WARN" }

    # Restart Explorer to apply visual changes cleanly
    Write-Log -Message "Restarting File Explorer to apply visual registry changes..." -Level "INFO"
    try {
        Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Log -Message "File Explorer restarted successfully." -Level "SUCCESS"
    }
    catch {
        Write-Log -Message "Could not restart File Explorer automatically: $($_.Exception.Message)" -Level "WARN"
    }

    Add-ResultEntry -Name "Windows System Tweaks" -Status "Installed" -Message "Applied $tweaksApplied system and registry customizations."
}
