<#
.Synopsis
   This script queries a NetScaler ADC for its configuration
.DESCRIPTION
   Once the script has queried the NetScaler for its configuration
   it converts the settings that are present into html fragments
   which are combined with all of the other settings to produce a
   HTML document.
   If an ADCObjectName is not specified, this script searches for 
   all configuration categories in the NS that have a current 
   configruation, if an ADCObjectName/s are specified it will only 
   search for these specifically.
   The script will also prompt for Netscaler credentials.
.EXAMPLE
   Get-ADCConfig.ps1 -ADCAddress 192.168.10.101 -HTMLOutputFile c:\temp\ADCReport.html 
   This will connect to a NetScaler on 192.168.10.101 and get all 
   of the configs and convert them into a HTML report named: ADCReport.html 
.EXAMPLE
   Get-ADCConfig.ps1 -ADCAddress 192.168.10.101 -HTMLOutputFile c:\temp\ADCReport.html -AdcObjectName Interface,arp 
   This will connect to a NetScaler on 192.168.10.101 and get only 
   config info from Interface and arp and convert these into a HTML 
   report named: ADCReport.html 
.PARAMETER AdcObjectName
   This parameter accepts names of configuration categories within the
   NetScaler ADC and can accept one or more as an array
.PARAMETER ADCAddress
   This parameter accepts the address of the NetScaler ADC, this could
   be either and IPAddress or a FQDN
.PARAMETER HTMLOutputFile
   This parameter accepts the file path of the html document that will
   be produced by this script. Make sure the file ends with .html 
   example c:\inetpub\wwwroot\ADCReport.html
.NOTES
   General notes
     Created by: Brent Denny
     Created on: 09 Sep 2020
#>
[CmdletBinding()]
Param (
  [Parameter(dontshow)]
  [PSCredential]$ScriptCreds =  (Get-Credential -Message 'ADC login credentials' -UserName nsroot),
  [string[]]$AdcObjectName = '',
  [string]$ADCAddress = '192.168.10.101',
  [ValidatePattern('.+\.html\s*$')]
  [string]$HTMLOutputFile = 'c:\ADCConfig.html'
)

$Css = @'
<style>
table {
  font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
  border-collapse: collapse;
  width: 100%;
}

td, th {
  border: 1px solid #ddd;
  padding: 8px;
}

tr:nth-child(even){background-color: #f2f2f2;}

tr:hover {background-color: #ddd;}

th {
  padding-top: 12px;
  padding-bottom: 12px;
  text-align: left;
  background-color: #4CAF50;
  color: white;
  text-transform: uppercase;
}
h3 {color: #4CAF50;padding-left:30px;text-transform: uppercase;}
</style>
'@


function Get-ADCobjects {
  [CmdletBinding()]
  Param ([PSCredential]$creds,[string]$NSAddress)
  $AdcObjects = Invoke-RestMethod -Method Get -Uri "http://$NSAddress/nitro/v1/config"   -Credential $creds
  $AdcObjects.configObjects.objects
}

function Get-ADCConfig {
  [CmdletBinding()]
  Param (
    [PSCredential]$creds,
    [Parameter(mandatory=$true)]
    [string]$NetScalerObject,
    [string]$NSAddress
  )
  
  try {
    $IndividualObjects = Invoke-RestMethod -Method Get -Uri "http://$NSAddress/nitro/v1/config/$NetScalerObject"   -Credential $creds -ErrorAction Stop
    $IndividualObjects | Select-Object -ExpandProperty $NetScalerObject -ErrorAction stop
  }
  catch{}
}

try {
  $TestAuth =  Invoke-RestMethod -Method Get -Uri "http://$ADCAddress/nitro/v1/config"   -Credential $ScriptCreds -ErrorAction Stop
}
Catch {
  Write-Warning 'Please enter correct credentials for the ADC '
  break
}
$frag = $null
$fragCount = 0
if ($AdcObjectName -ne '') {
  $AllAdcObjects = $AdcObjectName
}
else {
  $AllAdcObjects = Get-ADCobjects -creds $ScriptCreds -NSAddress $ADCAddress
}
$ObjectCount = $AllAdcObjects.Count
foreach ($AdcElement in $AllAdcObjects) {
  $fragCount++
  Write-Progress -PercentComplete ($fragCount/$ObjectCount*100) -Status "Processing $AdcElement" -Activity "Getting the NetScaler Config"
  $AdcObjectdata = Get-ADCConfig -creds $ScriptCreds -NetScalerObject $AdcElement -NSAddress $ADCAddress
  if ($AdcObjectdata.Count -gt 0) { $Frag = $Frag + ($AdcObjectdata | ConvertTo-Html -Fragment -PreContent "<br><hr><h3> $AdcElement </h3>") }
}
ConvertTo-Html -PostContent $Frag -Head $Css | Out-File $HTMLOutputFile
