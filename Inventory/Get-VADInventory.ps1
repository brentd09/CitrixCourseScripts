[Cmdletbinding()]
Param (
  [string]$DeliveryController = 'localhost'
)
Add-PSSnapin Citrix*
function Get-CSS {
  $CSSContent = @'
<style>
<style>
body {font-family: Arial, Helvetica, sans-serif;}
h2 {text-align: center;}
table.ListTable {font-family: Arial, Helvetica, sans-serif;border-collapse: collapse;width: auto;}
table {font-family: Arial, Helvetica, sans-serif;border-collapse: collapse;width: 100%;}
td, th {border: 1px solid #ddd;padding: 8px;}
tr:nth-child(even){background-color: #f2f2f2;}
tr:hover {background-color: #ddd;}
th {padding-top: 12px;padding-bottom: 12px;text-align: left;background-color: #4CAF50;color: white;}
</style>
'@
  $CSSContent
}

function Get-CTXSite {
  Param ([string]$DDC)
  $CTXSite = Get-BrokerSite -AdminAddress $DDC
  $CTXSiteHTML = $CTXSite | Select-Object -Property Name,LicenseServerName,LicensedSessionsActive,LicenseModel | 
    ConvertTo-Html -Fragment -PreContent '<h2>Site Information</h2>' -As List | Out-String
  $CTXSiteHTML -replace '<table>','<table Class=ListTable>' -replace '<tr><td>','<tr><th>' -replace '</td><td>','</th><td>'
}

function Get-CtxMachCat {
  Param ([string]$DDC)
  $CTXCat = Get-BrokerCatalog -AdminAddress $DDC
  $CTXCatHtml = $CTXCat | Select-Object -Property Name,AllocationType,SessionSupport,ZoneName | 
    ConvertTo-Html -Fragment -PreContent '<br><h2>Machine Catalogs</h2>' | Out-String
  $CTXCatHtml
}

function Get-CtxDelGrp {
  Param ([string]$DDC)
  $CTXDelGrp = Get-BrokerDesktopGroup -AdminAddress $DDC
  $CTXDelGrpHtml = $CTXDelGrp | Select-Object -Property Name,DeliveryType,DesktopKind,Enabled,InMaintenanceMode | 
    ConvertTo-Html -Fragment -PreContent '<br><h2>Delivery Groups</h2>' | Out-String
  $CTXDelGrpHtml
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


$WebPage = ConvertTo-Html -Head (Get-CSS) -Body $SiteFrag,$MachCatFrag,$DelGrpFrag
$WebPage | Out-File C:\inetpub\wwwroot\reports\index.html -Force 