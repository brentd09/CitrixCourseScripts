[CmdletBinding()]
Param (
  [PSCredential]$creds =  (Get-Credential -Message NSlogin -UserName nsroot),
  [Parameter(mandatory=$true)]
  [ValidateSet('interface','lbvserver','service','server')]
  [string]$NetScalerObject
)

$res = Invoke-RestMethod -Method Get -Uri "http://192.168.10.101/nitro/v1/config/$NetScalerObject"   -Credential $creds
$res | Select-Object -ExpandProperty $NetScalerObject