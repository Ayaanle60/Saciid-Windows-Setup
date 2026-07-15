# Saciid Windows Setup

**Saciid Windows Setup** is a complete, modular, maintainable, and production-ready Windows deployment framework inspired by Chris Titus Tech's Windows utility. It automates software installations directly from official internet sources, deploys customized Microsoft 365 packages via the Office Deployment Tool, applies privacy and debloating Group Policy overrides, forces uBlock Origin ad-blocking on Edge and Chrome, restores missing Store dependencies on LTSC/IoT builds, and repairs the Windows Package Manager (`winget`).

---

## ⚡ Quick Start (Global Execution)

Launch PowerShell on any supported Windows PC and run the following single command:

```powershell
irm https://raw.githubusercontent.com/Ayaanle60/Saciid-Windows-Setup/main/install.ps1 | iex
```

> **Note**: Before hosting on your GitHub account, replace `USERNAME` with your actual GitHub username in the command above and within `install.ps1`.

### Local Execution & Double-Click Launcher
If you have downloaded or cloned this repository locally, you don't even need to open PowerShell first:
* **Double-Click Launcher**: Simply double-click **`Run-Setup.cmd`** in the folder. It automatically requests Administrator privileges (`UAC`), sets the PowerShell `ExecutionPolicy Bypass`, and launches the setup menu for you!
* **PowerShell Console**: Or run from PowerShell directly:
```powershell
.\install.ps1
```

---

## 🖥️ Supported Operating Systems

The framework automatically detects and optimizes for:
* **Windows 10 Home**
* **Windows 10 Pro**
* **Windows 10 Enterprise**
* **Windows 10 Education**
* **Windows 10 LTSC (Long-Term Servicing Channel)**
* **Windows 10 IoT Enterprise**
* **Windows 11 (All Editions)**

---

## 🚀 Core Features & Capabilities

### 1. Automatic Elevation & Execution Policy Bypass
* **Self-Elevation**: Automatically detects if PowerShell is running as Administrator. If not, it relaunches itself elevated cleanly so you only see the Windows UAC prompt once.
* **Execution Policy Bypass**: Temporarily sets `ExecutionPolicy Bypass -Scope Process -Force` so scripts run without security warnings while leaving system defaults untouched when closed.

### 2. Interactive Number-Based Menu
When executed, you will be presented with a clean ASCII menu supporting single, multiple (`1,4,7`), or batch selections:

```text
===================================
      SACIID WINDOWS SETUP
===================================

1. Install Everything
2. AnyDesk
3. WinRAR
4. Microsoft 365
5. Google Chrome
6. VLC
7. Browser Extensions
8. Windows Tweaks
9. LTSC Apps
10. Winget Repair
11. Exit
```

### 3. Smart Software Detection & Direct Internet Downloads
* **No `Win32_Product` WMI Queries**: Avoids slow and risky WMI queries. Uses 64-bit (`HKLM\Software`), 32-bit (`HKLM\Software\Wow6432Node`), and User (`HKCU\Software`) Uninstall registry keys, binary path checks, and `AppxPackage` verification.
* **Interactive Update Prompt**: If an application already exists on your system, you are prompted:
  ```text
  Chrome already installed.
  Latest version available.
  Update? (Y/N)
  ```
* **Direct Official CDN Downloads**: Always fetches the latest installers directly from AnyDesk, RARLab (WinRAR x64 Trial), Google (Chrome Enterprise 64-bit MSI), and VideoLAN (VLC x64) without relying entirely on `winget`.

### 4. Custom Microsoft 365 (64-bit English en-us)
Deploys Office directly via the **Microsoft Office Deployment Tool (ODT)** using `configs/office.xml`:
* **Included**: Word, Excel, PowerPoint, Outlook.
* **Excluded**: Teams, OneDrive, Access, Publisher, OneNote, Skype for Business / Lync, Groove, Bing features.

### 5. Group Policy Debloating & uBlock Origin Enforcement
* **Google Chrome**: Sets Group Policy `ExtensionInstallForcelist` in `HKLM` to force-install **uBlock Origin Lite**. Sets Chrome as default browser or opens `ms-settings:defaultapps`.
* **Microsoft Edge**: Sets Group Policy `ExtensionInstallForcelist` in `HKLM` to force-install **uBlock Origin**. Disables all Start/News/Discover feeds, Shopping suggestions, Copilot, Sidebar web widgets, Rewards, and Office recommendations.

### 6. Production Windows Tweaks
* Shows file extensions (`HideFileExt = 0`) & opens File Explorer directly to **This PC**.
* Disables Windows tips, lockscreen ads, and Cortana/Bing Start Menu web search integration.
* Removes Windows 11 Taskbar Widgets (`AllowNewsAndInterests = 0`) & Chat icon (`ChatIcon = 3`).
* Activates the **High Performance** system power plan (`8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`).
* Enables **Dark Mode** for Apps and System themes.
* Restarts File Explorer automatically so changes apply immediately.

### 7. LTSC / IoT Enterprise & Winget Repair Architecture
* Works seamlessly on **Windows 10 LTSC / IoT Enterprise** builds even when Microsoft Store is absent.
* Automatically downloads and registers core dependencies (`Microsoft.VCLibs.x64.14.00.Desktop.appx`, `Microsoft.UI.Xaml.2.8.appx`, `Microsoft.DesktopAppInstaller.msixbundle`).
* Restores and registers **Microsoft Store**, **Microsoft Calculator**, and **Microsoft Photos**.
* Completely repairs broken or missing `winget` CLI installations and adds `WindowsApps` to system `PATH`.

### 8. Progress Bars, Logging & Final Summary Report
* Every step displays dynamic terminal progress bars using `Write-Progress` (`Downloading...`, `Installing...`, `Verifying...`, `Cleaning up...`).
* Maintains comprehensive execution logs at `C:\WindowsSetup\Logs\Install.log`.
* Cleans up all temporary downloads automatically (`C:\WindowsSetup\Temp`) and outputs a clean final report:
  ```text
  Installed:
  ✓ Chrome
  ✓ VLC
  ✓ Office

  Skipped:
  ✓ WinRAR

  Failed:
  ✗ Calculator
  ```

---

## 📁 Repository Tree

```text
Saciid-Windows-Setup
│
├── Run-Setup.cmd             # Double-click launcher (auto UAC elevation & ExecutionPolicy bypass)
├── install.ps1               # Main entry point (self-elevation, staging, menu launch)
├── README.md                 # Project documentation
├── modules
│   ├── helpers.ps1           # Logging, progress bars, software detection, cleanup
│   ├── software.ps1          # AnyDesk, WinRAR, Chrome, and VLC installation logic
│   ├── office.ps1            # Office Deployment Tool wrapper & custom installation
│   ├── browsers.ps1          # Chrome/Edge uBlock Origin & debloat Group Policies
│   ├── tweaks.ps1            # Registry adjustments, explorer tweaks, power schemes
│   ├── ltsc.ps1              # LTSC/IoT OS checks, offline Store, Photos, & Calculator
│   ├── winget.ps1            # Winget bootstrap, health check, and dependency repair
│   └── menu.ps1              # Interactive numbered multi-selection menu system
│
├── configs
│   └── office.xml            # Office Deployment Tool XML configuration file
│
└── assets
    └── README.txt            # Project asset placeholder
```

---

## 🛠️ Customization Guide

1. **Changing GitHub Username**: Open `install.ps1` and update `$gitHubUser = "USERNAME"` to your GitHub handle so `irm | iex` online execution fetches your specific fork/modules.
2. **Adding/Removing Office Apps**: Open `configs\office.xml` and add/remove `<ExcludeApp ID="AppName" />` tags according to official Microsoft ODT documentation.
3. **Adding Custom Software**: Open `modules\software.ps1` and add new functions using the `Invoke-DownloadWithProgress` and `Invoke-InstallWithProgress` helpers.

---

## 📄 License & Disclaimer

Designed and engineered for enterprise automation and personal deployment speed. Use at your own discretion after reviewing your organizational policies regarding Group Policy modifications.
