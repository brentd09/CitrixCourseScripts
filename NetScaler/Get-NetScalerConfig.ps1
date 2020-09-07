[CmdletBinding()]
Param (
  [PSCredential]$creds =  (Get-Credential -Message NSlogin -UserName nsroot),
  [Parameter(mandatory=$true)]
  [ValidateSet('interface','lbvserver','service','server')]
  [string]$NetScalerElement
)

$res = Invoke-RestMethod -Method Get -Uri "http://192.168.10.101/nitro/v1/config/$NetScalerElement"   -Credential $creds
$res.lbvserver | select *