# ==============================================================================
# SACIID WINDOWS SETUP - HELPERS MODULE
# File: modules/helpers.ps1
# Description: Core utility functions for logging, progress bars, detection,
#              interactive update prompts, results tracking, and system cleanup.
# ==============================================================================

# Initialize Global Directory Paths
$global:SetupDir = "C:\WindowsSetup"
$global:LogsDir  = "$global:SetupDir\Logs"
$global:TempDir  = "$global:SetupDir\Temp"
$global:LogPath  = "$global:LogsDir\Install.log"

# Initialize Result Tracking Collections
$global:InstalledApps = [System.Collections.Generic.List[string]]::new()
$global:SkippedApps   = [System.Collections.Generic.List[string]]::new()
$global:FailedApps    = [System.Collections.Generic.List[string]]::new()

# Ensure base directories exist
if (-not (Test-Path -Path $global:LogsDir)) {
    New-Item -Path $global:LogsDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path -Path $global:TempDir)) {
    New-Item -Path $global:TempDir -ItemType Directory -Force | Out-Null
}

<#
.SYNOPSIS
    Writes structured log entries with timestamps to console and C:\WindowsSetup\Logs\Install.log.
#>
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "SKIP")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine   = "[$timestamp] [$Level] $Message"

    # Write to File
    try {
        Add-Content -Path $global:LogPath -Value $logLine -ErrorAction SilentlyContinue
    }
    catch {
        # Fallback if file lock exists
    }

    # Format Console Output
    switch ($Level) {
        "INFO"    { Write-Host " -> $Message" -ForegroundColor Cyan }
        "SUCCESS" { Write-Host " [✓] $Message" -ForegroundColor Green }
        "WARN"    { Write-Host " [!] $Message" -ForegroundColor Yellow }
        "ERROR"   { Write-Host " [✗] $Message" -ForegroundColor Red }
        "SKIP"    { Write-Host " [~] $Message" -ForegroundColor DarkYellow }
    }
}

<#
.SYNOPSIS
    Records the final outcome of an installation or configuration step.
#>
function Add-ResultEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Installed", "Skipped", "Failed")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [string]$Message = ""
    )

    switch ($Status) {
        "Installed" {
            if (-not $global:InstalledApps.Contains($Name)) { $global:InstalledApps.Add($Name) }
            if ($Message) { Write-Log -Message "$Name : $Message" -Level "SUCCESS" }
            else { Write-Log -Message "$Name successfully installed/configured." -Level "SUCCESS" }
        }
        "Skipped" {
            if (-not $global:SkippedApps.Contains($Name)) { $global:SkippedApps.Add($Name) }
            if ($Message) { Write-Log -Message "$Name : $Message" -Level "SKIP" }
            else { Write-Log -Message "$Name was skipped by user choice or configuration." -Level "SKIP" }
        }
        "Failed" {
            if (-not $global:FailedApps.Contains($Name)) { $global:FailedApps.Add($Name) }
            if ($Message) { Write-Log -Message "$Name : $Message" -Level "ERROR" }
            else { Write-Log -Message "$Name failed to install/configure." -Level "ERROR" }
        }
    }
}

<#
.SYNOPSIS
    Detects if an application is installed via Registry Uninstall keys or executable check.
    DOES NOT USE Win32_Product.
#>
function Test-SoftwareInstalled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$CheckExecutable = "",

        [Parameter(Mandatory = $false)]
        [string]$PackageFamilyName = ""
    )

    # 1. Check Executable Path if provided
    if ($CheckExecutable -ne "" -and (Test-Path -Path $CheckExecutable)) {
        Write-Log -Message "Detected $Name via executable: $CheckExecutable" -Level "INFO"
        return $true
    }

    # 2. Check Appx Package if provided
    if ($PackageFamilyName -ne "") {
        $appx = Get-AppxPackage -Name $PackageFamilyName -AllUsers -ErrorAction SilentlyContinue
        if ($appx) {
            Write-Log -Message "Detected $Name via Appx package: $($appx.Name)" -Level "INFO"
            return $true
        }
    }

    # 3. Check Uninstall Registry Keys (64-bit, 32-bit, and HKCU)
    $regPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $regPaths) {
        if (Test-Path -Path (Split-Path $path -Parent)) {
            $installed = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayName -like "*$Name*" }
            
            if ($installed) {
                Write-Log -Message "Detected $($installed.DisplayName) via Registry." -Level "INFO"
                return $true
            }
        }
    }

    return $false
}

<#
.SYNOPSIS
    Checks if software exists. If it does, prompts the user whether to update/reinstall.
    Returns $true if installation should proceed, $false if skipped.
#>
function Test-ShouldInstallOrUpdate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$CheckExecutable = "",

        [Parameter(Mandatory = $false)]
        [string]$PackageFamilyName = ""
    )

    $isInstalled = Test-SoftwareInstalled -Name $Name -CheckExecutable $CheckExecutable -PackageFamilyName $PackageFamilyName

    if ($isInstalled) {
        Write-Host ""
        Write-Host "$Name already installed." -ForegroundColor Yellow
        Write-Host "Latest version available." -ForegroundColor Yellow
        Write-Host ""
        
        $response = ""
        while ($response -notmatch '^[YyNn]$') {
            $response = Read-Host "Update? (Y/N)"
        }

        if ($response -match '^[Nn]$') {
            Add-ResultEntry -Name $Name -Status "Skipped" -Message "User chose not to update existing installation."
            return $false
        }
        else {
            Write-Log -Message "User chose to update existing installation of $Name." -Level "INFO"
            return $true
        }
    }

    return $true
}

<#
.SYNOPSIS
    Downloads a file with dynamic Write-Progress indication.
#>
function Invoke-DownloadWithProgress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$OutFile,

        [Parameter(Mandatory = $false)]
        [string]$Activity = "Downloading File"
    )

    Write-Log -Message "Downloading from: $Uri" -Level "INFO"
    Write-Progress -Activity $Activity -Status "Initializing download..." -PercentComplete 0

    try {
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        $request.AllowAutoRedirect = $true
        
        $response = $request.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()

        $targetFolder = Split-Path -Parent $OutFile
        if (-not (Test-Path -Path $targetFolder)) {
            New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
        }

        $fileStream = [System.IO.File]::Create($OutFile)
        $buffer = New-Object byte[] 65536
        $totalDownloaded = 0

        while (($read = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $totalDownloaded += $read

            if ($totalBytes -gt 0) {
                $percent = [int](($totalDownloaded / $totalBytes) * 100)
                $statusText = "Downloading: {0:N2} MB of {1:N2} MB ({2}%)" -f ($totalDownloaded / 1MB), ($totalBytes / 1MB), $percent
                Write-Progress -Activity $Activity -Status $statusText -PercentComplete $percent
            }
            else {
                $statusText = "Downloading: {0:N2} MB downloaded..." -f ($totalDownloaded / 1MB)
                Write-Progress -Activity $Activity -Status $statusText
            }
        }

        $fileStream.Close()
        $responseStream.Close()
        $response.Close()

        Write-Progress -Activity $Activity -Status "Verifying download..." -PercentComplete 100
        Start-Sleep -Milliseconds 300
        Write-Progress -Activity $Activity -Completed

        if (Test-Path -Path $OutFile) {
            Write-Log -Message "Download completed successfully: $OutFile" -Level "SUCCESS"
            return $true
        }
        else {
            throw "File not found after stream close: $OutFile"
        }
    }
    catch {
        Write-Progress -Activity $Activity -Completed
        Write-Log -Message "Download failed for ${Uri}: $($_.Exception.Message)" -Level "ERROR"
        if (Test-Path -Path $OutFile) { Remove-Item -Path $OutFile -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

<#
.SYNOPSIS
    Runs an executable/MSI with Write-Progress tracking and exit code validation.
#>
function Invoke-InstallWithProgress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $false)]
        [int[]]$ValidExitCodes = @(0, 3010)
    )

    Write-Log -Message "Executing: $FilePath $($ArgumentList -join ' ')" -Level "INFO"
    Write-Progress -Activity $Activity -Status "Installing package..." -PercentComplete 50

    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $FilePath
        if ($ArgumentList.Count -gt 0) {
            $processInfo.Arguments = ($ArgumentList -join " ")
        }
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($processInfo)
        $process.WaitForExit()

        Write-Progress -Activity $Activity -Status "Verifying installation..." -PercentComplete 90
        Start-Sleep -Milliseconds 500
        Write-Progress -Activity $Activity -Completed

        if ($ValidExitCodes -contains $process.ExitCode) {
            Write-Log -Message "Installation finished successfully (Exit Code: $($process.ExitCode))." -Level "SUCCESS"
            return $true
        }
        else {
            Write-Log -Message "Installation process exited with unexpected code: $($process.ExitCode)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Progress -Activity $Activity -Completed
        Write-Log -Message "Execution error during ${Activity}: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

<#
.SYNOPSIS
    Cleans up all temporary files created during installation.
#>
function Remove-TempFiles {
    [CmdletBinding()]
    param ()

    Write-Log -Message "Cleaning up temporary installation files..." -Level "INFO"
    Write-Progress -Activity "Cleaning Up" -Status "Removing temporary files and installers..." -PercentComplete 50

    try {
        if (Test-Path -Path $global:TempDir) {
            Get-ChildItem -Path $global:TempDir -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Progress -Activity "Cleaning Up" -Status "Cleanup finished." -PercentComplete 100
        Start-Sleep -Milliseconds 300
        Write-Progress -Activity "Cleaning Up" -Completed
        Write-Log -Message "Temporary files cleaned up successfully." -Level "SUCCESS"
    }
    catch {
        Write-Progress -Activity "Cleaning Up" -Completed
        Write-Log -Message "Warning during cleanup: $($_.Exception.Message)" -Level "WARN"
    }
}

<#
.SYNOPSIS
    Displays the final installation summary report.
#>
function Show-FinalReport {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                            FINAL INSTALLATION REPORT                         " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Installed Section
    Write-Host "Installed:" -ForegroundColor White
    if ($global:InstalledApps.Count -gt 0) {
        foreach ($app in $global:InstalledApps) {
            Write-Host "✓ $app" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  (None)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Skipped Section
    Write-Host "Skipped:" -ForegroundColor White
    if ($global:SkippedApps.Count -gt 0) {
        foreach ($app in $global:SkippedApps) {
            Write-Host "✓ $app" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  (None)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Failed Section
    Write-Host "Failed:" -ForegroundColor White
    if ($global:FailedApps.Count -gt 0) {
        foreach ($app in $global:FailedApps) {
            Write-Host "✗ $app" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  (None)" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Detailed log available at: $global:LogPath" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""
}
