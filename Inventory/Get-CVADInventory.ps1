<#
.SYNOPSIS
  Creates a webpage showing the inventory of the CVAD site
.DESCRIPTION
  This will get varied bits of information regarding the CVAD site and creates an
  index.html file in a reports virual directory of the DeliveryController
.EXAMPLE
  Get-CVADInventory -DeliveryController NYC-VDC-001.workspacelab.com
  This communicates with the DDC listed on the commandline to extract the information
  required for the inventory 
.PARAMTER DeliveryController
  This indicates which delivery controller to communicate with to get the site information
.NOTES
  General notes
    Created by : Brent Denny
    Created on : 18 Apr 2021
    Modified on: 20 Apr 2021
#>
[Cmdletbinding()]
Param (
  [string]$DeliveryController = 'localhost'
)
Add-PSSnapin Citrix*

# ------------Funtions-------------
function Get-CSS {
  $CSSContent = @'
<style>
<style>
body {font-family: Arial, Helvetica, sans-serif;}
h1,h2 {text-align: center;color:#001773;}
table.ListTable {font-family: Arial, Helvetica, sans-serif;border-collapse: collapse;width: auto;}
th.Test {background-color:green;}
h2.Test {color:green}
table {font-family: Arial, Helvetica, sans-serif;border-collapse: collapse;width: 100%;}
td, th {border: 1px solid #ddd;padding: 8px;}
tr:nth-child(even){background-color: #f2f2f2;}
tr:hover {background-color: #ddd;}
th {padding-top: 12px;padding-bottom: 12px;text-align: left;background-color: #001773;color:White;}
</style>
'@
  $CSSContent
}
function Get-CTXSite {
  Param ([string]$DDC)
  $CTXSite = Get-BrokerSite -AdminAddress $DDC
  $CtxDBConn = Get-BrokerDBConnection -AdminAddress $DDC
  $CTXSiteHTML = $CTXSite | Select-Object -Property Name,LicenseServerName,LicenseServerPort,LicensingGracePeriodActive,LicensedSessionsActive,LicenseModel,@{n='DBConnection';e={$CtxDBConn}} | 
    ConvertTo-Html -Fragment -PreContent '<h1>Virtual Apps and Desktop Site Information</h1>' -As List | Out-String
  $CTXSiteHTML -replace '<table>','<table Class=ListTable>' -replace '<tr><td>','<tr><th>' -replace '</td><td>','</th><td>'
}
function Get-CtxMachCat {
  Param ([string]$DDC)
  $CTXCat = Get-BrokerCatalog -AdminAddress $DDC
  $CTXCatHtml = $CTXCat | Select-Object -Property Name,AllocationType,SessionSupport,ZoneName | 
    ConvertTo-Html -Fragment -PreContent '<br><br><h2>Machine Catalogs</h2>' | Out-String
  $CTXCatHtml
}
function Get-CtxDelGrp {
  Param ([string]$DDC)
  $CTXDelGrp = Get-BrokerDesktopGroup -AdminAddress $DDC
  $CTXDelGrpHtml = $CTXDelGrp | Select-Object -Property Name,DeliveryType,DesktopKind,Enabled,InMaintenanceMode | 
    ConvertTo-Html -Fragment -PreContent '<br><br><h2>Delivery Groups</h2>' | Out-String
  $CTXDelGrpHtml
}
function Get-CtxDDC {
  Param ([string]$DDC)
  $CTXDDC = Get-BrokerController -AdminAddress $DDC
  $CTXDDCHtml = $CTXDDC | Select-Object -Property DNSName,ControllerVersion,OSType,State,LastStartTime | 
    ConvertTo-Html -Fragment -PreContent '<br><br><h2>Delivery Controllers</h2>' | Out-String
  $CTXDDCHtml
}
function Get-CtxApp {
  Param ([string]$DDC)
  $CTXApp = Get-BrokerApplication -AdminAddress $DDC
  $CTXAppHtml = $CTXApp | Select-Object -Property ApplicationName,Enabled,Visible,HomeZoneName | 
    ConvertTo-Html -Fragment -PreContent '<br><br><h2>Applications</h2>' | Out-String
  $CTXAppHtml  
}
function Get-CtxSession {
  Param ([string]$DDC)
  $CTXSession = Get-BrokerSession -AdminAddress $DDC
  $CTXSessionHtml = $CTXSession | Select-Object -Property @{n='Applications';e={$_.ApplicationsInUse -join ';'}},ClientName,ClientAddress,ClientVersion,BrokeringTime,SessionType,SessionState,UserName,ZoneName  |
    ConvertTo-Html -Fragment -PreContent '<br><br><h2>Sessions</h2>' | Out-String
  $CTXSessionHtml  
}
function Get-CtxZone {
  Param ([string]$DDC)
  $CTXZone = Get-ConfigZone -AdminAddress $DDC
  $CTXZoneHtml = $CTXZone | Select-Object -Property Name,@{n='Controllers';e={$_.ControllerNames -join ';'}}  |
    ConvertTo-Html -Fragment -PreContent '<br><br><h2>Zones</h2>' | Out-String
  $CTXZoneHtml
}
function Get-CtxVDA {
  Param ([string]$DDC)
  $CTXVDA = Get-BrokerMachine -AdminAddress $DDC
  $CTXVDAHtml = $CTXVDA | Select-Object -Property MachineName,InMaintenanceMode,LoadIndex,RegistrationState,SummaryState,SessionSupport,LastConnectionUser,LastConnectionTime  |
    ConvertTo-Html -Fragment -PreContent '<br><br><h2>Virtual Delivery Agents</h2>' | Out-String
  $CTXVDAHtml
}

function Test-CtxBkrDB {
  Param ([string]$DDC)
  $CTXBkrDB = New-Object -TypeName psobject -Property (Test-BrokerDBConnection -DBConnection (Get-BrokerDBConnection -AdminAddress $DDC)).ExtraInfo
  $CTXBkrDBHTML = $CTXBkrDB | ConvertTo-Html -Fragment -PreContent '<h2 class=Test>Broker DB Connections Test</h2>' -As List | Out-String
  $CTXBkrDBHTML -replace '<table>','<table Class=ListTable>' -replace '<tr><td>','<tr><th Class=Test>' -replace '</td><td>','</th><td>'
}
# ----------------Main Code ----------------
try {
  if (-not (Test-Path -PathType Container -Path C:\inetpub\wwwroot\reports)) {
    New-Item -Path C:\inetpub\wwwroot -Name Reports -ItemType Directory -ErrorAction Stop
  }
}
catch {write-warning "could not create the reports path under the IIS web directory"}

$SiteFrag = Get-CTXSite -DDC $DeliveryController
$MachCatFrag = Get-CtxMachCat -DDC $DeliveryController 
$DelGrpFrag = Get-CtxDelGrp -DDC $DeliveryController
$DDCFrag = Get-CtxDDC -DDC $DeliveryController
$AppsFrag = Get-CtxApp -DDC $DeliveryController
$SessFrag = Get-CtxSession -DDC $DeliveryController
$ZoneFrag = Get-CtxZone -DDC $DeliveryController
$VDAFrag = Get-CtxVDA -DDC $DeliveryController
$TestBkrDBFrag = Test-CtxBkrDB -DDC $DeliveryController

$WebPage = ConvertTo-Html -Head (Get-CSS) -Body $SiteFrag,$ZoneFrag,$DDCFrag,$MachCatFrag,$DelGrpFrag,$AppsFrag,$SessFrag,$VDAFrag,'<br><br><br><br><hr>',$TestBkrDBFrag
$WebPage | Out-File C:\inetpub\wwwroot\reports\index.html -Force 