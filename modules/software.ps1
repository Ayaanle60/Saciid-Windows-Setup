# ==============================================================================
# SACIID WINDOWS SETUP - SOFTWARE INSTALLATION MODULE
# File: modules/software.ps1
# Description: Installs latest AnyDesk, WinRAR (trial), Google Chrome Enterprise x64,
#              and VLC x64 directly from official internet sources with progress bars.
# ==============================================================================

<#
.SYNOPSIS
    Installs latest AnyDesk directly from official endpoint.
#>
function Install-AnyDesk {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                           INSTALLING ANYDESK (LATEST)                        " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    $exeCheck = "${env:ProgramFiles (x86)}\AnyDesk\AnyDesk.exe"
    if (-not (Test-Path $exeCheck)) {
        $exeCheck = "$env:ProgramFiles\AnyDesk\AnyDesk.exe"
    }

    $shouldInstall = Test-ShouldInstallOrUpdate -Name "AnyDesk" -CheckExecutable $exeCheck
    if (-not $shouldInstall) { return }

    $url = "https://download.anydesk.com/AnyDesk.exe"
    $outFile = "$global:TempDir\AnyDesk.exe"

    $downloadSuccess = Invoke-DownloadWithProgress -Uri $url -OutFile $outFile -Activity "Downloading AnyDesk"
    if (-not $downloadSuccess) {
        Add-ResultEntry -Name "AnyDesk" -Status "Failed" -Message "Failed to download AnyDesk.exe from $url"
        return
    }

    $installDir = "${env:ProgramFiles (x86)}\AnyDesk"
    $installArgs = @("--install", "`"$installDir`"", "--start-with-win", "--silent")

    $installSuccess = Invoke-InstallWithProgress -FilePath $outFile -ArgumentList $installArgs -Activity "Installing AnyDesk" -ValidExitCodes @(0, 1, 3010)

    if ($installSuccess -or (Test-Path "$installDir\AnyDesk.exe")) {
        Add-ResultEntry -Name "AnyDesk" -Status "Installed" -Message "AnyDesk latest version installed."
    }
    else {
        Add-ResultEntry -Name "AnyDesk" -Status "Failed" -Message "AnyDesk installation process returned failure."
    }

    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue | Out-Null
}

<#
.SYNOPSIS
    Installs latest WinRAR (x64 Trial Version only) from official RARLab endpoint.
#>
function Install-WinRAR {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                       INSTALLING WINRAR (X64 TRIAL)                          " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    $exeCheck = "$env:ProgramFiles\WinRAR\WinRAR.exe"
    $shouldInstall = Test-ShouldInstallOrUpdate -Name "WinRAR archiver" -CheckExecutable $exeCheck
    if (-not $shouldInstall) { return }

    # Official RARLab direct download for latest 64-bit English installer
    $url = "https://www.rarlab.com/rar/winrar-x64-701.exe"
    $outFile = "$global:TempDir\winrar-x64.exe"

    $downloadSuccess = Invoke-DownloadWithProgress -Uri $url -OutFile $outFile -Activity "Downloading WinRAR Trial (x64)"
    if (-not $downloadSuccess) {
        # Fallback to stable mirror if 701 link redirects or changes
        $fallbackUrl = "https://www.rarlab.com/rar/winrar-x64-624.exe"
        Write-Log -Message "Primary link failed. Trying fallback RARLab mirror..." -Level "WARN"
        $downloadSuccess = Invoke-DownloadWithProgress -Uri $fallbackUrl -OutFile $outFile -Activity "Downloading WinRAR Trial (Fallback)"
        if (-not $downloadSuccess) {
            Add-ResultEntry -Name "WinRAR archiver" -Status "Failed" -Message "Failed to download WinRAR installer."
            return
        }
    }

    $installSuccess = Invoke-InstallWithProgress -FilePath $outFile -ArgumentList @("/S") -Activity "Installing WinRAR Trial" -ValidExitCodes @(0)

    if ($installSuccess -or (Test-Path $exeCheck)) {
        Add-ResultEntry -Name "WinRAR archiver" -Status "Installed" -Message "WinRAR x64 Trial version installed."
    }
    else {
        Add-ResultEntry -Name "WinRAR archiver" -Status "Failed" -Message "WinRAR installer exited with errors."
    }

    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue | Out-Null
}

<#
.SYNOPSIS
    Installs Google Chrome Standalone Enterprise x64 MSI directly from Google CDN.
#>
function Install-GoogleChrome {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                INSTALLING GOOGLE CHROME (ENTERPRISE X64)                     " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    $exeCheck = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $exeCheck)) {
        $exeCheck = "${env:ProgramFiles (x86)}\Google\Chrome\Application\chrome.exe"
    }

    $shouldInstall = Test-ShouldInstallOrUpdate -Name "Google Chrome" -CheckExecutable $exeCheck
    if (-not $shouldInstall) { return }

    $url = "https://dl.google.com/chrome/install/GoogleChromeStandaloneEnterprise64.msi"
    $outFile = "$global:TempDir\GoogleChromeEnterprise64.msi"

    $downloadSuccess = Invoke-DownloadWithProgress -Uri $url -OutFile $outFile -Activity "Downloading Google Chrome Enterprise MSI"
    if (-not $downloadSuccess) {
        Add-ResultEntry -Name "Google Chrome" -Status "Failed" -Message "Failed to download Google Chrome standalone MSI."
        return
    }

    $msiArgs = @("/i", "`"$outFile`"", "/qn", "/norestart")
    $installSuccess = Invoke-InstallWithProgress -FilePath "msiexec.exe" -ArgumentList $msiArgs -Activity "Installing Google Chrome Enterprise" -ValidExitCodes @(0, 3010)

    if ($installSuccess -or (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe")) {
        Add-ResultEntry -Name "Google Chrome" -Status "Installed" -Message "Google Chrome Enterprise 64-bit installed."
        
        # Apply policies and extensions immediately if browsers module is loaded
        if (Get-Command -Name "Set-ChromePoliciesAndDefaults" -ErrorAction SilentlyContinue) {
            Set-ChromePoliciesAndDefaults
        }
    }
    else {
        Add-ResultEntry -Name "Google Chrome" -Status "Failed" -Message "Google Chrome MSI installation failed."
    }

    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue | Out-Null
}

<#
.SYNOPSIS
    Installs VLC Media Player x64 directly from VideoLAN mirrors.
#>
function Install-VLC {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                        INSTALLING VLC MEDIA PLAYER (X64)                     " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    $exeCheck = "$env:ProgramFiles\VideoLAN\VLC\vlc.exe"
    $shouldInstall = Test-ShouldInstallOrUpdate -Name "VLC media player" -CheckExecutable $exeCheck
    if (-not $shouldInstall) { return }

    # Try latest stable mirror endpoint
    $url = "https://get.videolan.org/vlc/last/win64/vlc-3.0.21-win64.exe"
    $outFile = "$global:TempDir\vlc-win64.exe"

    $downloadSuccess = Invoke-DownloadWithProgress -Uri $url -OutFile $outFile -Activity "Downloading VLC Media Player x64"
    if (-not $downloadSuccess) {
        $fallbackUrl = "https://mirror.clarkson.edu/videolan/vlc/3.0.21/win64/vlc-3.0.21-win64.exe"
        Write-Log -Message "Primary VideoLAN link failed. Trying fallback mirror..." -Level "WARN"
        $downloadSuccess = Invoke-DownloadWithProgress -Uri $fallbackUrl -OutFile $outFile -Activity "Downloading VLC (Fallback Mirror)"
        if (-not $downloadSuccess) {
            Add-ResultEntry -Name "VLC media player" -Status "Failed" -Message "Failed to download VLC x64 installer."
            return
        }
    }

    $installSuccess = Invoke-InstallWithProgress -FilePath $outFile -ArgumentList @("/L=1033", "/S") -Activity "Installing VLC Media Player" -ValidExitCodes @(0)

    if ($installSuccess -or (Test-Path $exeCheck)) {
        Add-ResultEntry -Name "VLC media player" -Status "Installed" -Message "VLC Media Player x64 installed."
    }
    else {
        Add-ResultEntry -Name "VLC media player" -Status "Failed" -Message "VLC installation process failed."
    }

    Remove-Item -Path $outFile -Force -ErrorAction SilentlyContinue | Out-Null
}
