# ==============================================================================
# SACIID WINDOWS SETUP - BROWSERS & EXTENSIONS MODULE
# File: modules/browsers.ps1
# Description: Configures Group Policy registry overrides to force-install
#              uBlock Origin Lite in Chrome and uBlock Origin in Edge.
#              Disables Edge telemetry, shopping, feeds, Copilot, and bloatware.
#              Sets or prompts Chrome as default browser.
# ==============================================================================

<#
.SYNOPSIS
    Configures Chrome registry policies (uBlock Origin Lite) and default browser behavior.
#>
function Set-ChromePoliciesAndDefaults {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                CONFIGURING GOOGLE CHROME POLICIES & DEFAULTS                 " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Log -Message "Configuring Chrome extension force-install policies..." -Level "INFO"

    $chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    if (-not (Test-Path $chromePolicyPath)) {
        New-Item -Path $chromePolicyPath -Force | Out-Null
    }

    # Force install uBlock Origin Lite (Extension ID: ddkjiahejlhfcokbknmiheckhfglcaec)
    try {
        Set-ItemProperty -Path $chromePolicyPath -Name "1" -Value "ddkjiahejlhfcokbknmiheckhfglcaec;https://clients2.google.com/service/update2/crx" -Force
        Write-Log -Message "Force-installed uBlock Origin Lite for Google Chrome via Registry Policy." -Level "SUCCESS"
        Add-ResultEntry -Name "Chrome Extensions" -Status "Installed" -Message "uBlock Origin Lite configured via Group Policy."
    }
    catch {
        Write-Log -Message "Failed to set Chrome ExtensionInstallForcelist policy: $($_.Exception.Message)" -Level "ERROR"
        Add-ResultEntry -Name "Chrome Extensions" -Status "Failed" -Message "Failed to set uBlock Origin Lite registry policy."
    }

    # Default Browser Configuration
    Write-Log -Message "Checking default browser configuration..." -Level "INFO"
    $chromeExe = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
    if (-not (Test-Path $chromeExe)) {
        $chromeExe = "${env:ProgramFiles (x86)}\Google\Chrome\Application\chrome.exe"
    }

    if (Test-Path $chromeExe) {
        # Windows 10/11 uses cryptographic UserChoice hashes preventing direct registry tampering for protocol associations.
        # We attempt programmatical setting if supported, or open Default Apps window gracefully.
        try {
            Write-Log -Message "Opening Windows Default Apps Settings page for user verification..." -Level "INFO"
            Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue
            Write-Host ""
            Write-Host " [!] Windows restrictions prevent background protocol hijacking without user consent." -ForegroundColor Yellow
            Write-Host "     Please select 'Google Chrome' and click 'Set default' in the opened settings window." -ForegroundColor Yellow
            Write-Host ""
            Add-ResultEntry -Name "Chrome Default Browser" -Status "Installed" -Message "Default Apps settings opened for Chrome selection."
        }
        catch {
            Write-Log -Message "Could not launch ms-settings:defaultapps: $($_.Exception.Message)" -Level "WARN"
        }
    }
    else {
        Write-Log -Message "Google Chrome executable not found. Skipping default browser configuration." -Level "SKIP"
    }
}

<#
.SYNOPSIS
    Configures Edge extension policies (uBlock Origin) and disables feeds/sidebar/copilot.
#>
function Set-EdgePoliciesAndTweaks {
    [CmdletBinding()]
    param ()

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                CONFIGURING MICROSOFT EDGE POLICIES & DEBLOAT                 " -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Log -Message "Configuring Microsoft Edge Group Policy overrides..." -Level "INFO"

    # 1. Force Install uBlock Origin (Extension ID: odfsieeiaaieiocijainopjmedgpbfaie)
    $edgeExtPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    if (-not (Test-Path $edgeExtPolicyPath)) {
        New-Item -Path $edgeExtPolicyPath -Force | Out-Null
    }

    try {
        Set-ItemProperty -Path $edgeExtPolicyPath -Name "1" -Value "odfsieeiaaieiocijainopjmedgpbfaie;https://edge.microsoft.com/extensionwebstorebase/v1/crx" -Force
        Write-Log -Message "Force-installed uBlock Origin for Microsoft Edge via Registry Policy." -Level "SUCCESS"
        Add-ResultEntry -Name "Edge Extensions" -Status "Installed" -Message "uBlock Origin configured via Group Policy."
    }
    catch {
        Write-Log -Message "Failed to set Edge ExtensionInstallForcelist policy: $($_.Exception.Message)" -Level "ERROR"
        Add-ResultEntry -Name "Edge Extensions" -Status "Failed" -Message "Failed to set uBlock Origin registry policy."
    }

    # 2. Disable Edge Telemetry, Feeds, Sidebar, Shopping, Copilot, and Promotions
    $edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    if (-not (Test-Path $edgePolicyPath)) {
        New-Item -Path $edgePolicyPath -Force | Out-Null
    }

    $edgePolicies = @{
        # Shopping & Recommendations
        "EdgeShoppingAssistantEnabled"              = 0
        "ShowRecommendationsEnabled"               = 0
        "PersonalizationReportingEnabled"          = 0
        "PromotionsEnabled"                        = 0
        # Sidebar & Web Widgets
        "HubsSidebarEnabled"                       = 0
        "WebWidgetAllowed"                         = 0
        "StandaloneHubsSidebarEnabled"             = 0
        # Copilot & Discover Feed
        "DiscoverPageContextEnabled"               = 0
        "EdgeCopilotEnabled"                       = 0
        # Start Feed, News Feed, Sponsored Content & Quick Links
        "NewTabPageLocation"                       = "about:blank"
        "NewTabPagePrerenderEnabled"               = 0
        "NewTabPageQuickLinksEnabled"              = 0
        "NewTabPageContentCustomizationEnabled"    = 0
        # Microsoft Rewards & Office Recommendations
        "ShowMicrosoftRewards"                     = 0
        "MicrosoftOfficeMenuEnabled"               = 0
        "UserExperienceImprovementProgramEnabled"  = 0
        # Additional Privacy & Clutter
        "AlternateErrorPagesEnabled"               = 0
        "AutofillCreditCardEnabled"                = 0
    }

    $successCount = 0
    foreach ($policy in $edgePolicies.GetEnumerator()) {
        try {
            if ($policy.Value -is [string]) {
                Set-ItemProperty -Path $edgePolicyPath -Name $policy.Key -Value $policy.Value -Type String -Force | Out-Null
            }
            else {
                Set-ItemProperty -Path $edgePolicyPath -Name $policy.Key -Value $policy.Value -Type DWord -Force | Out-Null
            }
            $successCount++
        }
        catch {
            Write-Log -Message "Could not set Edge policy $($policy.Key): $($_.Exception.Message)" -Level "WARN"
        }
    }

    if ($successCount -gt 0) {
        Write-Log -Message "Successfully applied $successCount Edge debloat and privacy Group Policies." -Level "SUCCESS"
        Add-ResultEntry -Name "Edge Debloat Policies" -Status "Installed" -Message "Disabled Feeds, Shopping, Copilot, Sidebar, and Rewards."
    }
    else {
        Add-ResultEntry -Name "Edge Debloat Policies" -Status "Failed" -Message "Failed to apply Edge Group Policies."
    }
}

<#
.SYNOPSIS
    Wrapper function to run all browser extension configurations and debloat policies.
#>
function Configure-Browsers {
    [CmdletBinding()]
    param ()

    Set-ChromePoliciesAndDefaults
    Set-EdgePoliciesAndTweaks
}
