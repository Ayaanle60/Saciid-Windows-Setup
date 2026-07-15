@echo off
:: ==============================================================================
:: SACIID WINDOWS SETUP - DOUBLE-CLICK LAUNCHER
:: File: Run-Setup.cmd
:: Description: Automatically requests Administrator privileges (UAC), bypasses
::              PowerShell execution policy, and launches install.ps1 safely.
:: ==============================================================================

title Saciid Windows Setup Launcher
echo Checking Administrator privileges...

:: Check if script is running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrative privileges ^(UAC^)...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Set directory to the folder where this script is located
cd /d "%~dp0"

echo [i] Administrator privileges confirmed. Launching setup...
echo.

:: Launch install.ps1 if present locally, otherwise fetch from GitHub online
if exist "install.ps1" (
    powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "install.ps1"
) else (
    echo [i] Local install.ps1 not found. Downloading directly from GitHub online...
    powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Ayaanle60/Saciid-Windows-Setup/main/install.ps1 | iex"
)

if %errorLevel% neq 0 (
    echo [✗] An error occurred while running Saciid Windows Setup!
    echo ============================================================================== > "%USERPROFILE%\Desktop\problem.txt"
    echo                     SACIID WINDOWS SETUP - PROBLEM REPORT                     >> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo Timestamp      : %date% %time%                                                 >> "%USERPROFILE%\Desktop\problem.txt"
    echo Execution Mode : Double-Click Batch Launcher (Run-Setup.cmd)                   >> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo REASON FOR FAILURE:                                                            >> "%USERPROFILE%\Desktop\problem.txt"
    echo PowerShell script exited with error code: %errorLevel%                         >> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo SUGGESTED ACTIONS:                                                             >> "%USERPROFILE%\Desktop\problem.txt"
    echo 1. Check if antivirus or AppLocker blocked script execution.                   >> "%USERPROFILE%\Desktop\problem.txt"
    echo 2. If running online, verify internet connection and GitHub repo accessibility.>> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo.
    echo [!] A detailed problem report has been saved to your Desktop: %USERPROFILE%\Desktop\problem.txt
    echo [i] Press any key to close this window...
    pause >nul
)
