# ==============================================================================
# SACIID WINDOWS SETUP - MAIN ENTRY POINT
# File: install.ps1
# Description: Self-elevates to Administrator, sets execution policy bypass,
#              detects OS edition, stages modules if invoked via web (irm | iex),
#              dot-sources modules, and launches the interactive numbered menu.
# ==============================================================================

# 1. LANGUAGE MODE CHECK & EXECUTION POLICY BYPASS
function Exit-WithError {
    param ([string]$Message)
    
    # Create problem.txt on the user's Desktop explaining exactly why it failed
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    if (-not $desktopPath -or -not (Test-Path $desktopPath)) {
        $desktopPath = "$env:USERPROFILE\Desktop"
    }
    $problemFile = Join-Path -Path $desktopPath -ChildPath "problem.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $osName = "Windows"
    $osVer = "Unknown"
    try {
        $osInfo = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($osInfo) { $osName = $osInfo.Caption }
        $regInfo = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
        if ($regInfo) { $osVer = "$($regInfo.DisplayVersion) ($($osInfo.Version))" }
    } catch {}

    $problemReport = @"
==============================================================================
                    SACIID WINDOWS SETUP - PROBLEM REPORT
==============================================================================
Timestamp      : $timestamp
System OS      : $osName - $osVer
PowerShell     : $($PSVersionTable.PSVersion) (LanguageMode: $($ExecutionContext.SessionState.LanguageMode))
Execution Mode : $(if ($PSCommandPath) { "Local Script ($PSCommandPath)" } else { "Online GitHub Command (irm | iex)" })
==============================================================================

REASON FOR FAILURE / PROBLEM:
$Message

==============================================================================
SUGGESTED ACTIONS & SOLUTIONS:
1. Run as Administrator: Ensure you are running PowerShell as Administrator
   (Right-click PowerShell or Run-Online-Setup.cmd -> Run as Administrator).
2. Online GitHub Check: If running via 'irm | iex' from GitHub, ensure that
   all module files (.ps1) and configs/office.xml exist and are uploaded to:
   https://github.com/Ayaanle60/Saciid-Windows-Setup
3. Antivirus / Security: Check if your antivirus, Windows Defender, or AppLocker
   is blocking script execution or network requests to raw.githubusercontent.com.
==============================================================================
"@
    try {
        Set-Content -Path $problemFile -Value $problemReport -Force -ErrorAction SilentlyContinue
        Write-Host " [!] A detailed problem report has been saved to your Desktop: $problemFile" -ForegroundColor Yellow
    } catch {}

    Write-Host " [✗] $Message" -ForegroundColor Red
    Write-Host ""
    Write-Host " [i] Press [Enter] or any key to keep window open / close..." -ForegroundColor Cyan
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { Read-Host "Press [Enter] to close" }
    exit 1
}

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Exit-WithError "Critical Error: Saciid Windows Setup cannot run due to restricted LanguageMode ($($ExecutionContext.SessionState.LanguageMode))."
}

try {
    Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
} catch {}

# 2. SELF ELEVATION CHECK & AUTOMATIC RELAUNCH (Inspired by Chris Titus Tech WinUtil)
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host " [!] Requesting Administrative privileges (UAC)..." -ForegroundColor Yellow
    
    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }

    # Check if we are running from a local script file or from memory (irm | iex)
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
        $scriptArg = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        try {
            if ($processCmd -eq "wt.exe") {
                Start-Process $processCmd -ArgumentList "$powershellCmd $scriptArg" -Verb RunAs -ErrorAction Stop
            } else {
                Start-Process $processCmd -ArgumentList $scriptArg -Verb RunAs -ErrorAction Stop
            }
            exit
        }
        catch {
            Exit-WithError "Failed to elevate privileges or UAC prompt was declined. Please right-click and select 'Run as Administrator'."
        }
    }
    else {
        # We are running from memory via Invoke-RestMethod / Invoke-Expression
        $gitHubUser = "Ayaanle60"
        $gitHubRepo = "Saciid-Windows-Setup"
        $gitHubBranch = "main"
        $scriptArg = "-NoExit -NoProfile -ExecutionPolicy Bypass -Command `"& { irm https://raw.githubusercontent.com/$gitHubUser/$gitHubRepo/$gitHubBranch/install.ps1 | iex }`""
        try {
            # Use powershell directly for memory pipe to prevent terminal wrapper quote mangling
            Start-Process "powershell.exe" -ArgumentList $scriptArg -Verb RunAs -ErrorAction Stop
            exit
        }
        catch {
            Exit-WithError "Failed to elevate privileges or UAC prompt was declined. Please run PowerShell as Administrator."
        }
    }
}

# Ensure TLS 1.2 and TLS 1.3 are enabled for secure modern GitHub and CDN downloads
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 -bor 3072
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}

# 3. AUTOMATIC OS EDITION DETECTION
function Get-WindowsEditionDetails {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $caption = $os.Caption
        $version = $os.Version
        $regInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
        $editionId = $regInfo.EditionID
        $displayVer = $regInfo.DisplayVersion

        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " Detected Operating System : $caption ($editionId)" -ForegroundColor Cyan
        Write-Host " Version / Build           : $displayVer ($version)" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
    }
    catch {
        Write-Host " Detected Operating System : Windows 10/11 (Edition detection fallback)" -ForegroundColor Cyan
    }
}

Clear-Host
Write-Host "==============================================================================" -ForegroundColor Cyan
# ASCII Header
Write-Host "                                                                              " -ForegroundColor Cyan
Write-Host "                  ███████╗ █████╗  ██████╗██╗██╗██████╗                       " -ForegroundColor Cyan
Write-Host "                  ██╔════╝██╔══██╗██╔════╝██║██║██╔══██╗                      " -ForegroundColor Cyan
Write-Host "                  ███████╗███████║██║     ██║██║██║  ██║                      " -ForegroundColor Cyan
Write-Host "                  ╚════██║██╔══██║██║     ██║██║██║  ██║                      " -ForegroundColor Cyan
Write-Host "                  ███████║██║  ██║╚██████╗██║██║██████╔╝                      " -ForegroundColor Cyan
Write-Host "                  ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝╚═╝╚═════╝                       " -ForegroundColor Cyan
Write-Host "                                                                              " -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Get-WindowsEditionDetails

# 4. MODULE STAGING & DOT-SOURCING ARCHITECTURE
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot -or $scriptRoot -eq "") {
    # If running via web pipe (irm | iex), stage local framework directory
    $scriptRoot = "$env:TEMP\SaciidWindowsSetup_Framework"
    if (-not (Test-Path $scriptRoot)) {
        New-Item -Path $scriptRoot -ItemType Directory -Force | Out-Null
    }
}

$modulesDir = "$scriptRoot\modules"
$configsDir = "$scriptRoot\configs"

# Check if local modules exist. If missing, download directly from GitHub repo
$requiredModules = @("helpers.ps1", "software.ps1", "office.ps1", "browsers.ps1", "tweaks.ps1", "ltsc.ps1", "winget.ps1", "menu.ps1")
$missingModules = @()

if (-not (Test-Path $modulesDir)) {
    New-Item -Path $modulesDir -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $configsDir)) {
    New-Item -Path $configsDir -ItemType Directory -Force | Out-Null
}

foreach ($mod in $requiredModules) {
    if (-not (Test-Path "$modulesDir\$mod")) {
        $missingModules += $mod
    }
}

try {
    if ($missingModules.Count -gt 0) {
        Write-Host " [i] Local module framework incomplete. Downloading latest modules from GitHub..." -ForegroundColor Cyan
        $gitHubUser = "Ayaanle60"
        $gitHubRepo = "Saciid-Windows-Setup"
        $gitHubBranch = "main"

        foreach ($mod in $missingModules) {
            $modUrl = "https://raw.githubusercontent.com/$gitHubUser/$gitHubRepo/$gitHubBranch/modules/$mod"
            $rootUrl = "https://raw.githubusercontent.com/$gitHubUser/$gitHubRepo/$gitHubBranch/$mod"
            $modTarget = "$modulesDir\$mod"
            Write-Host "     -> Downloading $mod..." -ForegroundColor DarkCyan
            
            $downloaded = $false
            foreach ($url in @($modUrl, $rootUrl)) {
                try {
                    Invoke-RestMethod -Uri $url -OutFile $modTarget -ErrorAction Stop
                    if (Test-Path $modTarget) {
                        $contentCheck = Get-Content -Path $modTarget -TotalCount 1 -ErrorAction SilentlyContinue
                        if ($contentCheck -match "404: Not Found") {
                            Remove-Item -Path $modTarget -Force -ErrorAction SilentlyContinue
                        } else {
                            $downloaded = $true
                            break
                        }
                    }
                } catch {}
            }

            if (-not $downloaded) {
                Write-Host " [!] Could not fetch '$mod' from GitHub online (404 Not Found)." -ForegroundColor Yellow
                Write-Host "     Ensure the 'modules' folder (containing $mod) is uploaded to https://github.com/$gitHubUser/$gitHubRepo" -ForegroundColor Yellow
            }
        }

        # Fetch configs/office.xml if missing (check both configs/office.xml and root office.xml)
        if (-not (Test-Path "$configsDir\office.xml")) {
            foreach ($url in @("https://raw.githubusercontent.com/$gitHubUser/$gitHubRepo/$gitHubBranch/configs/office.xml", "https://raw.githubusercontent.com/$gitHubUser/$gitHubRepo/$gitHubBranch/office.xml")) {
                try {
                    Invoke-RestMethod -Uri $url -OutFile "$configsDir\office.xml" -ErrorAction Stop
                    if (Test-Path "$configsDir\office.xml") {
                        $contentCheck = Get-Content -Path "$configsDir\office.xml" -TotalCount 1 -ErrorAction SilentlyContinue
                        if ($contentCheck -match "404: Not Found") {
                            Remove-Item -Path "$configsDir\office.xml" -Force -ErrorAction SilentlyContinue
                        } else { break }
                    }
                } catch {}
            }
        }
    }

    # Dot-source all required modules safely
    foreach ($mod in $requiredModules) {
        $modPath = "$modulesDir\$mod"
        if (Test-Path $modPath) {
            try {
                . $modPath
            }
            catch {
                Exit-WithError "Syntax or execution error loading module ${mod}: $($_.Exception.Message)"
            }
        }
        else {
            Exit-WithError "Critical error: Module '$mod' not found at $modPath. Ensure all files are pushed to GitHub."
        }
    }

    # 5. INITIALIZE LOGGING & LAUNCH INTERACTIVE MENU
    Write-Log -Message "Saciid Windows Setup session started by $env:USERNAME on $env:COMPUTERNAME" -Level "INFO"
    Show-Menu
}
catch {
    Exit-WithError "Unhandled startup or execution failure: $($_.Exception.Message)"
}
