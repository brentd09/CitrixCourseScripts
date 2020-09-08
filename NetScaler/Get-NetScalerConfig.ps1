[CmdletBinding()]
Param (
  [Parameter(dontshow)]
  [PSCredential]$ScriptCreds =  (Get-Credential -Message 'ADC login credentials' -UserName nsroot)
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
}
h3 {color: #4CAF50;}
</style>
'@


function Get-ADCobjects {
  [CmdletBinding()]
  Param ([PSCredential]$creds)
  $AdcObjects = Invoke-RestMethod -Method Get -Uri "http://192.168.10.101/nitro/v1/config"   -Credential $creds
  $AdcObjects.configObjects.objects
}

function Get-ADCConfig {
  [CmdletBinding()]
  Param (
    [PSCredential]$creds,
    [Parameter(mandatory=$true)]
    [string]$NetScalerObject
  )
  
  try {
    $IndividualObjects = Invoke-RestMethod -Method Get -Uri "http://192.168.10.101/nitro/v1/config/$NetScalerObject"   -Credential $creds -ErrorAction Stop
    $IndividualObjects | Select-Object -ExpandProperty $NetScalerObject -ErrorAction stop
  }
  catch{}
}

$frag = $null
$fragCount = 0
$AllAdcObjects = Get-ADCobjects -creds $ScriptCreds
$ObjectCount = $AllAdcObjects.Count
foreach ($AdcElement in $AllAdcObjects) {
  $fragCount++
  Write-Progress -PercentComplete ($fragCount/$ObjectCount*100) -Status "Processing $AdcElement" -Activity "Getting the NetScaler Config"
  $AdcObjectdata = Get-ADCConfig -creds $ScriptCreds -NetScalerObject $AdcElement
  if ($AdcObjectdata.Count -gt 0) { $Frag = $Frag + ($AdcObjectdata | ConvertTo-Html -Fragment -PreContent "<br><hr><h3> $AdcElement </h3>") }
}
ConvertTo-Html -PostContent $Frag -Head $Css | Out-File c:\report.html