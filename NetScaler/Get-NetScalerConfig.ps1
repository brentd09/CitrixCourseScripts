[CmdletBinding()]
Param (
  [Parameter(dontshow)]
  [PSCredential]$ScriptCreds =  (Get-Credential -Message 'ADC login credentials' -UserName nsroot),
  [string[]]$AdcObjectName = '',
  [string]$ADCAddress = '192.168.10.101',
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
$AllAdcObjects = Get-ADCobjects -creds $ScriptCreds -NSAddress $ADCAddress
$ObjectCount = $AllAdcObjects.Count
if ($AdcObjectName -ne '') {$AllAdcObjects = $AdcObjectName}
foreach ($AdcElement in $AllAdcObjects) {
  $fragCount++
  Write-Progress -PercentComplete ($fragCount/$ObjectCount*100) -Status "Processing $AdcElement" -Activity "Getting the NetScaler Config"
  $AdcObjectdata = Get-ADCConfig -creds $ScriptCreds -NetScalerObject $AdcElement -NSAddress $ADCAddress
  if ($AdcObjectdata.Count -gt 0) { $Frag = $Frag + ($AdcObjectdata | ConvertTo-Html -Fragment -PreContent "<br><hr><h3> $AdcElement </h3>") }
}
ConvertTo-Html -PostContent $Frag -Head $Css | Out-File $HTMLOutputFile
