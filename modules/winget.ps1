# ==============================================================================
# SACIID WINDOWS SETUP - WINGET BOOTSTRAP & REPAIR MODULE
# File: modules/winget.ps1
# Description: Detects missing dependencies, broken App Installer, and missing
#              Store packages. Repairs Winget completely from official endpoints.
# ==============================================================================

<#
.SYNOPSIS
    Diagnoses and repairs Windows Package Manager (Winget) and its dependencies.
#>
function Repair-WingetSystem {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                      WINGET BOOTSTRAP & AUTOMATIC REPAIR                     " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Log -Message "Starting Winget health diagnostic and repair routine..." -Level "INFO"

    # 1. Check Winget binary accessibility
    $wingetCmd = Get-Command -Name "winget" -ErrorAction SilentlyContinue
    $localAppPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
    $wingetExeLocal = "$localAppPath\winget.exe"

    if (-not $wingetCmd -and (Test-Path $wingetExeLocal)) {
        Write-Log -Message "Adding WindowsApps directory to current PowerShell PATH environment variable..." -Level "INFO"
        $env:PATH = "$env:PATH;$localAppPath"
        $wingetCmd = Get-Command -Name "winget" -ErrorAction SilentlyContinue
    }

    # 2. Check dependencies and reinstall if missing or broken
    $vclibs = Get-AppxPackage -Name "*Microsoft.VCLibs.140.00.UWPDesktop*" -AllUsers -ErrorAction SilentlyContinue
    $uixaml = Get-AppxPackage -Name "*Microsoft.UI.Xaml*" -AllUsers -ErrorAction SilentlyContinue
    $appInst = Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*" -AllUsers -ErrorAction SilentlyContinue

    $needsBootstrap = $false
    if (-not $vclibs -or -not $uixaml -or -not $appInst -or -not $wingetCmd) {
        Write-Log -Message "Missing or corrupted Winget packages detected. Starting full bootstrap..." -Level "WARN"
        $needsBootstrap = $true
    }
    else {
        Write-Log -Message "Testing Winget CLI functionality..." -Level "INFO"
        try {
            $testOutput = & winget --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log -Message "Winget is functional ($testOutput)." -Level "SUCCESS"
            } else {
                Write-Log -Message "Winget responded with errors. Proceeding with repair..." -Level "WARN"
                $needsBootstrap = $true
            }
        }
        catch {
            $needsBootstrap = $true
        }
    }

    if ($needsBootstrap) {
        # Utilize LTSC offline dependency installer if available
        if (Get-Command -Name "Install-WingetAndDependenciesOffline" -ErrorAction SilentlyContinue) {
            Install-WingetAndDependenciesOffline
        }
        else {
            # Fallback download directly
            $repairDir = "$global:TempDir\WingetRepair"
            if (-not (Test-Path $repairDir)) { New-Item -Path $repairDir -ItemType Directory -Force | Out-Null }

            Write-Log -Message "Downloading latest Microsoft.DesktopAppInstaller bundle from GitHub..." -Level "INFO"
            $bundleUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            $bundlePath = "$repairDir\DesktopAppInstaller.msixbundle"

            $dl = Invoke-DownloadWithProgress -Uri $bundleUrl -OutFile $bundlePath -Activity "Downloading Winget Bundle"
            if ($dl) {
                try {
                    Write-Progress -Activity "Repairing Winget" -Status "Installing msixbundle..." -PercentComplete 50
                    Add-AppxPackage -Path $bundlePath -ForceApplicationShutdown -ErrorAction Stop
                    Write-Progress -Activity "Repairing Winget" -Completed
                    Write-Log -Message "DesktopAppInstaller bundle reinstalled." -Level "SUCCESS"
                }
                catch {
                    Write-Progress -Activity "Repairing Winget" -Completed
                    Write-Log -Message "Repair installation failed: $($_.Exception.Message)" -Level "ERROR"
                }
            }
            Remove-Item -Path $repairDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        }

        # Re-register AppInstaller manifest across all users
        try {
            Write-Log -Message "Re-registering DesktopAppInstaller manifests..." -Level "INFO"
            Get-AppxPackage -AllUsers *DesktopAppInstaller* | ForEach-Object {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {}

        # Ensure PATH includes WindowsApps
        if ($env:PATH -notlike "*$localAppPath*") {
            $env:PATH = "$env:PATH;$localAppPath"
        }
    }

    # Final verification check
    $finalCheck = Get-Command -Name "winget" -ErrorAction SilentlyContinue
    if ($finalCheck) {
        $ver = & winget --version 2>&1
        Write-Log -Message "Winget repair completed successfully. Version: $ver" -Level "SUCCESS"
        Add-ResultEntry -Name "Winget Repair" -Status "Installed" -Message "Windows Package Manager verified functional ($ver)."
    }
    else {
        Add-ResultEntry -Name "Winget Repair" -Status "Failed" -Message "Could not verify winget executable."
    }
}
