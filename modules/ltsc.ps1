# ==============================================================================
# SACIID WINDOWS SETUP - LTSC & IOT ENTERPRISE MODULE
# File: modules/ltsc.ps1
# Description: Detects Windows LTSC / IoT Enterprise editions.
#              Installs Microsoft Photos, Calculator, Store, App Installer,
#              VCLibs, UI.Xaml, and Winget dependencies even on systems lacking Store.
# ==============================================================================

<#
.SYNOPSIS
    Checks whether the current Windows OS is an LTSC or IoT Enterprise edition.
#>
function Test-IsLtscOrIotEdition {
    [CmdletBinding()]
    param ()

    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $caption = $osInfo.Caption
        $regEdition = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue).EditionID

        if ($caption -match "LTSC|IoT" -or $regEdition -match "LTSC|IoT") {
            Write-Log -Message "Detected LTSC / IoT Enterprise environment: $caption ($regEdition)" -Level "INFO"
            return $true
        }
    }
    catch {
        Write-Log -Message "Could not query Win32_OperatingSystem for LTSC check." -Level "WARN"
    }

    return $false
}

<#
.SYNOPSIS
    Downloads and installs core Appx/MSIX dependencies (VCLibs, UI.Xaml, AppInstaller/Winget).
#>
function Install-WingetAndDependenciesOffline {
    [CmdletBinding()]
    param ()

    Write-Log -Message "Installing core VCLibs, UI.Xaml, and AppInstaller/Winget packages..." -Level "INFO"

    $depDir = "$global:TempDir\Dependencies"
    if (-not (Test-Path $depDir)) {
        New-Item -Path $depDir -ItemType Directory -Force | Out-Null
    }

    # Package URLs from official Microsoft and GitHub release assets
    $packages = @(
        @{
            Name     = "Microsoft.VCLibs.140.00.UWPDesktop"
            Url      = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
            OutFile  = "$depDir\VCLibs.x64.appx"
        },
        @{
            Name     = "Microsoft.UI.Xaml.2.8"
            Url      = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
            OutFile  = "$depDir\UI.Xaml.2.8.x64.appx"
        },
        @{
            Name     = "Microsoft.DesktopAppInstaller (Winget)"
            Url      = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
            OutFile  = "$depDir\DesktopAppInstaller.msixbundle"
        }
    )

    foreach ($pkg in $packages) {
        $installed = Get-AppxPackage -Name "*$($pkg.Name.Split(' ')[0])*" -AllUsers -ErrorAction SilentlyContinue
        if ($installed) {
            Write-Log -Message "$($pkg.Name) is already present on the system." -Level "SUCCESS"
            continue
        }

        $downloadSuccess = Invoke-DownloadWithProgress -Uri $pkg.Url -OutFile $pkg.OutFile -Activity "Downloading $($pkg.Name)"
        if ($downloadSuccess) {
            Write-Progress -Activity "Installing $($pkg.Name)" -Status "Registering Appx/MSIX package..." -PercentComplete 50
            try {
                Add-AppxPackage -Path $pkg.OutFile -ErrorAction Stop
                Write-Progress -Activity "Installing $($pkg.Name)" -Completed
                Write-Log -Message "Successfully installed $($pkg.Name)." -Level "SUCCESS"
            }
            catch {
                Write-Progress -Activity "Installing $($pkg.Name)" -Completed
                Write-Log -Message "Failed to register package $($pkg.Name): $($_.Exception.Message)" -Level "ERROR"
            }
        }
        else {
            Write-Log -Message "Skipping installation of $($pkg.Name) due to download failure." -Level "WARN"
        }
    }

    Remove-Item -Path $depDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}

<#
.SYNOPSIS
    Installs Microsoft Photos and Microsoft Calculator on LTSC systems.
#>
function Install-LtscApps {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                  INSTALLING LTSC APPS & STORE DEPENDENCIES                   " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    $isLtsc = Test-IsLtscOrIotEdition
    if (-not $isLtsc) {
        Write-Host " [!] Current OS is not detected as Windows LTSC or IoT Enterprise." -ForegroundColor Yellow
        Write-Host "     Proceeding anyway to ensure missing Store, Calculator, and Photos are available." -ForegroundColor Yellow
        Write-Host ""
    }

    # 1. Ensure core dependencies (VCLibs, UI.Xaml, App Installer, Winget) are installed
    Install-WingetAndDependenciesOffline

    # Check if Winget is now accessible either via command or direct PATH
    $wingetCmd = Get-Command -Name "winget" -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
        $localWinget = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        if (Test-Path $localWinget) {
            $wingetPath = $localWinget
        }
    } else {
        $wingetPath = $wingetCmd.Source
    }

    # 2. Install Microsoft Calculator
    Write-Log -Message "Checking Microsoft Calculator..." -Level "INFO"
    $calcApp = Get-AppxPackage -Name "*WindowsCalculator*" -AllUsers -ErrorAction SilentlyContinue
    if (-not $calcApp) {
        if ($wingetPath) {
            Write-Log -Message "Installing Microsoft Calculator via Winget..." -Level "INFO"
            $installSuccess = Invoke-InstallWithProgress -FilePath $wingetPath -ArgumentList @("install", "--id", "9WZDNCRFHVN5", "--exact", "--source", "msstore", "--accept-package-agreements", "--accept-source-agreements") -Activity "Installing Microsoft Calculator"
            if ($installSuccess -or (Get-AppxPackage -Name "*WindowsCalculator*")) {
                Add-ResultEntry -Name "Microsoft Calculator" -Status "Installed" -Message "Calculator installed successfully."
            } else {
                Add-ResultEntry -Name "Microsoft Calculator" -Status "Failed" -Message "Failed to install Calculator from msstore."
            }
        }
        else {
            Add-ResultEntry -Name "Microsoft Calculator" -Status "Failed" -Message "Winget not available to install Calculator."
        }
    }
    else {
        Add-ResultEntry -Name "Microsoft Calculator" -Status "Skipped" -Message "Microsoft Calculator is already installed."
    }

    # 3. Install Microsoft Photos
    Write-Log -Message "Checking Microsoft Photos..." -Level "INFO"
    $photosApp = Get-AppxPackage -Name "*Windows.Photos*" -AllUsers -ErrorAction SilentlyContinue
    if (-not $photosApp) {
        if ($wingetPath) {
            Write-Log -Message "Installing Microsoft Photos via Winget..." -Level "INFO"
            $installSuccess = Invoke-InstallWithProgress -FilePath $wingetPath -ArgumentList @("install", "--id", "9WZDNCRFJBH4", "--exact", "--source", "msstore", "--accept-package-agreements", "--accept-source-agreements") -Activity "Installing Microsoft Photos"
            if ($installSuccess -or (Get-AppxPackage -Name "*Windows.Photos*")) {
                Add-ResultEntry -Name "Microsoft Photos" -Status "Installed" -Message "Photos installed successfully."
            } else {
                Add-ResultEntry -Name "Microsoft Photos" -Status "Failed" -Message "Failed to install Photos from msstore."
            }
        }
        else {
            Add-ResultEntry -Name "Microsoft Photos" -Status "Failed" -Message "Winget not available to install Photos."
        }
    }
    else {
        Add-ResultEntry -Name "Microsoft Photos" -Status "Skipped" -Message "Microsoft Photos is already installed."
    }

    # 4. Check & Repair Microsoft Store if missing
    $storeApp = Get-AppxPackage -Name "*WindowsStore*" -AllUsers -ErrorAction SilentlyContinue
    if (-not $storeApp) {
        Write-Log -Message "Microsoft Store is missing. Attempting registration from system repository..." -Level "WARN"
        try {
            $storeManifest = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps\*WindowsStore*\AppxManifest.xml" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($storeManifest) {
                Add-AppxPackage -DisableDevelopmentMode -Register $storeManifest.FullName -ErrorAction Stop
                Write-Log -Message "Microsoft Store restored and registered from local repository." -Level "SUCCESS"
                Add-ResultEntry -Name "Microsoft Store" -Status "Installed" -Message "Restored from local manifest."
            }
            elseif ($wingetPath) {
                Invoke-InstallWithProgress -FilePath $wingetPath -ArgumentList @("install", "--id", "9WZDNCRFJBMP", "--exact", "--source", "msstore", "--accept-package-agreements", "--accept-source-agreements") -Activity "Installing Microsoft Store" | Out-Null
                if (Get-AppxPackage -Name "*WindowsStore*") {
                    Add-ResultEntry -Name "Microsoft Store" -Status "Installed" -Message "Installed via Winget."
                } else {
                    Add-ResultEntry -Name "Microsoft Store" -Status "Failed" -Message "Could not restore Store on this LTSC build."
                }
            }
            else {
                Add-ResultEntry -Name "Microsoft Store" -Status "Failed" -Message "Manifest not found in WindowsApps directory."
            }
        }
        catch {
            Write-Log -Message "Error while attempting Store registration: $($_.Exception.Message)" -Level "ERROR"
            Add-ResultEntry -Name "Microsoft Store" -Status "Failed" -Message "Failed to register Microsoft Store manifest."
        }
    }
    else {
        Write-Log -Message "Microsoft Store package is verified intact." -Level "SUCCESS"
    }
}
