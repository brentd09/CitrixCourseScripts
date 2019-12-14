
#Requires -Version 3.0

# Citrix Storefront Configurator
# Jacob Rutski
# jake@serioustek.net
# http://blogs.serioustek.net
# @JRutski on Twitter
# Created on August 24th, 2015
# Current version 0.8
#
# Version 0.1 (Beta)
#-Primarily supports SF3.0; some features disabled if older versions detected; Only tested on 3.0 thus far
#-SF powershell is only used to reset SF; otherwise, all settings are 'brute force' string manipulation of the web.config files
#-Simple workflow handler does not currently download the required DLL from Citrix as it is a ShareFile link
#-Custom header insert does not currently support multiple custom headers
#
# Version 0.2 (Beta)
#-Added support to read existing store configuration
#-Added type and keyword filter support
#-Added SF PoSH SDK for more accurate configuration when available (2.5+)
#
# Version 0.3 (Beta)
#-Fixed propagate changes check; set -confirm:$false
#-Added Tabs; set functionality and UI tabs
#-Numerous bugfixes - including WebStorePath
#
# Version 0.4 (Beta)
#-Added click-through disclaimer functionality
#-Added footer functionality
#-Fixed several extra white space issues
#
# Version 0.5 (Beta)
#-Added workspace control buttons
#-Set web.config to use [XML] type since it looks like the paths don't change between versions ([Regex]::Escape)
#-Added feature parity with previous Citrix tool
#
# Version 0.55 (Beta)
#-Bug fix for Storefront 2.1 - 2.6 not having the 'friendly name' property exposed in Get-DSStores used to get virtual path
#-Bug fix for XML being overwritten by buffer after applying filter settings
#
# Version 0.56 (Beta)
#-Bug fix for default document hard code
#
# Version 0.6 (Beta)
#-Fix to enable multi-language support with Unicode output
#-Add event logging
#-Fix for default document overwrite
#-CRL .NET framework config in XML, overwrite fixed
#
# Version 0.7 (Beta)
#-Fix hardcoded SiteID
#-Added Optimal Gateway Routing functionality
#
# Version 0.8 (Beta)
#-Some Form and functions cleanup
#-Added single FQDN functionality
#-Added MultiSite UI; functionality not ready
#
# Version 0.81 (Beta)
#-Fixed optimal gateway disable
#-Multisite basic functionality to build XML; does not read existing config or disable
#
# Version 1.0
#-Multisite functionality completed

# Check for root
# http://blogs.technet.com/b/heyscriptingguy/archive/2011/05/11/check-for-admin-credentials-in-a-powershell-script.aspx
If(!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Host "`nThis script is not running as administrator - this is required to modify configuration files.`n"
    Exit
}

# Get Citrix Storefront version
[version]$strCurrentStorefront = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where {$_.DisplayName -eq "Citrix Storefront"} | Select -Unique).DisplayVersion

# Exit if Storefront not found
If(!($strCurrentStorefront)){[System.Windows.Forms.MessageBox]::Show("Citrix Storefront not found." , "Status"); Exit}

# Load Citrix SF SDK
$SFInstallPath = (Get-ItemProperty -Path HKLM:\SOFTWARE\Citrix\DeliveryServicesManagement -Name InstallDir).InstallDir
& $SFInstallPath\..\Scripts\ImportModules.ps1

# Find SF Stores and base URL by PS SDK
$script:ctxSFStores = (Get-DSWebSite).Applications
$script:ctxSiteID = (Get-DSWebSite).Id
$script:strBaseURL = (Get-DSHostBaseUrl | Where {$_.siteID -eq $script:ctxSiteID}).hostBaseUrl

$script:boolCategories = $false
$script:boolDynHeader = $false
$script:boolDisclaimerWeb = $false
$script:boolDisclaimerCAG = $false
$script:boolFooter = $false
$script:modFiles = @()
$script:strCurrentStore = ""
$script:strCurrentWebStore = ""
$script:objSFGateways = ""
$script:objSFFarms = ""
$script:storeVirtPath = ""
$script:boolGWUpdate = $false
$script:boolSingleFQDN = $false
$script:boolMultiSite = $false
[xml]$script:currentStoreXML = ""
[xml]$script:currentWebStoreXML = ""

#region Functions

Function Set-SFCInit
{
    
    # Disable items until store is selected
    $checkDefaultDoc.Enabled = $false
    $comboWebTabs.Enabled = $false
    $checkCategories.Enabled = $false
    $checkWorkflow.Enabled = $false
    $checkNative.Enabled = $false
    $checkCRL.Enabled = $false
    $checkLaunch.Enabled = $false
    $checkWorkspace.Enabled = $false
    $checkCustomHeader.Enabled = $false
    $checkKeyFilter.Enabled = $false
    $comboKeyFilter.Enabled = $false
    $checkTypeApps.Enabled = $false
    $checkTypeDesk.Enabled = $false
    $checkTypeDocs.Enabled = $false
    $checkDynHeader.Enabled = $false
    $labelTypeFilter.Enabled = $false
    $groupDisclaimer.Enabled = $false
    $groupFooter.Enabled = $false
    $checkWSCReconnect.Enabled = $false
    $checkWSCDisconnect.Enabled = $false
    $checkSFR.Enabled = $false
    $checkAppsView.Enabled = $false
    $checkDesktopView.Enabled = $false
    $checkWSCEnable.Enabled = $false
    $textLogonTimeout.Enabled = $false
    $checkHTMLTab.Enabled = $false
    $textMultiClick.Enabled = $false
    $checkAppCatView.Enabled = $false
    $checkPluginUpgrade.Enabled = $false
    $checkSingleFQDN.Enabled = $false
    $textSingleFQDN.Enabled = $false
    $checkMultiEnable.Enabled = $false
    $linkAddFarmMapping.Enabled = $false
    
}

Function Get-SFCStoreFromWeb
{
    Param([string]$fileName="")

    # xml.configuration.'citrix.deliveryservices'.webReceiver.serverSettings.discoveryService.url
    # $strDiscovery = (Get-Content "$($fileName)\web.config" | Select-String '<discoveryService url' -SimpleMatch).ToString()
    $strDiscovery = $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.serverSettings.discoveryService.url
    [int]$leftIndex = $strDiscovery.IndexOf("/Citrix") + 8
    return $strDiscovery.Substring($leftIndex, ($strDiscovery.IndexOf("/discovery") - $leftIndex))
}

Function Get-SFCStoreConfig
{
    # Set stores, script XML variables
    $script:strCurrentWebStore = ($script:ctxSFStores | Where {$_.Name -eq $listWebStores.SelectedItem.ToString()}).Folder
    [xml]$script:currentWebStoreXML = (Get-Content "$($script:strCurrentWebStore)\web.config")
    $script:servicesStore = Get-SFCStoreFromWeb -fileName $strCurrentWebStore
    $script:strCurrentStore = ($script:ctxSFStores | Where {$_.Name -eq $servicesStore}).Folder
    [xml]$script:currentStoreXML = (Get-Content "$($script:strCurrentStore)\web.config")
    $ReceiverLabel.Text = "Receiver Store: $($script:servicesStore)"
    $script:storeVirtPath = ($script:ctxSFStores | Where {$_.Name -eq $script:servicesStore}).VirtualPath
   
    # Get auto launch desktop setting
    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.autoLaunchDesktop)){$checkLaunch.Checked = $true}Else{$checkLaunch.Checked = $false}
    $checkLaunch.Enabled = $true

    # Get framework config
    [xml]$frameworkConfig = Get-Content 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\Aspnet.config'
    If($frameworkConfig.configuration.runtime.generatePublisherEvidence){$checkCRL.Checked = $true}
    $checkCRL.Enabled = $true

    # Get Receiver deployment location
    If($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.win32.path -eq "clients/Windows/CitrixReceiver.exe"){$checkNative.Checked = $true}Else{$checkNative.Checked = $false}
    $checkNative.Enabled = $true

    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.upgradeAtLogin))
    {$checkPluginUpgrade.Checked = $true}Else{$checkPluginUpgrade.Checked = $false}
    $checkPluginUpgrade.Enabled = $true

    # Get desktop and apps tabs enabled
    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.showDesktopsView))
    {$checkDesktopView.Checked = $true}Else{$checkDesktopView.Checked = $false}; $checkDesktopView.Enabled = $true

    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.showAppsView))
    {$checkAppsView.Checked = $true}Else{$checkAppsView.Checked = $false}; $checkAppsView.Enabled = $true

    # Get default tab
    $storeDefaultView = $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.defaultView
    Switch ($storeDefaultView)
    {
        "Favorites"{$comboWebTabs.SelectedItem = $comboWebTabs.Items[0]}
        "Desktops"{$comboWebTabs.SelectedItem = $comboWebTabs.Items[1]}
        "Apps"{$comboWebTabs.SelectedItem = $comboWebTabs.Items[2]}
        "Auto"{$comboWebTabs.SelectedItem = $comboWebTabs.Items[3]}
    }
    $comboWebTabs.Enabled = $true

    # Storefront 3.0 specific items - Get apps categories - code in \custom\script.js
    If($strCurrentStorefront -gt [version]"3.0")
    {

        $checkKeyFilter.Enabled = $true
        $labelTypeFilter.Enabled = $true
        $checkTypeApps.Enabled = $true
        $checkTypeDesk.Enabled = $true
        $checkTypeDocs.Enabled = $true
        $checkCategories.Enabled = $true
        $checkWorkflow.Enabled = $true
        $checkCustomHeader.Enabled = $true
        $checkDynHeader.Enabled = $true
        $groupDisclaimer.Enabled = $true
        $groupFooter.Enabled = $true

        # Get App category view
        If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.enableAppsFolderView)){$checkAppCatView.Checked = $true}Else{$checkAppCatView.Checked = $false}
        $checkAppCatView.Enabled = $true

        $storeTypeFilter = Get-DSResourceFilterType -SiteId $script:ctxSiteID -VirtualPath $script:storeVirtPath
        If((Get-DSResourceFilterKeyword -SiteId $script:ctxSiteID -VirtualPath $script:storeVirtPath).Include){$storeKeyFilterInc = $true; $storeKeyFilter = (Get-DSResourceFilterKeyword -SiteId $script:ctxSiteID -VirtualPath $script:storeVirtPath).Include}
        Else{$storeKeyFilterInc = $false; $storeKeyFilter = (Get-DSResourceFilterKeyword -SiteId $script:ctxSiteID -VirtualPath $script:storeVirtPath).Exclude}
    
        # Set filters form
        If($storeKeyFilter)
        {
            $checkKeyFilter.Checked = $true; $textKeyFilter.Text = $storeKeyFilter -join ", "; $textKeyFilter.Enabled = $true; $comboKeyFilter.Enabled = $true
            If($storeKeyFilterInc){$comboKeyFilter.SelectedItem = $comboKeyFilter.Items[1]}Else{$comboKeyFilter.SelectedItem = $comboKeyFilter.Items[0]}
        }
        Else{$textKeyFilter.Text ="";$checkKeyFilter.Checked = $false;$textKeyFilter.Enabled = $false; $comboKeyFilter.Enabled = $false}
        If("Applications" -in $storeTypeFilter){$checkTypeApps.Checked = $true}Else{$checkTypeApps.Checked = $false}
        If("Desktops" -in $storeTypeFilter){$checkTypeDesk.Checked = $true}Else{$checkTypeDesk.Checked = $false}
        If("Documents" -in $storeTypeFilter){$checkTypeDocs.Checked = $true}Else{$checkTypeDocs.Checked = $false}

        If(Get-Content "$($strCurrentWebStore)\custom\script.js" | Select-String 'CTXS.ExtensionAPI.navigateToFolder(''/'');' -SimpleMatch)
        {
            $checkCategories.Checked = $true
            $comboWebTabs.Enabled = $false
            $script:boolCategories = $true
        }
        Else
        {$checkCategories.Checked = $false}

        # Get Simple workflow handler
        If($script:currentStoreXML.configuration.container.components.component.id -contains 'SimpleWorkflowHandler')
        {$checkWorkflow.Checked = $true}
        Else{$checkWorkflow.Checked = $false}

        # Get DynHeader SF3
        If(Get-Content "$($strCurrentWebStore)\custom\script.js" | Select-String 'function setDynamicContent(txtFile, element) {' -SimpleMatch)
        {
            $checkDynHeader.Checked = $true
            $script:boolDynHeader = $true
        }
        Else{$checkDynHeader.Checked = $false}

        # Get click through disclaimer data
        # Web only disclaimer - pre-logon
        $disclaimer = Get-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -locater 'CTXS.Extensions.beforeLogon = function (callback) {'
        If($disclaimer.Enabled)
        {
            $checkDisclaimerWeb.Checked = $true
            $textDisclaimerTitle.Text = $disclaimer.Title
            $textDisclaimerButton.Text = $disclaimer.Button
            $textDisclaimerMsg.Text = $disclaimer.Text 
            $checkDisclaimerScrollWeb.Checked = $disclaimer.Scroll
            $script:boolDisclaimerWeb = $true  
                
        }
        Else
        {
            $checkDisclaimerWeb.Checked = $false
            $textDisclaimerTitle.Text = ""
            $textDisclaimerButton.Text = ""
            $textDisclaimerMsg.Text = ""

        }

        # CAG disclaimer - post-logon
        $disclaimerCAG = Get-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -locater 'CTXS.Extensions.beforeDisplayHomeScreen = function (callback) {'
        If($disclaimerCAG.Enabled)
        {
            $checkDisclaimerCAG.Checked = $true
            $textDisclaimerTitleCAG.Text = $disclaimerCAG.Title
            $textDisclaimerButtonCAG.Text = $disclaimerCAG.Button
            $textDisclaimerMsgCAG.Text = $disclaimerCAG.Text
            $script:boolDisclaimerCAG = $true
             
        }
        Else
        {
            $checkDisclaimerCAG.Checked = $false
            $textDisclaimerTitleCAG.Text = ""
            $textDisclaimerButtonCAG.Text = ""
            $textDisclaimerMsgCAG.Text = ""

        }

        Validate-SFCClickThrough

        # All pages footer
        $footer = Get-SFCFooter -fileName "$($strCurrentWebStore)\custom\script.js"
        If($footer.Enabled)
        {
            $checkFooter.Checked = $true
            $textFooterMsg.Text = $footer.Text
            $textFooterSize.Text = $footer.Size
            $textFooterColor.Text = $footer.Color
            $script:boolFooter = $true
        }
        Else
        {
            $checkFooter.Checked = $false
            $textFooterMsg.Text = ""
            $textFooterSize.Text = ""
            $textFooterColor.Text = ""
        }

        Validate-SFCFooter
    }

    # HTML5 single tab
    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.html5.singleTabLaunch))
    {$checkHTMLTab.Checked = $true}Else{$checkHTMLTab.Checked = $false}
    $checkHTMLTab.Enabled = $true
    $checkDefaultDoc.Enabled = $true

    # Get WSC Enable
    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.enabled))
    {$checkWSCEnable.Checked = $true; $comboWSCLogoff.Enabled = $true}Else{$checkWSCEnable.Checked = $false; $comboWSCLogoff.Enabled = $false}
    $checkWSCEnable.Enabled = $true

    # Get WSC auto reconnect
    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.autoReconnectAtLogon))
    {$checkWorkspace.Checked = $true}Else{$checkWorkspace.Checked = $false}
    $checkWorkspace.Enabled = $true

    # Get WSC Show reconnect
    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.showReconnectButton))
    {$checkWSCReconnect.Checked = $true}Else{$checkWSCReconnect.Checked = $false}
    $checkWSCReconnect.Enabled = $true
    
    # Get WSC Show disconnect
    If([System.Convert]::ToBoolean($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.showDisconnectButton))
    {$checkWSCDisconnect.Checked = $true}Else{$checkWSCDisconnect.Checked = $false}
    $checkWSCDisconnect.Enabled = $true

    # Get WSC logoff action
    switch($script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.logoffAction)
    {
        "disconnect"{$comboWSCLogoff.SelectedItem = $comboWSCLogoff.Items[0]}
        "none"{$comboWSCLogoff.SelectedItem = $comboWSCLogoff.Items[1]}
        "terminate"{$comboWSCLogoff.SelectedItem = $comboWSCLogoff.Items[2]}
    }

    # Get SFR
    If($script:currentStoreXML.configuration.'citrix.deliveryservices'.wing.resources.ChildNodes.launch.allowSpecialFolderRedirection -eq "on")
    {$checkSFR.Checked = $true}Else{$checkSFR.Checked = $false}
    $checkSFR.Enabled = $true

    # Get logon and multiclick timeout; MultiSite\HA
    $textLogonTimeout.Text = $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.authManager.loginFormTimeout
    $textLogonTimeout.Enabled = $true
    If($strCurrentStorefront -gt [version]"2.5")
    {
        $textMultiClick.Text = $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.multiClickTimeout
        $textMultiClick.Enabled = $true

        # Get data for MultiSite
        $script:objSFFarms = (Get-DSFarmSets -IISSiteId $script:ctxSiteID -VirtualPath $script:storeVirtPath).Farms
        $checkMultiEnable.Enabled = $true
        If(Test-Path Variable:script:intFarmMappings)
        {
            for($i = 0; $i -le $script:intFarmMappings; $i++)
            {
                $multiTab.Controls.Remove((gv "groupFarmMap$i").Value)
                (gv "groupFarmMap$i").Value = $null
                (gv "intMapEFS$i").Value = $null
            }

            Remove-Variable 'intFarmMappings' -Scope 'Script'
        }
        If($script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings)
        {
            $script:boolMultiSite = $true
            $checkMultiEnable.Checked = $true
            $linkAddFarmMapping.Enabled = $true
            Get-SFCMultiSite
        }
        Else
        {
            $script:boolMultiSite = $false
            $checkMultiEnable.Checked = $false
            $linkAddFarmMapping.Enabled = $false
        }
    }

    # Get data for Optimal Gateway, Single FQDN
    If($strCurrentStorefront -gt [version]"2.6")
    {
        $script:objSFGateways = (Get-DSGlobalGateways).Gateways
        $optGWGroup.Enabled = $true
        $checkGWEnable.Checked = $false
        $comboGWName.Items.Clear()
        Validate-SFCOptimalGW "init"
        Foreach($gwName in $script:objSFGateways.Name)
        {
            [void] $comboGWName.Items.Add($gwName)
        }
        $storeOptimalGW = Get-DSOptimalGatewayForFarms -SiteId $script:ctxSiteID -ResourcesVirtualPath $script:storeVirtPath
        If($storeOptimalGW)
        {
            $script:boolGWUpdate = $true
            $checkGWEnable.Checked = $true
            $comboGWName.Enabled = $true
            $i = 0
            foreach($comboItem in $comboGWName.Items)
            {
                If($comboItem -eq $storeOptimalGW.GatewayName)
                {$comboGWName.SelectedIndex = $i}
                Else{$i++}
            }
            $textGWBypass.Text = $storeOptimalGW.StasBypassDuration
            If([System.Convert]::ToBoolean($storeOptimalGW.EnableSessionReliability)){$checkGWSR.Checked = $true}Else{$checkGWSR.Checked = $false}
            If([System.Convert]::ToBoolean($storeOptimalGW.StasUseLoadBalancing)){$checkGWUseLB.Checked = $true}Else{$checkGWUseLB.Checked = $false}
            If([System.Convert]::ToBoolean($storeOptimalGW.UseTwoTickets)){$checkGWTwoSTA.Checked = $true}Else{$checkGWTwoSTA.Checked = $false}
            If([System.Convert]::ToBoolean($storeOptimalGW.EnabledOnDirectAccess)){$checkGWDirect.Checked = $true}Else{$checkGWDirect.Checked = $false}
        }

        $checkSingleFQDN.Enabled = $true
        $singleFQDNURL = Get-SFCSingleFQDN
        If($singleFQDNURL)
        {
            $checkSingleFQDN.checked = $true
            $textSingleFQDN.Text = $singleFQDNURL
            $textSingleFQDN.Enabled = $true
            $script:boolSingleFQDN = $true
        }
        Else
        {
            $checkSingleFQDN.checked = $false
            $textSingleFQDN.Enabled = $false
            $textSingleFQDN.Text = ''
        }
    }
    
}

Function Add-SFCDefaultDocument
{
#------------------
# Create SFDefault.html per CTX133903
# Write SFDefault.html to C:\Inetpub\wwwroot
# Configure as new default page in IIS

    If(!(Test-Path 'C:\inetpub\wwwroot\SFDefault.html'))
    {
        New-Item C:\inetpub\wwwroot\SFDefault.html -ItemType file

        $IISString = @"
<script type="text/javascript">
<!--
window.location="/Citrix/$($listWebStores.SelectedItem.ToString())";
// -->
</script>
"@

        $IISString | Out-File "C:\inetpub\wwwroot\SFDefault.html"

        $filter = "system.webserver/defaultdocument/files"        $site = "IIS:\sites\Default Web Site"        $file = "SFDefault.html"
        If ([Environment]::OSVersion.Version.Build -ne 7601)
        {
            Add-WebConfiguration $filter "$site" -Value @{value=$file}
        }
        Else
        {
        $strCmd = @"
C:\Windows\System32\inetsrv\appcmd.exe set config "Default Web Site" /section:defaultDocument "/+files.[@start,value='SFDefault.html']"
"@

            iex $strCmd
        }
    }
    Else
    {
        $IISString = @"
<script type="text/javascript">
<!--
window.location="/Citrix/$($listWebStores.SelectedItem.ToString())";
// -->
</script>
"@

        $IISString | Out-File "C:\inetpub\wwwroot\SFDefault.html"
    }

}

Function Remove-SFCFileString
{
    Param([string]$findString="",
        [string]$fileName="")

    (Get-Content $fileName) | Select-String -Pattern ([regex]::Escape($findString)) -NotMatch | Set-Content $fileName
}

Function Get-SFCCustomCode
{
    # Loop through lines looking for Reference; once past reference, look for value; If comment start found, keep reading until comment end
}

Function Set-SFCCRLCheck
{
    Param([bool]$enable)

    Add-PSSnapin Citrix.DeliveryServices.Framework.Commands
    $framework32File = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet.config'
    $framework64File = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet.config'
    If($enable)
    {
        If(!([xml](Get-content $framework32File)).configuration.runtime.generatePublisherEvidence)
        {
            Set-DSAssemblyVerification $false

            Backup-SFCFile $framework32File
            [xml]$frameworkXML = Get-Content $framework32File
            $newComponent = $frameworkXML.CreateElement('generatePublisherEvidence')
            $newComponent.SetAttribute('enabled','false')
            $frameworkXML.configuration.runtime.AppendChild($newComponent)
            $frameworkXML.Save($framework32File)
        }
        If(!([xml](Get-content $framework64File)).configuration.runtime.generatePublisherEvidence)
        {
            Backup-SFCFile $framework64File
            [xml]$frameworkXML = Get-Content $framework64File
            $newComponent = $frameworkXML.CreateElement('generatePublisherEvidence')
            $newComponent.SetAttribute('enabled','false')
            $frameworkXML.configuration.runtime.AppendChild($newComponent)
            $frameworkXML.Save($framework64File)
        }
    }
    Else
    {
        If(([xml](Get-content $framework32File)).configuration.runtime.generatePublisherEvidence -and ([xml](Get-content $framework64File)).configuration.runtime.generatePublisherEvidence)
        {
            Set-DSAssemblyVerification $true
            Backup-SFCFile $framework32File
            [xml]$frameworkXML = Get-Content $framework32File
            $deleteNode = $frameworkXML.configuration.runtime.generatePublisherEvidence
            $frameworkXML.configuration.runtime.RemoveChild($deleteNode)
            $frameworkXML.Save($framework32File)

            Backup-SFCFile $framework64File
            [xml]$frameworkXML = Get-Content $framework64File
            $deleteNode = $frameworkXML.configuration.runtime.generatePublisherEvidence
            $frameworkXML.configuration.runtime.RemoveChild($deleteNode)
            $frameworkXML.Save($framework64File)
        }
    }

}

Function Add-SFCForwardHeader
{
    Param([string]$fileName="",
        [string]$strHeader="")

    Backup-SFCFile $fileName

    $newStr = "<forwardedHeaders>$([char]10)<header name=`"$strHeader`" />$([char]10)</forwardedHeaders>"

    (Get-Content $fileName) | ForEach-Object {$_
        if($_ -match 'loopbackPortUsingHttp'){ $newStr } } | Set-Content $fileName -Encoding Unicode
}

Function Enable-SFCSimpleWorkflow
{
    Param([string]$fileName="",
        [bool]$enable)
    
    If($enable)
    {
        If(!($script:currentStoreXML.configuration.container.components.component.id -contains 'SimpleWorkflowHandler'))
        {
            [object]$template = $script:currentStoreXML.configuration.container.components.component | Where-Object {$_.Id -eq "webApplicationStartupModule"}
            $newComponent = $template.Clone()
            $newComponent.Id = "SimpleWorkflowHandler"
            $newComponent.type = "Citrix.DeveloperNetwork.StoreFront.SimpleWorkflowHandler, SimpleWorkflowHandler"
            $newComponent.service = "Citrix.DeliveryServices.DazzleResources.Workflow.IWorkflowAdaptor, Citrix.DeliveryServices.DazzleResources.Workflow"
            $script:currentStoreXML.configuration.container.components.AppendChild($newComponent)
        }
    }
    Else
    {
        If($script:currentStoreXML.configuration.container.components.component.id -contains 'SimpleWorkflowHandler')
        {
            $deleteNode = $script:currentStoreXML.configuration.container.components.component | Where-Object {$_.id -eq "SimpleWorkflowHandler"}
            $script:currentStoreXML.configuration.container.components.RemoveChild($deleteNode)
        }
    }
}

Function Deploy-SFCReceivers
{
    param([string]$fileName,
        [string]$receiverLocation="")

    If($receiverLocation -eq "Citrix")
    {
        # Backup-SFCFile
        # Replace-SFCValue -findValue '<win32 path' -setValue 'http://downloadplugins.citrix.com/Windows/CitrixReceiverWeb.exe' -fileName $fileName
        # Replace-SFCValue -findValue '<macOS path' -setValue 'http://downloadplugins.citrix.com/Mac/CitrixReceiverWeb.dmg' -fileName $fileName 
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.win32.path = "http://downloadplugins.citrix.com/Windows/CitrixReceiverWeb.exe"
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.macOS.path = "http://downloadplugins.citrix.com/Mac/CitrixReceiverWeb.dmg"
               
    }
    Else
    {
        # Create directories
        If(!(Test-Path 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Mac') -or !(Test-Path 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Windows'))
        {
            New-Item -ItemType Directory -Path 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Windows' -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Mac' -ErrorAction SilentlyContinue
        }

        # Download latest Receiver from Citrix
        If(!(Test-Path 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Windows\CitrixReceiver.exe') -or !(Test-Path 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Mac\CitrixReceiver.dmg'))
        {
            Invoke-WebRequest http://downloadplugins.citrix.com/Windows/CitrixReceiverWeb.exe -outfile 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Windows\CitrixReceiver.exe'
            Invoke-WebRequest http://downloadplugins.citrix.com/Mac/CitrixReceiverWeb.dmg -outfile 'C:\Program Files\Citrix\Receiver StoreFront\Receiver Clients\Mac\CitrixReceiver.dmg'
        }

        # set configuration web.config
        # Backup-SFCFile $fileName
        # Replace-SFCValue -findValue '<win32 path' -setValue 'clients/Windows/CitrixReceiver.exe' -fileName $fileName
        # Replace-SFCValue -findValue '<macOS path' -setValue 'clients/Mac/CitrixReceiver.dmg' -fileName $fileName
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.win32.path = "clients/Windows/CitrixReceiver.exe"
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.macOS.path = "clients/Mac/CitrixReceiver.dmg"

    }
}

Function Reset-SFCStorefront
{
    foreach($mmcProcess in (get-process -Name mmc)){Stop-Process $mmcProcess.id}
    Clear-DSConfiguration

}

Function Set-SFCAppCategories
{
    param([string]$fileName,
        [bool]$enable)

    If($enable -and $boolCategories)
    {
        return;
    }
    ElseIf($enable)
    {
        Backup-SFCFile $fileName
        $newString = @"
CTXS.Extensions.afterDisplayHomeScreen = function (callback) {
     CTXS.ExtensionAPI.navigateToFolder('/'); };

"@

        Add-Content $fileName $newString
    }
    Else
    {
        Backup-SFCFile $fileName
        Remove-SFCFileString -fileName $fileName -findString 'CTXS.Extensions.afterDisplayHomeScreen = function (callback) {'
        Remove-SFCFileString -fileName $fileName -findString 'CTXS.ExtensionAPI.navigateToFolder(''/''); };'
    }
}

Function Validate-SFCAppCategories
{
    # Validation for App Categories
    If($checkCategories.Checked)
    {
        $comboWebTabs.SelectedItem = $comboWebTabs.Items[2]
        $comboWebTabs.Enabled = $false
        $checkAppCatView.Checked = $true
        $checkAppCatView.Enabled = $false
    }
    Else
    {
        $comboWebTabs.Enabled = $true
        $checkAppCatView.Enabled = $true
    }

    If($checkAppCatView.Checked)
    {
        $checkCategories.Enabled = $true
    }
    Else
    {
        $checkCategories.Enabled = $false
        $checkCategories.Checked = $false
    }
}

Function Remove-SFCParagraph
{
    Param([string]$fileName="",
        [string]$textStart="",
        [string]$textEnd="")

        [bool]$startLocate = $false
        $newFile = ''
        $i = 1

        $modFile = (Get-Content $fileName)
        foreach($line in $modFile)
        {
            If($line.Contains("/*")){$inComment = $true}
            If($line.Contains($textStart) -and !($inComment)){$startLocate = $true}
            If(!($startLocate))
            {
                $newFile += $line
                If($i -lt $modFile.Count){$newFile += "`r`n"}
            }
            If($line.Contains($textEnd)){$startLocate = $false}
            If($line.Contains("*/")){$inComment = $false}
            $i++
        }

        $newFile | Set-Content $fileName
}

Function Set-SFCDynHeader
{
    Param([string]$fileName="",
        [bool]$enable)

    # Enables dynamic header to read from \customweb\Readme.txt
    If($enable -and $script:boolDynHeader)
    {
        return;
    }
    ElseIf($enable)
    {
        $strCode = @"
function setDynamicContent(txtFile, element) {
   CTXS.ExtensionAPI.proxyRequest({
      url: "customweb/"+txtFile,
      success: function(txt) {`$(element).html(txt);}});
}

var fetchedContent=false;
function doFetchContent(callback)
{
  if(!fetchedContent) {
    fetchedContent = true;
    setDynamicContent("ReadMe.txt", "#customScrollTop");
  }
  callback();
}

CTXS.Extensions.beforeDisplayHomeScreen = doFetchContent;
CTXS.Extensions.beforeLogon = doFetchContent;

"@

        Backup-SFCFile $fileName
        Add-Content $fileName $strCode
    }
    Else
    {
        Backup-SFCFile $fileName
        Remove-SFCParagraph -fileName $fileName -textStart 'function setDynamicContent(txtFile, element) {' -textEnd 'CTXS.Extensions.beforeLogon = doFetchContent;'
    }
}

Function Set-SFCClickThrough
{
    # Enables click through message either pre logon (web store only) or post auth (native receiver and CAG)
    # Actions: enable: writes function and sets values; update: updates values; disable: removes function
    # Location: web: writes beforeLogon function; cag: writes beforeDisplayHomeScreen function
    Param([string]$fileName="",
        [string]$action="",
        [string]$location="",
        [string]$title="",
        [string]$text="",
        [string]$button="",
        [bool]$scroll)

    $cssFile = $fileName.Replace('script.js','style.css')
    If($scroll){$text = "<div class=`'disclaimer`'>$($text)"}
    If($location -eq "web")
    {
        $strStart = 'CTXS.Extensions.beforeLogon = function (callback) {'
        $strFunction = @"
CTXS.Extensions.beforeLogon = function (callback) {
  doneClickThrough = true;
  CTXS.ExtensionAPI.showMessage({
    messageTitle: "$($title)",
    messageText: "$($text)",
    okButtonText: "$($button)",
    okAction: callback
  });
};    
"@
    }
    If($location -eq "cag")
    {
        $strStart = 'CTXS.Extensions.beforeDisplayHomeScreen = function (callback) {'
        $strFunction = @"
CTXS.Extensions.beforeDisplayHomeScreen = function (callback) {
  if (!doneClickThrough) {
    CTXS.ExtensionAPI.showMessage({
      messageTitle: "$($title)",
      messageText: "$($text)",
      okButtonText: "$($button)",
      okAction: callback
    });
  } else {
    callback();
  }
};
"@
    }
    
    switch ($action)
    {
        "enable"
        {
            # Check and insert CSS data if needed
            If(!((Get-Content $cssFile) | Select-String '.disclaimer' -SimpleMatch) -and $scroll)
            {
                $strCSSScroll = @"
.disclaimer {
    height: 200px;
    overflow-y: auto;
}
"@
                Backup-SFCFile $cssFile
                Add-Content $cssFile $strCSSScroll
            }

            Backup-SFCFile $fileName
            Add-Content $fileName $strFunction -Encoding Unicode
        }
        "update"
        {
            # Check and insert CSS data if needed
            If(!((Get-Content $cssFile) | Select-String '.disclaimer' -SimpleMatch) -and $scroll)
            {
                $strCSSScroll = @"

.disclaimer {
    height: 200px;
    overflow-y: auto;
}
"@
                Backup-SFCFile $cssFile
                Add-Content $cssFile $strCSSScroll
            }

            $newFile = ''
            $i = 1
            $updateFile = (Get-Content $fileName)
            foreach($line in $updateFile)
            {
                If($line.Contains("/*")){$inComment = $true}
                If($line.Contains($strStart)){$inFunction = $true}
                If(!($inComment) -and $inFunction)
                {
                    If($line.Contains('messageTitle:'))
                    {
                        $newFile += $line -replace "messageTitle: `".*?`"","messageTitle: `"$($title)`""
                        $newFile += "`r`n"
                    }
                    ElseIf($line.Contains('messageText:'))
                    {
                        $newFile += $line -replace "messageText: `".*?`"","messageText: `"$($text)`""
                        $newFile += "`r`n"
                    }
                    ElseIf($line.Contains('okButtonText:'))
                    {
                        $newFile += $line -replace "okButtonText: `".*?`"","okButtonText: `"$($button)`""
                        $newFile += "`r`n"
                    }
                    Else
                    {
                        $newFile += $line
                        $newFile += "`r`n"
                    }
                }
                Else
                {
                    $newFile += $line
                    If($i -lt $updateFile.Count){$newFile += "`r`n"}
                }
                If($line.Contains("*/")){$inComment = $false}
                If($line.Contains("};")){$inFunction = $false}
                $i++

            }
            Backup-SFCFile $fileName
            $newFile | Set-Content $fileName -Encoding Unicode
        }
        "disable"
        {
            Backup-SFCFile $fileName
            Remove-SFCParagraph -fileName $fileName -textStart $strStart -textEnd '};'

            Backup-SFCFile $cssFile
            Remove-SFCParagraph -fileName $cssFile -textStart '.disclaimer {' -textEnd '}'
        }
    }
}

Function Get-SFCClickThrough
{
    Param([string]$fileName="",
        [string]$locater="")

    foreach($line in (Get-Content $fileName))
    {
        If($line.Contains("/*")){$inComment = $true}
        If(!($line.Contains("\\")) -and !($inComment) -and ($line.Contains($locater)))
        {
            $inFunction = $true
            $retVals = New-Object PSObject
            $retVals | Add-Member -MemberType NoteProperty -Name 'Enabled' -Value $true
        }
        If($inFunction)
        {
            If($line.Contains('messageTitle')){$retVals | Add-Member -MemberType NoteProperty -Name 'Title' -Value ($line.split('"'))[1]}
            If($line.Contains('messageText'))
            {
                If(($line.split('"'))[1].Contains("<div class=`'disclaimer`'>"))
                {
                    $retVals | Add-Member -MemberType NoteProperty -Name 'Text' -Value ($line.split('"'))[1].Replace("<div class=`'disclaimer`'>","")
                    $retVals | Add-Member -MemberType NoteProperty -Name 'Scroll' -Value $true
                }
                Else
                {
                    $retVals | Add-Member -MemberType NoteProperty -Name 'Text' -Value ($line.split('"'))[1]
                    $retVals | Add-Member -MemberType NoteProperty -Name 'Scroll' -Value $false
                }
            }
            If($line.Contains('okButtonText')){$retVals | Add-Member -MemberType NoteProperty -Name 'Button' -Value ($line.split('"'))[1]}
            If($line.Contains('};')){$inFunction = $false; return $retVals}
        }
        If($line.Contains("*/")){$inComment = $false}
    }
}

Function Validate-SFCClickThrough
{
    If($checkDisclaimerWeb.Checked)
    {
        $textDisclaimerTitle.Enabled = $true
        $textDisclaimerButton.Enabled = $true
        $textDisclaimerMsg.Enabled = $true
        $checkDisclaimerScrollWeb.Enabled = $true         
    }
    Else
    {
        $textDisclaimerTitle.Enabled = $false
        $textDisclaimerButton.Enabled = $false
        $textDisclaimerMsg.Enabled = $false
        $checkDisclaimerScrollWeb.Enabled = $false
    }

    If($checkDisclaimerCAG.Checked)
    {
        $textDisclaimerTitleCAG.Enabled = $true
        $textDisclaimerButtonCAG.Enabled = $true
        $textDisclaimerMsgCAG.Enabled = $true
        $checkDisclaimerScrollCAG.Enabled = $true
    }
    Else
    {
        $textDisclaimerTitleCAG.Enabled = $false
        $textDisclaimerButtonCAG.Enabled = $false
        $textDisclaimerMsgCAG.Enabled = $false
        $checkDisclaimerScrollCAG.Enabled = $false
    }
}

Function Get-SFCFooter
{
    Param([string]$fileName)

    $cssFile = $fileName.Replace('script.js','style.css')
    $strFooter = (Get-Content $fileName) | Select-String "('#customBottom').html" -SimpleMatch
    If($strFooter)
    {
        $retVals = New-Object PSObject
        $retVals | Add-Member -MemberType NoteProperty -Name 'Enabled' -Value $true
        $retVals | Add-Member -MemberType NoteProperty -Name 'Text' -Value ($strFooter.ToString().split('"'))[1]
        
        # Get CSS data
        $retVals | Add-Member -MemberType NoteProperty -Name 'Size' -Value ((Get-SFCCSSValue -fileName $cssFile -element '#customBottom' -property 'font-size') -replace 'px','')
        $retVals | Add-Member -MemberType NoteProperty -Name 'Color' -Value (Get-SFCCSSValue -fileName $cssFile -element '#customBottom' -property 'color')

        return $retVals;
    }
}

Function Set-SFCCSSValue
{
    Param([string]$fileName="",
        [string]$element="",
        [string]$property="",
        [string]$value)

        $newFile = ''
        $i = 1
        $updateFile = (Get-Content $fileName)
        foreach($line in $updateFile)
        {
            If($line.Contains("/*")){$inComment = $true}
            If(!($inComment) -and ($line.Contains($element))){$inElement = $true}
            If($inElement)
            {
                If($line.Contains($property))
                {
                    $newFile += $line -replace ":.*?(.*);", ":$($value);"
                    If($i -lt $updateFile.Count){$newFile += "`r`n"}
                }
                Else
                {
                    $newFile += $line
                    If($i -lt $updateFile.Count){$newFile += "`r`n"}
                }
            }
            Else
            {
                $newFile += $line
                If($i -lt $updateFile.Count){$newFile += "`r`n"}
            }

        If($line.Contains("*/")){$inComment = $false}
        If($line.Contains("}")){$inElement = $false}
        $i++

        }
    $newFile | Set-Content $fileName

}

Function Get-SFCCSSValue
{
    Param([string]$fileName="",
        [string]$element="",
        [string]$property="")

        foreach ($line in (Get-Content $fileName))
        {
            If($line.Contains("/*")){$inComment = $true}
            If(!($inComment) -and ($line.Contains($element))){$inElement = $true}
            If($inElement)
            {
                If($line.Contains($property))
                {
                    return ($line -Replace ".*?:","") -replace ";", ""
                }
            }
            If($line.Contains("}")){$inElement = $false}
            If($line.Contains("*/")){$inComment = $false}
        }
}

Function Validate-SFCFooter
{
    If($checkFooter.Checked)
    {
        $textFooterSize.Enabled = $true
        $textFooterColor.Enabled = $true
        $textFooterMsg.Enabled = $true
    }
    Else
    {
        $textFooterSize.Enabled = $false
        $textFooterColor.Enabled = $false
        $textFooterMsg.Enabled = $false
    }
}

Function Set-SFCFooter
{
    Param([string]$filename="",
        [string]$action="",
        [string]$size="",
        [string]$color="",
        [string]$msg="")

    $cssFile = $filename.Replace('script.js','style.css')
    If(!($size.Contains('px'))){$size = "$($size)px"}
    switch ($action)
    {
        "enable"
        {
            $strFunction = @"
`$('#customBottom').html("$($msg)");
"@

            Backup-SFCFile $filename
            Add-Content $filename $strFunction
            
            # add CSS data if not there
            If(!((Get-Content $cssFile) | Select-String '#customBottom' -SimpleMatch))
            {
                $strCSS = @"
#customBottom
{
 text-align:center;
 font-size:$($size);
 color:$($color);
 position:static;
}
"@
                Backup-SFCFile $cssFile
                Add-Content $cssFile $strCSS -Encoding Unicode
            }
        }
        "update"
        {
            # add CSS data if not there
            If(!((Get-Content $cssFile) | Select-String '#customBottom' -SimpleMatch))
            {
                $strCSS = @"
#customBottom
{
 text-align:center;
 font-size:$($size);
 color:$($color);
 position:static;
}
"@
                Backup-SFCFile $cssFile
                Add-Content $cssFile $strCSS
            }

            # update script.js
            $newFile = ''
            $i = 1
            $updateFile = (Get-Content $filename)
            foreach($line in $updateFile)
            {
                If($line.Contains("/*")){$inComment = $true}
                If(!($inComment) -and ($line.Contains('#customBottom')))
                {
                    $newFile += $line.Replace($line.Split('"')[1],$msg)
                    If($i -lt $updateFile.Count){$newFile += "`r`n"}
                }
                Else
                {
                    $newFile += $line
                    If($i -lt $updateFile.Count){$newFile += "`r`n"}
                }
                If($line.Contains("*/")){$inComment = $false}
                $i++
            }
            Backup-SFCFile $filename
            $newFile | Set-Content $fileName -Encoding Unicode

            # Update style.css
            Backup-SFCFile $cssFile
            Set-SFCCSSValue -fileName $cssFile -element '#customBottom' -property 'font-size' -value $size
            Set-SFCCSSValue -fileName $cssFile -element '#customBottom' -property 'color' -value $color

        }
        "disable"
        {
            Backup-SFCFile $filename
            Remove-SFCFileString -fileName $filename -findString '#customBottom'

            Backup-SFCFile $cssFile
            Remove-SFCParagraph -fileName $cssFile -textStart '#customBottom' -textEnd '}'
        }
    }
}

Function Validate-SFCOptimalGW
{
    Param([string]$action)

    switch($action)
    {

        "reset"
        {
            $textGWFQDN.Text = ""
            $textGWSTA.Text = ""
            $checkGWSR.Checked = $false
            $checkGWUseLB.Checked = $false
            $textGWFarms.Text = ""
        }
        "values"
        {
            $textGWFQDN.Text = "$(($script:objSFGateways | Where {$_.Name -eq $comboGWName.SelectedItem.ToString()}).Address)"
            $textGWSTA.Text = "$(($script:objSFGateways | Where {$_.Name -eq $comboGWName.SelectedItem.ToString()}).SecureTicketAuthorityURLs)"
            If([System.Convert]::ToBoolean(($script:objSFGateways | Where {$_.Name -eq $comboGWName.SelectedItem.ToString()}).SessionReliability))
            {$checkGWSR.Checked = $true}Else{$checkGWSR.Checked = $false}
            If([System.Convert]::ToBoolean(($script:objSFGateways | Where {$_.Name -eq $comboGWName.SelectedItem.ToString()}).RequestTicketTwoSTA))
            {$checkGWTwoSTA.Checked = $true}Else{$checkGWTwoSTA.Checked = $false}

            $textGWFarms.Text = ""
            foreach($farmDef in $script:objSFFarms)
            {
                $textGWFarms.Text += $farmDef.FarmName + ": " + $farmDef.Servers
                $textGWFarms.Text += "`r`n"
            }
            $checkGWSR.Enabled = $true
            $checkGWDirect.Enabled = $true
            $checkGWTwoSTA.Enabled = $true
            $checkGWUseLB.Enabled = $true
            $textGWBypass.Enabled = $true
            $textGWBypass.Text = "00:02:00"
        }
        "init"
        {
            If($checkGWEnable.Checked)
            {
                $comboGWName.Enabled = $true
            }
            Else
            {
                $comboGWName.Enabled = $false
                $textGWFQDN.Text = ""
                $textGWSTA.Text = ""
                $checkGWSR.Checked = $false
                $checkGWSR.Enabled = $false
                $checkGWTwoSTA.Checked = $false
                $checkGWTwoSTA.Enabled = $false
                $checkGWDirect.Checked = $false
                $checkGWDirect.Enabled = $false
                $checkGWUseLB.Checked = $false
                $checkGWUseLB.Enabled = $false
                $textGWBypass.Text = ""
                $textGWBypass.Enabled = $false
                $textGWFarms.Text = ""
                #$comboGWName.Items.Clear()
            }
        }

    }
    
}

Function Set-SFCOptimalGW
{
    Param([string]$action="")

    Switch($action)
    {
        "enable"
        {
            If($script:boolGWUpdate){Remove-DSOptimalGatewayForFarms -SiteId $script:ctxSiteID -ResourcesVirtualPath $script:storeVirtPath}
            Set-DSOptimalGatewayForFarms -SiteId $script:ctxSiteID `
                        -ResourcesVirtualPath $script:storeVirtPath  `
                        -GatewayName $comboGWName.SelectedItem.ToString()  `
                        -Hostnames ($textGWFQDN.Text.Replace("https://","")) `
                        -Farms $script:objSFFarms.FarmName `
                        -StaUrls ($script:objSFGateways | Where {$_.Name -eq $comboGWName.SelectedItem.ToString()}).SecureTicketAuthorityURLs  `
                        -StasUseLoadBalancing:($checkGWUseLB.Checked) `
                        -StasBypassDuration $textGWBypass.Text `
                        -EnableSessionReliability:($checkGWSR.Checked) `
                        -UseTwoTickets:($checkGWTwoSTA.Checked) `
                        -EnabledOnDirectAccess:($checkGWDirect.Checked)  
        }

        "disable"
        {
            Remove-DSOptimalGatewayForFarms -SiteId $script:ctxSiteID -ResourcesVirtualPath $script:storeVirtPath
        }
    }
}

Function Validate-SFCGroupSID
{    
    for($i=0; $i -le $script:intFarmMappings; $i++)
    {
        If(!((gv "textMultiGroup$i").Value.Text -eq ""))
        {
            try
            {
                $objUser = New-Object System.Security.Principal.NTAccount("",(gv "textMultiGroup$i").Value.Text)
                (gv "labelMultiSID$i").Value.Text = ($objUser.Translate([System.Security.Principal.SecurityIdentifier]).Value)
                (gv "textMultiGroup$i").Value.BackColor = ''
            }
            catch
            {
                [System.Exception]
                (gv "textMultiGroup$i").Value.BackColor = 'Red'
                (gv "labelMultiSID$i").Value.Text = "AD Object not found!"
            }
        }
    }
}

Function Add-SFCFarmMapping
{
    If(Test-Path Variable:script:intFarmMappings){$script:intFarmMappings++}
    Else{nv "intFarmMappings" -Value 0 -Scope 'script'}
    If($script:intFarmMappings -gt 0)
    {$newMapVPos = (gv "groupFarmMap$($script:intFarmMappings - 1)").Value.Bottom + 10}
    Else{$newMapVPos = 30}

    nv "groupFarmMap$script:intFarmMappings" -Force -Scope 'Script'
    (gv "groupFarmMap$script:intFarmMappings").Value = New-Object System.Windows.Forms.GroupBox
    (gv "groupFarmMap$script:intFarmMappings").Value.Location = New-Object System.Drawing.Point(5,$newMapVPos)
    (gv "groupFarmMap$script:intFarmMappings").Value.Size = New-Object System.Drawing.Size(440,200)
    (gv "groupFarmMap$script:intFarmMappings").Value.Text = "User Farm Mapping $($script:intFarmMappings)"
    $multiTab.Controls.Add((gv "groupFarmMap$script:intFarmMappings").Value)

    nv "labelMultiName$script:intFarmMappings" -Force -Scope 'Script'
    (gv "labelMultiName$script:intFarmMappings").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiName$script:intFarmMappings").Value.Location = New-Object System.Drawing.Point(8,18)
    (gv "labelMultiName$script:intFarmMappings").Value.Size = New-Object System.Drawing.Size(85,15)
    (gv "labelMultiName$script:intFarmMappings").Value.Text = "Mapping Name"
    (gv "groupFarmMap$script:intFarmMappings").Value.Controls.Add((gv "labelMultiName$script:intFarmMappings").Value)

    nv "textMultiName$script:intFarmMappings" -Force -Scope 'Script'
    (gv "textMultiName$script:intFarmMappings").Value = New-Object System.Windows.Forms.TextBox
    (gv "textMultiName$script:intFarmMappings").Value.Location = New-Object System.Drawing.Point(95,15)
    (gv "textMultiName$script:intFarmMappings").Value.Size = New-Object System.Drawing.Size(100,20)
    (gv "groupFarmMap$script:intFarmMappings").Value.Controls.Add((gv "textMultiName$script:intFarmMappings").Value)

    nv "labelMultiGroup$script:intFarmMappings" -Force -Scope 'Script'
    (gv "labelMultiGroup$script:intFarmMappings").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiGroup$script:intFarmMappings").Value.Location = New-Object System.Drawing.Point(215,18)
    (gv "labelMultiGroup$script:intFarmMappings").Value.Size = New-Object System.Drawing.Size(60,20)
    (gv "labelMultiGroup$script:intFarmMappings").Value.Text = "AD Group"
    (gv "groupFarmMap$script:intFarmMappings").Value.Controls.Add((gv "labelMultiGroup$script:intFarmMappings").Value)

    nv "textMultiGroup$script:intFarmMappings" -Force -Scope 'Script'
    (gv "textMultiGroup$script:intFarmMappings").Value = New-Object System.Windows.Forms.TextBox
    (gv "textMultiGroup$script:intFarmMappings").Value.Location = New-Object System.Drawing.Point(280,15)
    (gv "textMultiGroup$script:intFarmMappings").Value.Size = New-Object System.Drawing.Size(110,20)
    (gv "textMultiGroup$script:intFarmMappings").Value.Add_Leave({ Validate-SFCGroupSID })
    (gv "groupFarmMap$script:intFarmMappings").Value.Controls.Add((gv "textMultiGroup$script:intFarmMappings").Value)

    nv "labelMultiSID$script:intFarmMappings" -Force -Scope 'Script'
    (gv "labelMultiSID$script:intFarmMappings").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiSID$script:intFarmMappings").Value.Location = New-Object System.Drawing.Point(10,37)
    (gv "labelMultiSID$script:intFarmMappings").Value.Size = New-Object System.Drawing.Size(300,15)
    (gv "labelMultiSID$script:intFarmMappings").Value.Text = ""
    (gv "groupFarmMap$script:intFarmMappings").Value.Controls.Add((gv "labelMultiSID$script:intFarmMappings").Value)

}

Function Add-SFCEquivFarmSet
{
    Param([int]$farmSetGroup)

    If((gv "intMapEFS$farmSetGroup" -ErrorAction SilentlyContinue) -and (gv "intMapEFS$farmSetGroup" -ErrorAction SilentlyContinue).Value -ne $null){(gv "intMapEFS$farmSetGroup").Value++}
    Else{nv "intMapEFS$farmSetGroup" -Value 0 -Scope 'script' -Force}

    [string]$EFSID = $farmSetGroup.ToString() + (gv "intMapEFS$farmSetGroup").Value.ToString()

    (gv "groupFarmMap$farmSetGroup").Value.Size = New-Object System.Drawing.Size(440,((gv "intMapEFS$farmSetGroup").value * 130 + 190))
    Set-SFCMultiGroupPosition $farmSetGroup

    $linkAddEFS = New-Object System.Windows.Forms.Button
    $linkAddEFS.Location = New-Object System.Drawing.Point(270,80)
    $linkAddEFS.Text = "Add FarmSet $($farmSetGroup)"
    $linkAddEFS.Size = New-Object System.Drawing.Size(100,20)
    (gv "groupFarmMap$script:intFarmMappings").Value.Controls.Add($linkAddEFS)
    $linkAddEFS.Add_Click({ Add-SFCEquivFarmSet ($this.text -replace 'Add FarmSet ','') })

    nv "labelMultiEFSName$EFSID" -Force -Scope 'Script'
    (gv "labelMultiEFSName$EFSID").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiEFSName$EFSID").Value.Location = New-Object System.Drawing.Point(8,((gv "intMapEFS$farmSetGroup").value * 130 + 58))
    (gv "labelMultiEFSName$EFSID").Value.Size = New-Object System.Drawing.Size(145,20)
    (gv "labelMultiEFSName$EFSID").Value.Text = "EquivalentFarmSet Name"
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "labelMultiEFSName$EFSID").Value)

    nv "textMultiEFSName$EFSID" -Force -Scope 'script'
    (gv "textMultiEFSName$EFSID").Value = New-Object System.Windows.Forms.TextBox
    (gv "textMultiEFSName$EFSID").Value.Location = New-Object System.Drawing.Point(155,((gv "intMapEFS$farmSetGroup").value * 130 + 54))
    (gv "textMultiEFSName$EFSID").Value.Size = New-Object System.Drawing.Size(100,20)
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "textMultiEFSName$EFSID").Value)

    nv "labelMultiEFSLB$EFSID" -Force -Scope 'script'
    (gv "labelMultiEFSLB$EFSID").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiEFSLB$EFSID").Value.Location = New-Object System.Drawing.Point(262,((gv "intMapEFS$farmSetGroup").value * 130 +58))
    (gv "labelMultiEFSLB$EFSID").Value.Size = New-Object System.Drawing.Size(45,20)
    (gv "labelMultiEFSLB$EFSID").Value.Text = "Method"
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "labelMultiEFSLB$EFSID").Value)

    nv "comboMultiEFSLB$EFSID" -Force -Scope 'script'
    (gv "comboMultiEFSLB$EFSID").Value = New-Object System.Windows.Forms.ComboBox
    (gv "comboMultiEFSLB$EFSID").Value.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    (gv "comboMultiEFSLB$EFSID").Value.Location = New-Object System.Drawing.Point(310,((gv "intMapEFS$farmSetGroup").value * 130 +55))
    (gv "comboMultiEFSLB$EFSID").Value.Size = New-Object System.Drawing.Size(100,20)
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "comboMultiEFSLB$EFSID").Value)

    [void] (gv "comboMultiEFSLB$EFSID").Value.Items.Add('Failover')
    [void] (gv "comboMultiEFSLB$EFSID").Value.Items.Add('LoadBalanced')

    nv "labelMultiAggrName$EFSID" -Force -Scope 'script'
    (gv "labelMultiAggrName$EFSID").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiAggrName$EFSID").Value.Location = New-Object System.Drawing.Point(8,((gv "intMapEFS$farmSetGroup").value * 130 +77))
    (gv "labelMultiAggrName$EFSID").Value.Size = New-Object System.Drawing.Size(145,20)
    (gv "labelMultiAggrName$EFSID").Value.Text = "AggregationGroup Name"
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "labelMultiAggrName$EFSID").Value)

    nv "textMultiAggrName$EFSID" -Force -Scope 'script'
    (gv "textMultiAggrName$EFSID").Value = New-Object System.Windows.Forms.TextBox
    (gv "textMultiAggrName$EFSID").Value.Location = New-Object System.Drawing.Point(155,((gv "intMapEFS$farmSetGroup").value * 130 +75))
    (gv "textMultiAggrName$EFSID").Value.Size = New-Object System.Drawing.Size(100,20)
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "textMultiAggrName$EFSID").Value)

    nv "labelMultiPriFarm$EFSID" -Force -Scope 'script'
    (gv "labelMultiPriFarm$EFSID").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiPriFarm$EFSID").Value.Location = New-Object System.Drawing.Point(8,((gv "intMapEFS$farmSetGroup").value * 130 +103))
    (gv "labelMultiPriFarm$EFSID").Value.Size = New-Object System.Drawing.Size(85,15)
    (gv "labelMultiPriFarm$EFSID").Value.Text = "Primary Farms"
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "labelMultiPriFarm$EFSID").Value)

    nv "CLBMultiPriFarm$EFSID" -Force -Scope 'script'
    (gv "CLBMultiPriFarm$EFSID").Value = New-Object System.Windows.Forms.CheckedListBox
    (gv "CLBMultiPriFarm$EFSID").Value.Location = New-Object System.Drawing.Point(95,((gv "intMapEFS$farmSetGroup").value * 130 +103))
    (gv "CLBMultiPriFarm$EFSID").Value.Size = New-Object System.Drawing.Size(100,70)
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "CLBMultiPriFarm$EFSID").Value)

    foreach($farmItem in $script:objSFFarms)
    {
        [void](gv "CLBMultiPriFarm$EFSID").Value.Items.Add($farmItem.FarmName)
    }

    nv "labelMultiBkuFarm$EFSID" -Force -Scope 'script'
    (gv "labelMultiBkuFarm$EFSID").Value = New-Object System.Windows.Forms.Label
    (gv "labelMultiBkuFarm$EFSID").Value.Location = New-Object System.Drawing.Point(210,((gv "intMapEFS$farmSetGroup").value * 130 +103))
    (gv "labelMultiBkuFarm$EFSID").Value.Size = New-Object System.Drawing.Size(85,15)
    (gv "labelMultiBkuFarm$EFSID").Value.Text = "Backup Farms"
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "labelMultiBkuFarm$EFSID").Value)

    nv "CLBMultiBkuFarm$EFSID" -Force -Scope 'script'
    (gv "CLBMultiBkuFarm$EFSID").Value = New-Object System.Windows.Forms.CheckedListBox
    (gv "CLBMultiBkuFarm$EFSID").Value.Location = New-Object System.Drawing.Point(295,((gv "intMapEFS$farmSetGroup").value * 130 +103))
    (gv "CLBMultiBkuFarm$EFSID").Value.Size = New-Object System.Drawing.Size(100,70)
    (gv "groupFarmMap$farmSetGroup").Value.Controls.Add((gv "CLBMultiBkuFarm$EFSID").Value)

    foreach($farmItem in $script:objSFFarms)
    {
        [void](gv "CLBMultiBkuFarm$EFSID").Value.Items.Add($farmItem.FarmName)
    }

    Set-SFCMultiGroupPosition $farmSetGroup

}

Function Build-SFCMultiSiteXML
{
    # Build base XML for multisite
    # check for existing
    If(!($script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings))
    {
        $script:modFiles += "XML configuration for Multi Site added to web.config"
        $userFarmMappings = $script:currentStoreXML.CreateElement('userFarmMappings')
        $clear = $script:currentStoreXML.CreateElement('clear')
        $userFarmMappings.AppendChild($clear)

        for($i=0; $i -le $script:intFarmMappings; $i++)
        {
            # Build individual UserFarmMappings
            nv "UFM$i" -Value $script:currentStoreXML.CreateElement('userFarmMapping')
            (gv "UFM$i").Value.SetAttribute('name',((gv "textMultiName$i").Value.Text))
            nv "groups$i" -Value $script:currentStoreXML.CreateElement('groups')
            nv "group$i" -Value $script:currentStoreXML.CreateElement('group')

            If(((gv "textMultiGroup$i").Value.Text).Contains('\')){$groupName = ((gv "textMultiGroup$i").Value.Text)}
            ElseIf(((gv "textMultiGroup$i").Value.Text) -like 'everyone' -or ((gv "textMultiGroup$i").Value.Text) -like 'authenticated users'){$groupName = ((gv "textMultiGroup$i").Value.Text)}
            ElseIf(((gv "textMultiGroup$i").Value.Text) -eq ''){$groupName = ''}
            Else{$groupName = "$([environment]::UserDomainName)\$((gv "textMultiGroup$i").Value.Text)"}

            (gv "group$i").Value.SetAttribute('name',$groupName)
            (gv "group$i").Value.SetAttribute('sid',((gv "labelMultiSID$i").Value.Text))
            (gv "groups$i").Value.AppendChild((gv "group$i").Value)
            (gv "UFM$i").Value.AppendChild((gv "groups$i").Value)
            nv "equivalentfarmSets$i" -Value $script:currentStoreXML.CreateElement('equivalentFarmSets')

            for($j=0; $j -le (gv "intMapEFS$i").Value; $j++)
            {
                [string]$ID = $i.ToString() + $j.ToString()
                nv "EFS$j" -Value $script:currentStoreXML.CreateElement('equivalentFarmSet') -Force
                (gv "EFS$j").Value.SetAttribute('name',((gv "textMultiEFSName$ID").Value.Text))
                (gv "EFS$j").Value.SetAttribute('loadBalanceMode',((gv "comboMultiEFSLB$ID").Value.SelectedItem.ToString()))
                (gv "EFS$j").Value.SetAttribute('aggregationGroup',((gv "textMultiAggrName$ID").Value.Text))
                nv "primeFarmRefs$j" -Value $script:currentStoreXML.CreateElement('primaryFarmRefs') -Force
                for($k=1; $k -le (gv "CLBMultiPriFarm$ID").Value.CheckedItems.Count; $k++)
                {
                    nv "pfarm$k" -Value $script:currentStoreXML.CreateElement('farm') -Force
                    (gv "pfarm$k").Value.SetAttribute('name',((gv "CLBMultiPriFarm$ID").Value.CheckedItems[$k-1]))
                    (gv "primeFarmRefs$j").Value.AppendChild((gv "pfarm$k").Value)
                }

                nv "bkupFarmRefs$j" -Value $script:currentStoreXML.CreateElement('backupFarmRefs') -Force
                for($l=1; $l -le (gv "CLBMultiBkuFarm$ID").Value.CheckedItems.Count; $l++)
                {
                    nv "bfarm$l" -Value $script:currentStoreXML.CreateElement('farm') -Force
                    (gv "bfarm$l").Value.SetAttribute('name',((gv "CLBMultiBkuFarm$ID").Value.CheckedItems[$l-1]))
                    (gv "bkupFarmRefs$j").Value.AppendChild((gv "bfarm$l").Value)
                }

                (gv "EFS$j").Value.AppendChild((gv "primeFarmRefs$j").Value)
                (gv "EFS$j").Value.AppendChild((gv "bkupFarmRefs$j").Value)
                (gv "equivalentfarmSets$i").Value.AppendChild((gv "EFS$j").Value)
            }

            (gv "UFM$i").Value.AppendChild((gv "equivalentfarmSets$i").Value)
            $userFarmMappings.AppendChild((gv "UFM$i").Value)
        }
        $script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.AppendChild($userFarmMappings)

    }
}

Function Get-SFCMultiSite
{
    foreach($farmMap in $script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings.userFarmMapping)
    {
        Add-SFCFarmMapping
        (gv "textMultiName$script:intFarmMappings").Value.text = $farmMap.Name
        (gv "textMultiGroup$script:intFarmMappings").Value.text = $farmMap.groups.group.name

        foreach ($efset in @($script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings.userFarmMapping)[$script:intFarmMappings].equivalentFarmSets.equivalentFarmSet)
        {
            Add-SFCEquivFarmSet $script:intFarmMappings
            [string]$EFSID = $script:intFarmMappings.ToString() + (gv "intMapEFS$script:intFarmMappings").Value.ToString()
            (gv "textMultiEFSName$EFSID").Value.Text = $efset.name
            (gv "textMultiAggrName$EFSID").Value.Text = $efset.aggregationGroup
            (gv "comboMultiEFSLB$EFSID").Value.SelectedItem = $efset.loadBalanceMode

            foreach ($priFarmRef in $efset.PrimaryFarmRefs.farm.name)
            {
                (gv "CLBMultiPriFarm$EFSID").Value.SetItemChecked(((gv "CLBMultiPriFarm$EFSID").Value.Items.IndexOf($priFarmRef)),$true)
            }

            foreach ($bkuFarmRef in $efset.backupFarmRefs.farm.name)
            {
                (gv "CLBMultiBkuFarm$EFSID").Value.SetItemChecked(((gv "CLBMultiBkuFarm$EFSID").Value.Items.IndexOf($bkuFarmRef)),$true)
            }
        }
    }
    Validate-SFCGroupSID
}

Function Set-SFCMultiSite
{
    Param([bool]$enable)

    If($enable)
    {
        If($script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings)
        {
            $deleteNode = $script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings
            $script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.RemoveChild($deleteNode)
        }
        Build-SFCMultiSiteXML
    }
    Else
    {
        If($script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings)
        {
            $deleteNode = $script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.userFarmMappings
            $script:currentStoreXML.configuration.'citrix.deliveryservices'.resourcesCommon.resourcesWingConfigurations.resourcesWingConfiguration.RemoveChild($deleteNode)
        }
    }
}

Function Set-SFCMultiGroupPosition
{
    param([int]$EFSFarmMap)

    If($EFSFarmMap -lt $script:intFarmMappings)
    {
        for($i=($EFSFarmMap+1);$i -le $script:intFarmMappings; $i++)
        {
            (gv "groupFarmMap$i").Value.Location = New-Object System.Drawing.Point(5,((gv "groupFarmMap$($i-1)").Value.Bottom + 10))
        }
    }

}

Function Validate-SFCMultiSite
{
    If($checkMultiEnable.Checked -and !(Test-Path Variable:script:intFarmMappings))
    {
    [System.Windows.Forms.MessageBox]::Show("Configuring StoreFront for MultiSite operation is a complex task.`nMisconfiguration can cause issues! Use caution.`n`nPlease see the configuration examples here: https://www.citrix.com/blogs/2014/10/13/storefront-multi-site-settings-some-examples/ `n`nReminder: all web.config files are backed up.", 'StoreFront MultiSite Warning')
        Add-SFCFarmMapping
        Add-SFCEquivFarmSet $script:intFarmMappings
        $linkAddFarmMapping.Enabled = $true
    }
    If(!($checkMultiEnable.Checked) -and (Test-Path Variable:script:intFarmMappings))
    {
        for($i = 0; $i -le $script:intFarmMappings; $i++)
        {(gv "groupFarmMap$i").Value.Enabled = $false}
    }
    If($checkMultiEnable.Checked -and (Test-Path Variable:script:intFarmMappings))
    {
        for($i = 0; $i -le $script:intFarmMappings; $i++)
        {(gv "groupFarmMap$i").Value.Enabled = $true}
    }
}

Function Get-SFCSingleFQDN
{
    [xml]$authXML = Get-Content C:\inetpub\wwwroot\Citrix\Authentication\web.config
    $allowedAudience = ($authXML.configuration.'citrix.deliveryservices'.tokenManager.services.service | Where {$_.displayName -eq 'Authentication Token Producer'}).allowedaudiences.add.audience
    If($allowedAudience | where {$_ -ne $script:strBaseURL})
    {
        return $allowedAudience | where {$_ -ne $script:strBaseURL}
    }
}

Function Set-SFCSingleFQDN
{
    Param([bool]$enable)

    $authFilePath = 'C:\inetpub\wwwroot\Citrix\Authentication\web.config'
    $roamFilePath = 'C:\inetpub\wwwroot\Citrix\Roaming\web.config'

    If($enable)
    {
        Backup-SFCFile $authFilePath
        [xml]$authXML = Get-Content $authFilePath
        $newComponent = $authXML.CreateElement('add')
        $newComponent.SetAttribute('name',($textSingleFQDN.Text.Replace('://','-')).Replace('/',''))
        $newComponent.SetAttribute('audience',$textSingleFQDN.Text)
        ($authXML.configuration.'citrix.deliveryservices'.tokenManager.services.service | Where {$_.displayName -eq 'Authentication Token Producer'}).allowedaudiences.AppendChild($newComponent)
        $authXML.Save($authFilePath)

        Backup-SFCFile $roamFilePath
        [xml]$roamXML = Get-Content $roamFilePath
        $newComponent = $roamXML.CreateElement('add')
        $newComponent.SetAttribute('name',($textSingleFQDN.Text.Replace('://','-')).Replace('/',''))
        $newComponent.SetAttribute('audience',$textSingleFQDN.Text)
        $roamXML.configuration.'citrix.deliveryservices'.tokenManager.services.service.allowedAudiences.AppendChild($newComponent)
        $roamXML.Save($roamFilePath)
    }
    Else
    {
        Backup-SFCFile $authFilePath
        [xml]$authXML = Get-Content $authFilePath
        foreach($xmlElement in ($authXML.configuration.'citrix.deliveryservices'.tokenManager.services.service | Where {$_.displayName -eq 'Authentication Token Producer'}).allowedaudiences.add)
        {
            If($xmlElement.audience -ne $script:strBaseURL)
            {
                $deleteNode = $xmlElement
                ($authXML.configuration.'citrix.deliveryservices'.tokenManager.services.service | Where {$_.displayName -eq 'Authentication Token Producer'}).allowedaudiences.RemoveChild($deleteNode)
            }            
        }
        $authXML.Save($authFilePath)

        Backup-SFCFile $roamFilePath
        [xml]$roamXML = Get-Content $roamFilePath
        foreach($xmlElement in $roamXML.configuration.'citrix.deliveryservices'.tokenManager.services.service.allowedAudiences.add)
        {
            If($xmlElement.audience -ne $script:strBaseURL)
            {
                $deleteNode = $xmlElement
                $roamXML.configuration.'citrix.deliveryservices'.tokenManager.services.service.allowedAudiences.RemoveChild($deleteNode)
            }
        }
        $roamXML.Save($roamFilePath)
    }
}

Function Backup-SFCFile
{
    Param([string]$backupFile="")
    $originalFile = gci $backupFile
    cpi $originalFile.FullName -Destination "$($psscriptroot)\$(($originalFile.FullName.Replace(':','')).Replace('\','-'))" -Force
    $script:modFiles += $backupFile
}

#endregion

#region form setup and tabs

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$script:SFCForm = New-Object System.Windows.Forms.Form
$SFCTabs = New-Object System.Windows.Forms.TabControl
$commonTab = New-Object System.Windows.Forms.TabPage
$UITab = New-Object System.Windows.Forms.TabPage
$ClientTab = New-Object System.Windows.Forms.TabPage
$ServerTab = New-Object System.Windows.Forms.TabPage
$multiTab = New-Object System.Windows.Forms.TabPage

# Set Icon, window text and window size
If(Test-Path "C:\Program Files\Citrix\Receiver StoreFront\Management\CitrixStoreFrontConsole.msc")
{$cornerIcon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Program Files\Citrix\Receiver StoreFront\Management\CitrixStoreFrontConsole.msc")}
Else
{$cornerIcon = [System.Drawing.Icon]::ExtractAssociatedIcon($PSHOME + "\Powershell.exe")}

$SFCForm.Icon = $cornerIcon
$SFCForm.Text = "Citrix Storefront Configurator"
$SFCForm.Size = New-Object System.Drawing.Size(480,600)

$SFCTabs.Location = New-Object System.Drawing.Point(5,70)
$SFCTabs.Size = New-Object System.Drawing.Size(455,450)
$SFCForm.Controls.Add($SFCTabs)

$commonTab.Location = New-Object System.Drawing.Point(10,70)
$commonTab.TabIndex = 1
$commonTab.Text = "Common Settings"
$commonTab.UseVisualStyleBackColor = $true
$SFCTabs.Controls.Add($commonTab)

$UITab.TabIndex = 2
$UITab.Text = "Custom UI"
$UITab.UseVisualStyleBackColor = $true
$SFCTabs.Controls.Add($UITab)
If($strCurrentStorefront -lt [version]"3.0.0.44"){$UITab.Enabled = $false}

$ClientTab.TabIndex = 3
$ClientTab.Text = "Client Settings"
$ClientTab.UseVisualStyleBackColor = $true
$SFCTabs.Controls.Add($ClientTab)

$ServerTab.TabIndex = 4
$ServerTab.Text = "Server Settings"
$ServerTab.UseVisualStyleBackColor = $true
$SFCTabs.Controls.Add($ServerTab)

$multiTab.TabIndex = 5
$multiTab.Text = "Multi Site"
$multiTab.UseVisualStyleBackColor = $true
$multiTab.AutoScroll = $true
$SFCTabs.Controls.Add($multiTab)

#endregion

#region Common tab

$SFLabel = New-Object System.Windows.Forms.Label
$SFLabel.Location = New-Object System.Drawing.Size(10,10)
$SFLabel.Size = New-Object System.Drawing.Size(280,20) 
$SFLabel.Text = "Citrix Storefront version detected: $($strCurrentStorefront)"
$SFCForm.Controls.Add($SFLabel)

$StoreLabel = New-Object System.Windows.Forms.Label
$StoreLabel.Location = New-Object System.Drawing.Size(10,30)
$StoreLabel.Size = New-Object System.Drawing.Size(240,20)
$StoreLabel.Text = "Please select Receiver Web Store to Modify: "
$SFCForm.Controls.Add($StoreLabel)

$listWebStores = New-Object System.Windows.Forms.ComboBox
$listWebStores.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$listWebStores.Location = New-Object System.Drawing.Size(250,30)
$listWebStores.Size = New-Object System.Drawing.Size(100,20)

$ReceiverLabel = New-Object System.Windows.Forms.Label
$ReceiverLabel.Location = New-Object System.Drawing.Size(10,50)
$ReceiverLabel.Size = New-Object System.Drawing.Size(240,20)
$ReceiverLabel.Text = "Receiver Store: "
$SFCForm.Controls.Add($ReceiverLabel)

Foreach($SFStore in ($script:ctxSFStores | Where {$_.AppPool -eq "Citrix Receiver for Web"}).Name)
{
    [void] $listWebStores.Items.Add($SFStore)
}

$SFCForm.Controls.Add($listWebStores)
$listWebStores.Add_SelectedIndexChanged({Get-SFCStoreConfig})

# ---------- Settings Items

# Choose default view
$labelDefaultView = New-Object System.Windows.Forms.Label
$labelDefaultView.Location = New-Object System.Drawing.Size(10,10)
$labelDefaultView.Size = New-Object System.Drawing.Size(150,20)
$labelDefaultView.Text = 'Default tab in Web Receiver'
$commonTab.Controls.Add($labelDefaultView)

$comboWebTabs = New-Object System.Windows.Forms.ComboBox
$comboWebTabs.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboWebTabs.Location = New-Object System.Drawing.Size(290,10)
$comboWebTabs.Size = New-Object System.Drawing.Size(100,20)
[void] $comboWebTabs.Items.Add("Favorites")
[void] $comboWebTabs.Items.Add("Desktops")
[void] $comboWebTabs.Items.Add("Apps")
[void] $comboWebTabs.Items.Add("auto")
$commonTab.Controls.Add($comboWebTabs)

# IIS Default Document
$checkDefaultDoc = New-Object System.Windows.Forms.CheckBox
$checkDefaultDoc.Location = New-Object System.Drawing.Size(10,35)
$checkDefaultDoc.Size = New-Object System.Drawing.Size(270,20)
$checkDefaultDoc.Text = 'Set IIS Default Document to Web Receiver'
$commonTab.Controls.Add($checkDefaultDoc)

# Choose apps categories view as default
$checkCategories = New-Object System.Windows.Forms.CheckBox
$checkCategories.Location = New-Object System.Drawing.Size(10,60)
$checkCategories.Size = New-Object System.Drawing.Size(270,20)
$checkCategories.Text = 'Set categories view as default in Apps tab'
$checkCategories.Add_Click({ Validate-SFCAppCategories })
$commonTab.Controls.Add($checkCategories)

# Enable App categories view
$checkAppCatView = New-Object System.Windows.Forms.CheckBox
$checkAppCatView.Location = New-Object System.Drawing.Size(10,85)
$checkAppCatView.Size = New-Object System.Drawing.Size(270,20)
$checkAppCatView.Text = 'Enable App categories view'
$checkAppCatView.Add_Click({ Validate-SFCAppCategories })
$commonTab.Controls.Add($checkAppCatView)

# Deploy native receiver
$checkNative = New-Object System.Windows.Forms.CheckBox
$checkNative.Location = New-Object System.Drawing.Size(10,110)
$checkNative.Size = New-Object System.Drawing.Size(340,20)
$checkNative.Text = 'Download latest Receivers and enable local install source'
$commonTab.Controls.Add($checkNative)

# Disable CRL checking
$checkCRL = New-Object System.Windows.Forms.CheckBox
$checkCRL.Location = New-Object System.Drawing.Size(10,135)
$checkCRL.Size = New-Object System.Drawing.Size(270,20)
$checkCRL.Text = 'Disable CRL checking'
$commonTab.Controls.Add($checkCRL)

# Auto-launch desktop
$checkLaunch = New-Object System.Windows.Forms.CheckBox
$checkLaunch.Location = New-Object System.Drawing.Size(10,160)
$checkLaunch.Size = New-Object System.Drawing.Size(270,20)
$checkLaunch.Text = 'Desktop autoLaunch'
$commonTab.Controls.Add($checkLaunch)

# Show Desktops view
$checkDesktopView = New-Object System.Windows.Forms.CheckBox
$checkDesktopView.Location = New-Object System.Drawing.Size(10,185)
$checkDesktopView.Size = New-Object System.Drawing.Size(270,20)
$checkDesktopView.Text = 'Show desktops tab'
$checkDesktopView.Add_Click({ })
$commonTab.Controls.Add($checkDesktopView)

# Show Apps view
$checkAppsView = New-Object System.Windows.Forms.CheckBox
$checkAppsView.Location = New-Object System.Drawing.Size(10,210)
$checkAppsView.Size = New-Object System.Drawing.Size(270,20)
$checkAppsView.Text = 'Show applications tab'
$checkAppsView.Add_Click({ })
$commonTab.Controls.Add($checkAppsView)

$FilterGroup = New-Object System.Windows.Forms.GroupBox
$FilterGroup.Location = New-Object System.Drawing.Point(10,240)
$FilterGroup.Size = New-Object System.Drawing.Size(420,70)
$FilterGroup.Text = "Filtering"
$CommonTab.Controls.Add($FilterGroup)

# Filter by keyword (Requires SF2.5+)
$checkKeyFilter = New-Object System.Windows.Forms.CheckBox
$checkKeyFilter.Location = New-Object System.Drawing.Size(10,15)
$checkKeyFilter.Size = New-Object System.Drawing.Size(150,20)
$checkKeyFilter.Text = 'Filter items by keyword'
$checkKeyFilter.Add_Click({ If($checkKeyFilter.Checked){$textKeyFilter.Enabled = $true; $comboKeyFilter.Enabled = $true}Else{$textKeyFilter.Enabled = $false; $comboKeyFilter.Enabled = $false}})
$FilterGroup.Controls.Add($checkKeyFilter)

$textKeyFilter = New-Object System.Windows.Forms.TextBox
$textKeyFilter.Location = New-Object System.Drawing.Size(180,15)
$textKeyFilter.Size = New-Object System.Drawing.Size(110,20)
$textKeyFilter.Enabled = $false
$FilterGroup.Controls.Add($textKeyFilter)
$comboKeyFilter = New-Object System.Windows.Forms.ComboBox
$comboKeyFilter.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboKeyFilter.Location = New-Object System.Drawing.Size(300,15)
$comboKeyFilter.Size = New-Object System.Drawing.Size(110,20)
$comboKeyFilter.Enabled = $false
[void] $comboKeyFilter.Items.Add("Exclude")
[void] $comboKeyFilter.Items.Add("Include")
$comboKeyFilter.SelectedItem = $comboKeyFilter.Items[0]
$FilterGroup.Controls.Add($comboKeyFilter)

# Filter by type (Requires SF2.5+)
$labelTypeFilter = New-Object System.Windows.Forms.Label
$labelTypeFilter.Location = New-Object System.Drawing.Size(10,43)
$labelTypeFilter.Size = New-Object System.Drawing.Size(180,20)
$labelTypeFilter.Text = 'Filter items by type (include)'
$FilterGroup.Controls.Add($labelTypeFilter)

$checkTypeApps = New-Object System.Windows.Forms.CheckBox
$checkTypeApps.Location = New-Object System.Drawing.Size(190,40)
$checkTypeApps.Size = New-Object System.Drawing.Size(50,20)
$checkTypeApps.Text = "Apps"
$checkTypeDesk = New-Object System.Windows.Forms.CheckBox
$checkTypeDesk.Location = New-Object System.Drawing.Size(240,40)
$checkTypeDesk.Size = New-Object System.Drawing.Size(70,20)
$checkTypeDesk.Text = "Desktops"
$checkTypeDocs = New-Object System.Windows.Forms.CheckBox
$checkTypeDocs.Location = New-Object System.Drawing.Size(310,40)
$checkTypeDocs.Size = New-Object System.Drawing.Size(80,20)
$checkTypeDocs.Text = "Documents"
$FilterGroup.Controls.Add($checkTypeApps)
$FilterGroup.Controls.Add($checkTypeDesk)
$FilterGroup.Controls.Add($checkTypeDocs)

# Propagate changes
$checkPropChanges = New-Object System.Windows.Forms.CheckBox
$checkPropChanges.Location = New-Object System.Drawing.Size(10,330)
$checkPropChanges.Size = New-Object System.Drawing.Size(350,20)
$checkPropChanges.Text = 'Check to propagate to server group once changes are applied'
$commonTab.Controls.Add($checkPropChanges)

# Reset Receiver
$checkReset = New-Object System.Windows.Forms.CheckBox
$checkReset.Location = New-Object System.Drawing.Size(10,365)
$checkReset.Size = New-Object System.Drawing.Size(320,20)
$checkReset.Text = 'Reset Storefront *CAUTION: THIS CANNOT BE UNDONE'
$checkReset.Add_Click({ [System.Windows.Forms.MessageBox]::Show("The Storefront reset is permenant - all data will be lost once applied.`nThis script does not backup anything during a full reset." , "WARNING") })
$commonTab.Controls.Add($checkReset)

# Add notes
$closeLabel = New-Object System.Windows.Forms.Label
$closeLabel.Location = New-Object System.Drawing.Size(10,400)
$closeLabel.Size = New-Object System.Drawing.Size(400,20)
$closeLabel.Text = "*Note: Any modified files will be backed up to the script directory. "
$commonTab.Controls.Add($closeLabel)

#endregion

#region UI tab

## UI - Display dynamic header from file (SF3+)
$checkDynHeader = New-Object System.Windows.Forms.CheckBox
$checkDynHeader.Location = New-Object System.Drawing.Size(10,10)
$checkDynHeader.Size = New-Object System.Drawing.Size(400,20)
$checkDynHeader.Text = "Enable a dynamic header from text or HTML \customweb\Readme.txt"
$checkDynHeader.Add_Click({  })
$UITab.Controls.Add($checkDynHeader)

## UI - Click through disclaimer
$groupDisclaimer = New-Object System.Windows.Forms.GroupBox
$groupDisclaimer.Location = New-Object System.Drawing.Point(10,40)
$groupDisclaimer.Size = New-Object System.Drawing.Size(420,210)
$groupDisclaimer.Text = "Click-through disclaimer"
$UITab.Controls.Add($groupDisclaimer)

$checkDisclaimerWeb = New-Object System.Windows.Forms.CheckBox
$checkDisclaimerWeb.Location = New-Object System.Drawing.Point(10,15)
$checkDisclaimerWeb.Size = New-Object System.Drawing.Size(150,20)
$checkDisclaimerWeb.Text = "Pre-Logon (web only)"
$checkDisclaimerWeb.Add_Click({ Validate-SFCClickThrough })
$groupDisclaimer.Controls.Add($checkDisclaimerWeb)

$checkDisclaimerScrollWeb = New-Object System.Windows.Forms.CheckBox
$checkDisclaimerScrollWeb.Location = New-Object System.Drawing.Point(260,15)
$checkDisclaimerScrollWeb.Size = New-Object System.Drawing.Size(150,20)
$checkDisclaimerScrollWeb.Text = "Scrollable"
$groupDisclaimer.Controls.Add($checkDisclaimerScrollWeb)

$labelDisclaimerTitle = New-Object System.Windows.Forms.Label
$labelDisclaimerTitle.Location = New-Object System.Drawing.Point(10,38)
$labelDisclaimerTitle.Size = New-Object System.Drawing.Size(80,20)
$labelDisclaimerTitle.Text = "Message Title"
$textDisclaimerTitle = New-Object System.Windows.Forms.TextBox
$textDisclaimerTitle.Location = New-Object System.Drawing.Point(90,35)
$textDisclaimerTitle.Size = New-Object System.Drawing.Size(110,20)
$groupDisclaimer.Controls.Add($labelDisclaimerTitle)
$groupDisclaimer.Controls.Add($textDisclaimerTitle)

$labelDisclaimerButton = New-Object System.Windows.Forms.Label
$labelDisclaimerButton.Location = New-Object System.Drawing.Point(220,38)
$labelDisclaimerButton.Size = New-Object System.Drawing.Size(70,20)
$labelDisclaimerButton.Text = "Button Text"
$textDisclaimerButton = New-Object System.Windows.Forms.TextBox
$textDisclaimerButton.Location = New-Object System.Drawing.Point(290,35)
$textDisclaimerButton.Size = New-Object System.Drawing.Size(110,20)
$groupDisclaimer.Controls.Add($labelDisclaimerButton)
$groupDisclaimer.Controls.Add($textDisclaimerButton)

$labelDisclaimerMsg = New-Object System.Windows.Forms.Label
$labelDisclaimerMsg.Location = New-Object System.Drawing.Point(10,58)
$labelDisclaimerMsg.Size = New-Object System.Drawing.Size(150,20)
$labelDisclaimerMsg.Text = "Disclaimer Message:"
$textDisclaimerMsg = New-Object System.Windows.Forms.TextBox
$textDisclaimerMsg.Location = New-Object System.Drawing.Point(10,78)
$textDisclaimerMsg.Size = New-Object System.Drawing.Size(400,20)
$groupDisclaimer.Controls.Add($labelDisclaimerMsg)
$groupDisclaimer.Controls.Add($textDisclaimerMsg)

$checkDisclaimerCAG = New-Object System.Windows.Forms.CheckBox
$checkDisclaimerCAG.Location = New-Object System.Drawing.Point(10,110)
$checkDisclaimerCAG.Size = New-Object System.Drawing.Size(240,20)
$checkDisclaimerCAG.Text = "Post-Logon (CAG\Native Receiver + Web)"
$checkDisclaimerCAG.Add_Click({ Validate-SFCClickThrough })
$groupDisclaimer.Controls.Add($checkDisclaimerCAG)

$checkDisclaimerScrollCAG = New-Object System.Windows.Forms.CheckBox
$checkDisclaimerScrollCAG.Location = New-Object System.Drawing.Point(260,110)
$checkDisclaimerScrollCAG.Size = New-Object System.Drawing.Size(150,20)
$checkDisclaimerScrollCAG.Text = "Scrollable"
$groupDisclaimer.Controls.Add($checkDisclaimerScrollCAG)

$labelDisclaimerTitleCAG = New-Object System.Windows.Forms.Label
$labelDisclaimerTitleCAG.Location = New-Object System.Drawing.Point(10,133)
$labelDisclaimerTitleCAG.Size = New-Object System.Drawing.Size(80,20)
$labelDisclaimerTitleCAG.Text = "Message Title"
$textDisclaimerTitleCAG = New-Object System.Windows.Forms.TextBox
$textDisclaimerTitleCAG.Location = New-Object System.Drawing.Point(90,130)
$textDisclaimerTitleCAG.Size = New-Object System.Drawing.Size(110,20)
$groupDisclaimer.Controls.Add($labelDisclaimerTitleCAG)
$groupDisclaimer.Controls.Add($textDisclaimerTitleCAG)

$labelDisclaimerButtonCAG = New-Object System.Windows.Forms.Label
$labelDisclaimerButtonCAG.Location = New-Object System.Drawing.Point(220,133)
$labelDisclaimerButtonCAG.Size = New-Object System.Drawing.Size(70,20)
$labelDisclaimerButtonCAG.Text = "Button Text"
$textDisclaimerButtonCAG = New-Object System.Windows.Forms.TextBox
$textDisclaimerButtonCAG.Location = New-Object System.Drawing.Point(290,130)
$textDisclaimerButtonCAG.Size = New-Object System.Drawing.Size(110,20)
$groupDisclaimer.Controls.Add($labelDisclaimerButtonCAG)
$groupDisclaimer.Controls.Add($textDisclaimerButtonCAG)

$labelDisclaimerMsgCAG = New-Object System.Windows.Forms.Label
$labelDisclaimerMsgCAG.Location = New-Object System.Drawing.Point(10,158)
$labelDisclaimerMsgCAG.Size = New-Object System.Drawing.Size(150,20)
$labelDisclaimerMsgCAG.Text = "Disclaimer Message:"
$textDisclaimerMsgCAG = New-Object System.Windows.Forms.TextBox
$textDisclaimerMsgCAG.Location = New-Object System.Drawing.Point(10,178)
$textDisclaimerMsgCAG.Size = New-Object System.Drawing.Size(400,20)
$groupDisclaimer.Controls.Add($labelDisclaimerMsgCAG)
$groupDisclaimer.Controls.Add($textDisclaimerMsgCAG)

## UI - Footer
$groupFooter = New-Object System.Windows.Forms.GroupBox
$groupFooter.Location = New-Object System.Drawing.Point(10,255)
$groupFooter.Size = New-Object System.Drawing.Size(420,75)
$groupFooter.Text = "Footer Text"
$UITab.Controls.Add($groupFooter)

$checkFooter = New-Object System.Windows.Forms.CheckBox
$checkFooter.Location = New-Object System.Drawing.Point(10,15)
$checkFooter.Size = New-Object System.Drawing.Size(122,20)
$checkFooter.Text = "Footer on All Pages"
$checkFooter.Add_Click({ Validate-SFCFooter })
$groupFooter.Controls.Add($checkFooter)

$labelFooterSize = New-Object System.Windows.Forms.Label
$labelFooterSize.Location = New-Object System.Drawing.Point(130,18)
$labelFooterSize.Size = New-Object System.Drawing.Size(75,20)
$labelFooterSize.Text = "Text Size (px)"
$groupFooter.Controls.Add($labelFooterSize)

$textFooterSize = New-Object System.Windows.Forms.TextBox
$textFooterSize.Location = New-Object System.Drawing.Point(205,15)
$textFooterSize.Size = New-Object System.Drawing.Size(30,20)
$groupFooter.Controls.Add($textFooterSize)

$labelFooterColor = New-Object System.Windows.Forms.Label
$labelFooterColor.Location = New-Object System.Drawing.Point(250,18)
$labelFooterColor.Size = New-Object System.Drawing.Size(110,20)
$labelFooterColor.Text = "Text Color word\hex"
$groupFooter.Controls.Add($labelFooterColor)

$textFooterColor = New-Object System.Windows.Forms.TextBox
$textFooterColor.Location = New-Object System.Drawing.Point(360,15)
$textFooterColor.Size = New-Object System.Drawing.Size(50,20)
$groupFooter.Controls.Add($textFooterColor)

$labelFooterMsg = New-Object System.Windows.Forms.Label
$labelFooterMsg.Location = New-Object System.Drawing.Point(7,45)
$labelFooterMsg.Size = New-Object System.Drawing.Size(60,20)
$labelFooterMsg.Text = "Footer text"
$groupFooter.Controls.Add($labelFooterMsg)

$textFooterMsg = New-Object System.Windows.Forms.TextBox
$textFooterMsg.Location = New-Object System.Drawing.Point(75,42)
$textFooterMsg.Size = New-Object System.Drawing.Size(330,20)
$groupFooter.Controls.Add($textFooterMsg)

#endregion

#region Client tab

$WSCGroup = New-Object System.Windows.Forms.GroupBox
$WSCGroup.Location = New-Object System.Drawing.Point(10,10)
$WSCGroup.Size = New-Object System.Drawing.Size(420,100)
$WSCGroup.Text = "Workspace Control"
$ClientTab.Controls.Add($WSCGroup)

# WSC Enable
$checkWSCEnable = New-Object System.Windows.Forms.CheckBox
$checkWSCEnable.Location = New-Object System.Drawing.Point(10,15)
$checkWSCEnable.Size = New-Object System.Drawing.Size(200,20)
$checkWSCEnable.Text = "Enable"
$checkWSCEnable.Add_Click({ If($checkWSCEnable.Checked){$comboWSCLogoff.Enabled = $true}Else{$comboWSCLogoff.Enabled = $false }})
$WSCGroup.Controls.Add($checkWSCEnable)

# WSC Show reconnect button
$checkWSCReconnect = New-Object System.Windows.Forms.CheckBox
$checkWSCReconnect.Location = New-Object System.Drawing.Point(10,40)
$checkWSCReconnect.Size = New-Object System.Drawing.Size(200,20)
$checkWSCReconnect.Text = "Show Reconnect Button"
$WSCGroup.Controls.Add($checkWSCReconnect)

# WSC auto reconnect at logon
$checkWorkspace = New-Object System.Windows.Forms.CheckBox
$checkWorkspace.Location = New-Object System.Drawing.Point(210,40)
$checkWorkspace.Size = New-Object System.Drawing.Size(200,20)
$checkWorkspace.Text = "Auto reconnect at logon"
$WSCGroup.Controls.Add($checkWorkspace)

# WSC Show disconnect button
$checkWSCDisconnect = New-Object System.Windows.Forms.CheckBox
$checkWSCDisconnect.Location = New-Object System.Drawing.Point(10,65)
$checkWSCDisconnect.Size = New-Object System.Drawing.Size(200,20)
$checkWSCDisconnect.Text = "Show Disconnect Button"
$WSCGroup.Controls.Add($checkWSCDisconnect)

$labelWSClogoff = New-Object System.Windows.Forms.Label
$labelWSClogoff.Location = New-Object System.Drawing.Point(210,68)
$labelWSClogoff.Size = New-Object System.Drawing.Size(80,20)
$labelWSClogoff.Text = "Logoff action"
$comboWSCLogoff = New-Object System.Windows.Forms.ComboBox
$comboWSCLogoff.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboWSCLogoff.Location = New-Object System.Drawing.Size(300,65)
$comboWSCLogoff.Size = New-Object System.Drawing.Size(100,20)
$comboWSCLogoff.Enabled = $false
[void] $comboWSCLogoff.Items.Add("disconnect")
[void] $comboWSCLogoff.Items.Add("none")
[void] $comboWSCLogoff.Items.Add("terminate")
$comboWSCLogoff.SelectedItem = $comboWSCLogoff.Items[0]
$WSCGroup.Controls.Add($labelWSClogoff)
$WSCGroup.Controls.Add($comboWSCLogoff)

# login form timeout
$labelLogonTimeout = New-Object System.Windows.Forms.Label
$labelLogonTimeout.Location = New-Object System.Drawing.Point(10,123)
$labelLogonTimeout.Size = New-Object System.Drawing.Size(160,20)
$labelLogonTimeout.Text = "Login form timeout (seconds)"
$ClientTab.Controls.Add($labelLogonTimeout)

$textLogonTimeout = New-Object System.Windows.Forms.TextBox
$textLogonTimeout.Location = New-Object System.Drawing.Point(170,120)
$textLogonTimeout.Size = New-Object System.Drawing.Size(30,20)
$ClientTab.Controls.Add($textLogonTimeout)

# Multi click timeout
$labelMultiClick = New-Object System.Windows.Forms.Label
$labelMultiClick.Location = New-Object System.Drawing.Point(10,148)
$labelMultiClick.Size = New-Object System.Drawing.Size(160,20)
$labelMultiClick.Text = "Multi-click timeout (seconds)"
$ClientTab.Controls.Add($labelMultiClick)

$textMultiClick = New-Object System.Windows.Forms.TextBox
$textMultiClick.Location = New-Object System.Drawing.Point(170,145)
$textMultiClick.Size = New-Object System.Drawing.Size(30,20)
$ClientTab.Controls.Add($textMultiClick)

# special folder redirection
$checkSFR = New-Object System.Windows.Forms.CheckBox
$checkSFR.Location = New-Object System.Drawing.Point(10,170)
$checkSFR.Size = New-Object System.Drawing.Size(200,20)
$checkSFR.Text = "Special Folder Redirection"
$ClientTab.Controls.Add($checkSFR)

# HTML 5 single tab launch
$checkHTMLTab = New-Object System.Windows.Forms.CheckBox
$checkHTMLTab.Location = New-Object System.Drawing.Point(10,195)
$checkHTMLTab.Size = New-Object System.Drawing.Size(250,20)
$checkHTMLTab.Text = "HTML5 Client single tab launch"
$ClientTab.Controls.Add($checkHTMLTab)

# Single FQDN Accounts URL
$checkSingleFQDN = New-Object System.Windows.Forms.CheckBox
$checkSingleFQDN.Location = New-Object System.Drawing.Point(10,220)
$checkSingleFQDN.Size = New-Object System.Drawing.Size(170,20)
$checkSingleFQDN.Text = "Single FQDN Accounts URL"
$checkSingleFQDN.Add_Click({ If($checkSingleFQDN.Checked){$textSingleFQDN.Enabled = $true}Else{$textSingleFQDN.Enabled = $false} })
$ClientTab.Controls.Add($checkSingleFQDN)

$textSingleFQDN = New-Object System.Windows.Forms.TextBox
$textSingleFQDN.Location = New-Object System.Drawing.Point(180,220)
$textSingleFQDN.Size = New-Object System.Drawing.Size(200,20)
$ClientTab.Controls.Add($textSingleFQDN)
 
#endregion

#region Server tab

$checkPluginUpgrade = New-Object System.Windows.Forms.CheckBox
$checkPluginUpgrade.Location = New-Object System.Drawing.Point(10,10)
$checkPluginUpgrade.Size = New-Object System.Drawing.Size(250,20)
$checkPluginUpgrade.Text = "Enable plugin upgrade"
$ServerTab.Controls.Add($checkPluginUpgrade)

# Simple workflow handler
$checkWorkflow = New-Object System.Windows.Forms.CheckBox
$checkWorkflow.Location = New-Object System.Drawing.Size(10,35)
$checkWorkflow.Size = New-Object System.Drawing.Size(270,20)
$checkWorkflow.Text = 'Enable Simple Workflow Handler'
$checkWorkflow.Add_Click({ If($checkWorkflow.Checked){[System.Windows.Forms.MessageBox]::Show("This setting will only apply configuration to the web.config file.`nDownloading the SimpleWorkflowHandler DLL manually is required.`n`nMore information is available: http://blogs.citrix.com/2015/08/17/citrix-recipe-box-storefront-approvals/`n`nDownload: https://citrix.sharefile.com/share#/download/s7c25c2e742e41f7b" , "Note")} })
$ServerTab.Controls.Add($checkWorkflow)

# Add custom Header
$checkCustomHeader = New-Object System.Windows.Forms.CheckBox
$checkCustomHeader.Location = New-Object System.Drawing.Size(10,60)
$checkCustomHeader.Size = New-Object System.Drawing.Size(270,20)
$checkCustomHeader.Text = 'Allow Custom Header Pass to Customization'
$checkCustomHeader.Add_Click({ If($checkCustomHeader.Checked){$textCustomHeader.Enabled = $true}Else{$textCustomHeader.Enabled = $false} })
$ServerTab.Controls.Add($checkCustomHeader)

$textCustomHeader = New-Object System.Windows.Forms.TextBox
$textCustomHeader.Location = New-Object System.Drawing.Size(290,60)
$textCustomHeader.Size = New-Object System.Drawing.Size(110,20)
$textCustomHeader.Enabled = $false
$ServerTab.Controls.Add($textCustomHeader)

# Optimal Gateway routing
$optGWGroup = New-Object System.Windows.Forms.GroupBox
$optGWGroup.Location = New-Object System.Drawing.Point(10,85)
$optGWGroup.Size = New-Object System.Drawing.Size(420,315)
$optGWGroup.Text = "Optimal Gateway Routing"
$ServerTab.Controls.Add($optGWGroup)

$checkGWEnable = New-Object System.Windows.Forms.CheckBox
$checkGWEnable.Location = New-Object System.Drawing.Point(10,20)
$checkGWEnable.Size = New-Object System.Drawing.Size(130,20)
$checkGWEnable.Text = "Enabled"
$checkGWEnable.Add_Click({Validate-SFCOptimalGW "init"})
$optGWGroup.Controls.Add($checkGWEnable)

$checkGWNull = New-Object System.Windows.Forms.CheckBox
$checkGWNull.Location = New-Object System.Drawing.Point(150,20)
$checkGWNull.Size = New-Object System.Drawing.Size(130,20)
$checkGWNull.Text = "Set Null Gateway"
$optGWGroup.Controls.Add($checkGWNull)

$labelGWName = New-Object System.Windows.Forms.Label
$labelGWName.Location = New-Object System.Drawing.Point(10,48)
$labelGWName.Size = New-Object System.Drawing.Size(130,20)
$labelGWName.Text = "Select Primary Gateway"
$optGWGroup.Controls.Add($labelGWName)

$comboGWName = New-Object System.Windows.Forms.ComboBox
$comboGWName.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboGWName.Location = New-Object System.Drawing.Point(140,45)
$comboGWName.Size = New-Object System.Drawing.Size(150,20)
$comboGWName.Add_SelectedIndexChanged({Validate-SFCOptimalGW 'values' })
$optGWGroup.Controls.Add($comboGWName)

$labelGWFQDN = New-Object System.Windows.Forms.Label
$labelGWFQDN.Location = New-Object System.Drawing.Point(10,73)
$labelGWFQDN.Size = New-Object System.Drawing.Size(90,20)
$labelGWFQDN.Text = "Gateway FQDN: "
$optGWGroup.Controls.Add($labelGWFQDN)

$textGWFQDN = New-Object System.Windows.Forms.TextBox
$textGWFQDN.Location = New-Object System.Drawing.Point(100,70)
$textGWFQDN.Size = New-Object System.Drawing.Size(300,20)
$textGWFQDN.ReadOnly = $true
$textGWFQDN.Text = ""
$optGWGroup.controls.Add($textGWFQDN)

$checkGWSR = New-Object System.Windows.Forms.CheckBox
$checkGWSR.Location = New-Object System.Drawing.Point(10,95)
$checkGWSR.Size = New-Object System.Drawing.Size(180,20)
$checkGWSR.Text = "Enable Session Reliability"
$optGWGroup.Controls.Add($checkGWSR)

$checkGWDirect = New-Object System.Windows.Forms.CheckBox
$checkGWDirect.Location = New-Object System.Drawing.Point(200,95)
$checkGWDirect.Size = New-Object System.Drawing.Size(170,20)
$checkGWDirect.Text = "Enabled for Direct Access"
$optGWGroup.Controls.Add($checkGWDirect)

$labelGWFarms = New-Object System.Windows.Forms.Label
$labelGWFarms.Location = New-Object System.Drawing.Point(10,120)
$labelGWFarms.Size = New-Object System.Drawing.Size(150,15)
$labelGWFarms.Text = "XenApp\XenDesktop Farms"
$optGWGroup.Controls.Add($labelGWFarms)

$textGWFarms = New-Object System.Windows.Forms.TextBox
$textGWFarms.Location = New-Object System.Drawing.Point(10,135)
$textGWFarms.Size = New-Object System.Drawing.Size(400,50)
$textGWFarms.ReadOnly = $true
$textGWFarms.Multiline = $true
$textGWFarms.ScrollBars = 'Both'
$textGWFarms.Text = ""
$optGWGroup.Controls.Add($textGWFarms)

$labelGWSTA = New-Object System.Windows.Forms.Label
$labelGWSTA.Location = New-Object System.Drawing.Point(10,190)
$labelGWSTA.Size = New-Object System.Drawing.Size(400,15)
$labelGWSTA.Text = "STA URLs"
$optGWGroup.Controls.Add($labelGWSTA)

$textGWSTA = New-Object System.Windows.Forms.TextBox
$textGWSTA.Location = New-Object System.Drawing.Point(10,205)
$textGWSTA.Size = New-Object System.Drawing.Size(400,50)
$textGWSTA.ReadOnly = $true
$textGWSTA.Multiline = $true
$textGWSTA.ScrollBars = 'Both'
$textGWSTA.Text = ""
$optGWGroup.Controls.Add($textGWSTA)

$checkGWTwoSTA = New-Object System.Windows.Forms.CheckBox
$checkGWTwoSTA.Location = New-Object System.Drawing.Point(10,262)
$checkGWTwoSTA.Size = New-Object System.Drawing.Size(170,20)
$checkGWTwoSTA.Text = "Use two STA Tickets"
$optGWGroup.Controls.Add($checkGWTwoSTA)

$checkGWUseLB = New-Object System.Windows.Forms.CheckBox
$checkGWUseLB.Location = New-Object System.Drawing.Point(190,262)
$checkGWUseLB.Size = New-Object System.Drawing.Size(170,20)
$checkGWUseLB.Text = "Load balance STA requests"
$optGWGroup.Controls.Add($checkGWUseLB)

$labelGWSTABypass = New-Object System.Windows.Forms.Label
$labelGWSTABypass.Location = New-Object System.Drawing.Point(10,290)
$labelGWSTABypass.Size = New-Object System.Drawing.Size(115,20)
$labelGWSTABypass.Text = "STA Bypass duration:"
$optGWGroup.Controls.Add($labelGWSTABypass)

$textGWBypass = New-Object System.Windows.Forms.TextBox
$textGWBypass.Location = New-Object System.Drawing.Point(125,287)
$textGWBypass.Size = New-Object System.Drawing.Size(100,20)
$textGWBypass.Text = ""
$optGWGroup.controls.Add($textGWBypass)

$optGWGroup.Enabled = $false

#endregion

#region MultiSite tab

$checkMultiEnable = New-Object System.Windows.Forms.CheckBox
$checkMultiEnable.Location = New-Object System.Drawing.Point(10,10)
$checkMultiEnable.Size = New-Object System.Drawing.Size(150,20)
$checkMultiEnable.Text = "Multi-Site Configuration"
$checkMultiEnable.Add_Click({ Validate-SFCMultiSite })
$multiTab.Controls.Add($checkMultiEnable)

$linkAddFarmMapping = New-Object System.Windows.Forms.Button
$linkAddFarmMapping.Location = New-Object System.Drawing.Point(200,10)
$linkAddFarmMapping.Size = New-Object System.Drawing.Size(120,20)
$linkAddFarmMapping.Text = "Add Farm Mapping"
$multiTab.Controls.Add($linkAddFarmMapping)
$linkAddFarmMapping.Add_Click({ Add-SFCFarmMapping; Add-SFCEquivFarmSet $script:intFarmMappings })

#endregion

# Add closing buttons
$SetButton = New-Object System.Windows.Forms.Button
$SetButton.Location = New-Object System.Drawing.Size(300,530)
$SetButton.Text = "Apply"

$SFCForm.Controls.Add($SetButton)
$SetButton.Add_Click({Apply_Click})

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(380,530)
$CancelButton.Text = "Cancel"

$SFCForm.Controls.Add($CancelButton)
$CancelButton.Add_Click({Cancel_Click})


Function Cancel_Click()
{
    Write-EventLog –LogName Application –Source “Citrix StoreFront Configurator” –EntryType Information –EventID 100 –Message “SFC cancelled - no changes made."
    $SFCForm.Close()
}

Function Apply_Click()
{
    $storeVirtualPath = ($script:ctxSFStores | Where {$_.Name -eq $script:servicesStore}).VirtualPath

    # Set common items
    If($checkDefaultDoc.Checked) { Add-SFCDefaultDocument }
    If($checkCRL.Checked) { Set-SFCCRLCheck -enable $true }Else{ Set-SFCCRLCheck -enable $false }
    If($checkWorkflow.Checked) { Enable-SFCSimpleWorkflow -enable $true}Else { Enable-SFCSimpleWorkflow -enable $false}
    
    If($checkCategories.Checked) { Set-SFCAppCategories "$($strCurrentWebStore)\custom\script.js" -enable $true }
    If(!($checkCategories.Checked) -and $script:boolCategories) { Set-SFCAppCategories "$($strCurrentWebStore)\custom\script.js" -enable $false }
    
    If($checkNative.Checked) { Deploy-SFCReceivers "$($strCurrentWebStore)\web.config" }Else{ Deploy-SFCReceivers "$($strCurrentWebStore)\web.config" -receiverLocation "Citrix" }
    If($checkPluginUpgrade.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.upgradeAtLogin = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.upgradeAtLogin = "false"}

    $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.defaultView = $comboWebTabs.SelectedItem.ToString()

    # Set apps and desktops tabs
    If($checkDesktopView.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.showDesktopsView = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.showDesktopsView = "false"}

    If($checkAppsView.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.showAppsView = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.uiViews.showAppsView = "false"}

    If($checkAppCatView.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.enableAppsFolderView = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.enableAppsFolderView = "false"}

    # Set HTML5 single tab
    If($checkHTMLTab.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.html5.singleTabLaunch = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.pluginAssistant.html5.singleTabLaunch = "false"}

    If ($checkLaunch.Checked)
    {
        # Replace-SFCValue -findValue autoLaunchDesktop -setValue true -fileName "$($strCurrentWebStore)\web.config"
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.autoLaunchDesktop = "true"
    }
        Else
    {
        # Replace-SFCValue -findValue autoLaunchDesktop -setValue false -fileName "$($strCurrentWebStore)\web.config"
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.autoLaunchDesktop = "false"
    }
    
    If ($checkWorkspace.Checked)
    {
        # Replace-SFCValue -findValue autoReconnectAtLogon -setValue true -fileName "$($strCurrentWebStore)\web.config"
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.autoReconnectAtLogon = "true"
    }
    Else
    {
        # Replace-SFCValue -findValue autoReconnectAtLogon -setValue false -fileName "$($strCurrentWebStore)\web.config"
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.autoReconnectAtLogon = "false"
    }

    If ($checkCustomHeader.Checked)
    {
        Add-SFCForwardHeader -fileName "$($strCurrentWebStore)\web.config" -strHeader $textCustomHeader.Text
    }

    # Set dynamic header
    If ($checkDynHeader.Checked){ Set-SFCDynHeader -fileName "$($strCurrentWebStore)\custom\script.js" -enable $true}
    If (!($checkDynHeader.Checked) -and ($script:boolDynHeader)){ Set-SFCDynHeader -fileName "$($strCurrentWebStore)\custom\script.js"}

    # Set logon disclaimer - web
    If ($checkDisclaimerWeb.Checked -and !($script:boolDisclaimerWeb))
    {
        Set-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -action 'enable' -location web -title $textDisclaimerTitle.Text -text $textDisclaimerMsg.Text -button $textDisclaimerButton.Text -scroll $checkDisclaimerScrollWeb.Checked
    }
    If ($checkDisclaimerWeb.Checked -and $script:boolDisclaimerWeb)
    {
        Set-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -action 'update' -location web -title $textDisclaimerTitle.Text -text $textDisclaimerMsg.Text -button $textDisclaimerButton.Text -scroll $checkDisclaimerScrollWeb.Checked
    }
    If (!($checkDisclaimerWeb.Checked) -and $script:boolDisclaimerWeb)
    {
        Set-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -action 'disable' -location web
    }
    # Set logon disclaimer - cag
    If ($checkDisclaimerCAG.Checked -and !($script:boolDisclaimerCAG))
    {
        Set-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -action 'enable' -location cag -title $textDisclaimerTitleCAG.Text -text $textDisclaimerMsgCAG.Text -button $textDisclaimerButtonCAG.Text -scroll $checkDisclaimerScrollCAG.Checked
    }
    If ($checkDisclaimerCAG.Checked -and $script:boolDisclaimerCAG)
    {
        Set-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -action 'update' -location cag -title $textDisclaimerTitleCAG.Text -text $textDisclaimerMsgCAG.Text -button $textDisclaimerButtonCAG.Text -scroll $checkDisclaimerScrollCAG.Checked
    }
    If (!($checkDisclaimerCAG.Checked) -and $script:boolDisclaimerCAG)
    {
        Set-SFCClickThrough -fileName "$($strCurrentWebStore)\custom\script.js" -action 'disable' -location cag
    }

    If ($checkFooter.Checked -and !($script:boolFooter)){Set-SFCFooter -filename "$($strCurrentWebStore)\custom\script.js" -action 'enable' -size $textFooterSize.Text -color $textFooterColor.Text -msg $textFooterMsg.Text}
    If ($checkFooter.Checked -and $script:boolFooter){Set-SFCFooter -filename "$($strCurrentWebStore)\custom\script.js" -action 'update' -size $textFooterSize.Text -color $textFooterColor.Text -msg $textFooterMsg.Text}
    If (!($checkFooter.Checked) -and $script:boolFooter){Set-SFCFooter -filename "$($strCurrentWebStore)\custom\script.js" -action 'disable'}

    # Set WSC items
    If($checkWSCEnable.Checked)
    {
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.enabled = "true"
        $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.logoffAction = $comboWSCLogoff.SelectedItem.ToString()
    }
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.enabled = "false"}

    If($checkWorkspace.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.autoReconnectAtLogon = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.autoReconnectAtLogon = "false"}

    If($checkWSCReconnect.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.showReconnectButton = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.showReconnectButton = "false"}
    
    If($checkWSCDisconnect.Checked){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.showDisconnectButton = "true"}
    Else{$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.workspaceControl.showDisconnectButton = "false"}

    # Set SFR
    If($checkSFR.Checked){$script:currentStoreXML.configuration.'citrix.deliveryservices'.wing.resources.ChildNodes.launch.allowSpecialFolderRedirection = "on"}
    Else{$script:currentStoreXML.configuration.'citrix.deliveryservices'.wing.resources.ChildNodes.launch.allowSpecialFolderRedirection = "off"}

    $script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.authManager.loginFormTimeout = $textLogonTimeout.Text.ToString()
    If($textMultiClick.Enabled){$script:currentWebStoreXML.configuration.'citrix.deliveryservices'.webReceiver.clientSettings.userInterface.multiClickTimeout = $textMultiClick.Text.ToString()}

    If(!($script:boolSingleFQDN) -and $checkSingleFQDN.Checked){Set-SFCSingleFQDN -enable $true}
    If($script:boolSingleFQDN -and !($checkSingleFQDN.Checked)){Set-SFCSingleFQDN -enable $false}

    # Multi Site XML config
    If($checkMultiEnable.Checked -and !($script:boolMultiSite)){Build-SFCMultiSiteXML}
    ElseIf($checkMultiEnable.Checked -and $script:boolMultiSite){Set-SFCMultiSite -enable $true}
    ElseIf(!($checkMultiEnable.Checked) -and $script:boolMultiSite){Set-SFCMultiSite -enable $false}

    # Save XML files
    Backup-SFCFile "$($script:strCurrentWebStore)\web.config"
    Backup-SFCFile "$($script:strCurrentStore)\web.config"
    $script:currentWebStoreXML.Save("$($script:strCurrentWebStore)\web.config")
    $script:currentStoreXML.Save("$($script:strCurrentStore)\web.config")

    If ($checkKeyFilter.Checked)
    {
        If($comboKeyFilter.SelectedItem.ToString() -eq "Include"){Set-DSResourceFilterKeyword -SiteId $script:ctxSiteID -VirtualPath $storeVirtualPath -IncludeKeywords @($textKeyFilter.Text -split ",")}
        Else{Set-DSResourceFilterKeyword -SiteId $script:ctxSiteID -VirtualPath $storeVirtualPath -ExcludeKeywords @($textKeyFilter.Text -split ",")}
        $script:modFiles += "Keyword filering via DS PoSH"
    }
    Else{Set-DSResourceFilterKeyword -SiteId $script:ctxSiteID -VirtualPath $storeVirtualPath -IncludeKeywords @()}

    # Set Type Filter settings
    $includedTypes = @()
    If($checkTypeApps.Checked){$includedTypes += "Applications"}
    If($checkTypeDesk.Checked){$includedTypes += "Desktops"}
    If($checkTypeDocs.Checked){$includedTypes += "Documents"}
    Set-DSResourceFilterType -SiteId $script:ctxSiteID -VirtualPath $storeVirtualPath -IncludeTypes $includedTypes

    # Set Optimal Gateway routing
    If($checkGWEnable.Checked){Set-SFCOptimalGW 'enable'; $script:modFiles += "Optimal Gateway Routing Configuration via DS PoSH"}
    If(!($checkGWEnable.Checked) -and $script:boolGWUpdate){Set-SFCOptimalGW 'disable'}

    If($checkPropChanges.Checked)
    {
        Add-PSSnapin Citrix.DeliveryServices.ConfigurationReplication.Command
        Start-DSConfigurationReplicationClusterUpdate -Confirm:$false
        Write-EventLog –LogName Application –Source “Citrix StoreFront Configurator” –EntryType Information –EventID 101 –Message “SFC has initiated a StoreFront cluster replication."
    }
    [System.Windows.Forms.MessageBox]::Show("Settings applied to Storefront.`nModified files backed up to: $($psscriptroot)" , "Status")

    Write-EventLog –LogName Application –Source “Citrix StoreFront Configurator” –EntryType Information –EventID 101 –Message “SFC has modified the following items:`n`r$($script:modFiles -join "`n")"
    $SFCForm.Close()
}

Set-SFCInit

New-EventLog –LogName Application –Source “Citrix StoreFront Configurator” -ErrorAction SilentlyContinue
Write-EventLog –LogName Application –Source “Citrix StoreFront Configurator” –EntryType Information –EventID 100 –Message “SFC launched by $([Environment]::username) - gathering StoreFront configuration."

$SFCForm.ShowDialog() | Out-Null
Remove-Variable * -ErrorAction SilentlyContinue

# SIG # Begin signature block
# MIINDQYJKoZIhvcNAQcCoIIM/jCCDPoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU2mUrXKB4x5SwpujnMigBUzhc
# 1N6gggpPMIIFFzCCA/+gAwIBAgIQD2hVwmXYvc9CuR/V3bYPoTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE1MDkxODAwMDAwMFoXDTE2MDky
# MjEyMDAwMFowXjELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1EMRQwEgYDVQQHEwtD
# cm93bnN2aWxsZTEVMBMGA1UEChMMSmFjb2IgUnV0c2tpMRUwEwYDVQQDEwxKYWNv
# YiBSdXRza2kwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDFLnK9TPSy
# UefZTT2YqEKzutYva/lUW8pHydko2k7GDmWLN8XMLMNoaRbgc+WVceNBi+G5HrOs
# zcjfiggHbTYrk+hGuxVnqKGI0AaVIQPkYLnYrXir75bxaDMtwSqD2olFe3XNAdg+
# eQDHViEMauJDDjywKRmZ4mw4Uv9KGcASWfY0ONFwy5lCOKh2i2K19Y5sFM97B6/f
# 5jpbyxMmSzl3drj5zkyRIvghCrbNxHT+SZtW0U1Cfw7xosfCWmvtMnO4W6ej57sI
# 4MwI6LNiapHB4wBzWM13+L6YMQBwtzHkA9pWGwC+sKjLaYJ2V5CuMUNc9kTUDZzJ
# Z8QtVYXw2BkhAgMBAAGjggG7MIIBtzAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg
# +S32ZXUOWDAdBgNVHQ4EFgQUWTB3LQn75DFStSMYxqkYZWcfd6swDgYDVR0PAQH/
# BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0
# dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWg
# M6Axhi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcx
# LmNybDBCBgNVHSAEOzA5MDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRw
# czovL3d3dy5kaWdpY2VydC5jb20vQ1BTMIGEBggrBgEFBQcBAQR4MHYwJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcwAoZCaHR0
# cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRENv
# ZGVTaWduaW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEB
# APQo3UxuU3UzVEJXK7Bg1GA37gokmzd/BAm56TtYO3tWuy/h/jH3Eh9dJumFierb
# +kBYw1O7r4F3uCGBykvPOFNExMqoS6a9YX0UBTC+cn16ivFLfUmSG24nu37ZvyEI
# JSdL6TqduG9L8tqpO0bZEuk1jv0/gjzgtGbJsidrqaWoJnkj4aaUdVum69C4NFfh
# JkfAxFxpbQl2AceUlmbBaLRxNfu8ZutTIJJFOlMlqHSmTFDilH8NG8o7gUg1fr7u
# 7lgsmSCOxiSFK6JFQ0BHihPvsTdSFFVFnTzxBaCkkrHLtEIqERt0gEk67XHGfL4O
# lAeu+ayIHCpIRNUAAZNWDAgwggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAI
# MA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lD
# ZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIx
# MjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIg
# QXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nad
# BS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3
# gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+
# qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv
# 5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFi
# g3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMB
# Af8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# AzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0
# aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNz
# dXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggr
# BgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1s
# AzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReui
# r/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXI
# LHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlri
# XiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTG
# xycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtA
# RKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEg
# zpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecY
# pJpkUe8xggIoMIICJAIBATCBhjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhE
# aWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBAhAPaFXCZdi9
# z0K5H9Xdtg+hMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQSZIEFQA1GaF4v82/Sh0BNr0GiXzAN
# BgkqhkiG9w0BAQEFAASCAQAv8M31shOMDGRUnOrKJJmGwB7Kp5FDf755SGI/6qtV
# w48Dtd15XxiS3LQVaSxk1Fiw7DcSSElU/LATjAkyMpdi8zlvzseXTUXXV9ZJUK7l
# HoFtU/9WXsVEqfzINyFTVrmkKKszqoG2Ycesg1fN7d0KYfWBawN/g35OG5DmA3jm
# wFjKfTRegYhVzlLLemW+D0Og0PcONda3fUiTvt/WLaA3EudhfbLCqcS49uYnWFdP
# uUiLFG2IlUuxHADTGHjX4I3UR+5LBCQ8SU8yvaXs9SStMMbSW3OQ3KJ84yyKIDa5
# gydnZiaC+oz8uTuLI+s9NAc6QC/pngpEz3kmvkzMZ4RV
# SIG # End signature block
