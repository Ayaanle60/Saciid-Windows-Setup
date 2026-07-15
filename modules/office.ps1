# ==============================================================================
# SACIID WINDOWS SETUP - MICROSOFT 365 / OFFICE MODULE
# File: modules/office.ps1
# Description: Automatically downloads and extracts the Office Deployment Tool (ODT)
#              and deploys 64-bit English (en-us) Word, Excel, PowerPoint, and Outlook
#              using configs/office.xml while excluding unwanted applications.
# ==============================================================================

<#
.SYNOPSIS
    Downloads ODT, extracts setup.exe, copies configs/office.xml, and installs Office.
#>
function Install-Microsoft365 {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                       INSTALLING MICROSOFT 365 (64-BIT)                      " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Check existing installation via WINWORD.EXE or Registry
    $wordPath = "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE"
    $shouldInstall = Test-ShouldInstallOrUpdate -Name "Microsoft 365" -CheckExecutable $wordPath

    if (-not $shouldInstall) {
        return
    }

    # Prepare directories
    $odtDir = "$global:TempDir\ODT"
    if (-not (Test-Path -Path $odtDir)) {
        New-Item -Path $odtDir -ItemType Directory -Force | Out-Null
    }

    # 1. Download Office Deployment Tool
    $odtUrl  = "https://go.microsoft.com/fwlink/p/?LinkID=626065"
    $odtExe  = "$odtDir\officedeploymenttool.exe"

    Write-Log -Message "Downloading Microsoft Office Deployment Tool..." -Level "INFO"
    $downloadSuccess = Invoke-DownloadWithProgress -Uri $odtUrl -OutFile $odtExe -Activity "Downloading Office Deployment Tool"

    if (-not $downloadSuccess) {
        Add-ResultEntry -Name "Microsoft 365" -Status "Failed" -Message "Failed to download Office Deployment Tool."
        return
    }

    # 2. Extract ODT setup.exe
    Write-Log -Message "Extracting Office Deployment Tool..." -Level "INFO"
    Write-Progress -Activity "Extracting ODT" -Status "Unpacking setup.exe and configuration files..." -PercentComplete 50

    try {
        $extractProc = [System.Diagnostics.Process]::Start($odtExe, "/quiet /extract:`"$odtDir`"")
        $extractProc.WaitForExit()
        Write-Progress -Activity "Extracting ODT" -Completed

        if (-not (Test-Path -Path "$odtDir\setup.exe")) {
            throw "setup.exe was not found in $odtDir after extraction."
        }
        Write-Log -Message "ODT extracted successfully." -Level "SUCCESS"
    }
    catch {
        Write-Progress -Activity "Extracting ODT" -Completed
        Write-Log -Message "Extraction failed: $($_.Exception.Message)" -Level "ERROR"
        Add-ResultEntry -Name "Microsoft 365" -Status "Failed" -Message "Failed to extract ODT setup.exe."
        return
    }

    # 3. Locate configs/office.xml
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $configSource = "$repoRoot\configs\office.xml"
    $configTarget = "$odtDir\office.xml"

    if (Test-Path -Path $configSource) {
        Copy-Item -Path $configSource -Destination $configTarget -Force
        Write-Log -Message "Copied local office.xml configuration." -Level "INFO"
    }
    else {
        Write-Log -Message "Local configs/office.xml not found. Creating fallback configuration..." -Level "WARN"
        $fallbackXml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="Publisher" />
      <ExcludeApp ID="Teams" />
      <ExcludeApp ID="Bing" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="PinIconsToTaskbar" Value="FALSE" />
  <Property Name="AUTOACTIVATE" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@
        Set-Content -Path $configTarget -Value $fallbackXml -Force
    }

    # 4. Execute setup.exe /configure office.xml
    Write-Log -Message "Starting silent Office installation (Word, Excel, PowerPoint, Outlook)..." -Level "INFO"
    $installSuccess = Invoke-InstallWithProgress -FilePath "$odtDir\setup.exe" -ArgumentList @("/configure", "`"office.xml`"") -Activity "Installing Microsoft 365" -ValidExitCodes @(0, 3010)

    if ($installSuccess) {
        Add-ResultEntry -Name "Microsoft 365" -Status "Installed" -Message "Word, Excel, PowerPoint, and Outlook (en-us x64) installed successfully."
    }
    else {
        Add-ResultEntry -Name "Microsoft 365" -Status "Failed" -Message "ODT setup.exe exited with errors."
    }

    # Clean up intermediate files
    Remove-Item -Path $odtDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}
