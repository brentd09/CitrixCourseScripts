[CmdletBinding()]
Param (
  [Parameter(dontshow)]
  [PSCredential]$ScriptCreds =  (Get-Credential -Message 'ADC login credentials' -UserName nsroot)
)

$Css = @'
<style>
  table {border:solid 1px black;border-collapse:collapse}
  th {border:solid 1px black;border-collapse:collapse; background-color:Blue;color:white}
  tr,td {border:solid 1px black;border-collapse:collapse}
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
$fragCount = 0
$AllAdcObjects = Get-ADCobjects -creds $ScriptCreds
$ObjectCount = $AllAdcObjects.Count
foreach ($AdcElement in $AllAdcObjects) {
  $fragCount++
  Write-Progress -PercentComplete ($fragCount/$ObjectCount*100) -Status "Processing $AdcElement" -Activity "NetScaler Config"
  $Frag = $Frag + (Get-ADCConfig -creds $ScriptCreds -NetScalerObject $AdcElement | ConvertTo-Html -Fragment -PreContent "<h1> $AdcElement </h1>")
}
ConvertTo-Html -PostContent $Frag -Head $Css | Out-File c:\report.html