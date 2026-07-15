@echo off
:: ==============================================================================
:: SACIID WINDOWS SETUP - ONLINE GITHUB LAUNCHER
:: File: Run-Online-Setup.cmd
:: Description: Automatically requests Administrator privileges (UAC), bypasses
::              PowerShell execution policy, and runs directly from GitHub online.
:: ==============================================================================

title Saciid Windows Setup (Online GitHub Launcher)
echo Checking Administrator privileges...

:: Check if script is running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting Administrative privileges ^(UAC^)...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo [i] Administrator privileges confirmed.
echo [i] Downloading and launching Saciid Windows Setup directly from GitHub...
echo.

powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/Ayaanle60/Saciid-Windows-Setup/main/install.ps1 | iex"
