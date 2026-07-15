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

if %errorLevel% neq 0 (
    echo [✗] An error occurred while launching Saciid Windows Setup from GitHub online!
    echo ============================================================================== > "%USERPROFILE%\Desktop\problem.txt"
    echo                     SACIID WINDOWS SETUP - PROBLEM REPORT                     >> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo Timestamp      : %date% %time%                                                 >> "%USERPROFILE%\Desktop\problem.txt"
    echo Execution Mode : Online Batch Launcher (Run-Online-Setup.cmd)                  >> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo REASON FOR FAILURE:                                                            >> "%USERPROFILE%\Desktop\problem.txt"
    echo PowerShell failed to execute the command: irm https://raw.githubusercontent.com/Ayaanle60/Saciid-Windows-Setup/main/install.ps1 ^| iex >> "%USERPROFILE%\Desktop\problem.txt"
    echo Error Code     : %errorLevel%                                                  >> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo SUGGESTED ACTIONS:                                                             >> "%USERPROFILE%\Desktop\problem.txt"
    echo 1. Check internet connection and ensure your GitHub repo URL is accessible.    >> "%USERPROFILE%\Desktop\problem.txt"
    echo 2. Ensure antivirus or AppLocker is not blocking PowerShell downloads.        >> "%USERPROFILE%\Desktop\problem.txt"
    echo ============================================================================== >> "%USERPROFILE%\Desktop\problem.txt"
    echo.
    echo [!] A detailed problem report has been saved to your Desktop: %USERPROFILE%\Desktop\problem.txt
    echo [i] Press any key to close this window...
    pause >nul
)
