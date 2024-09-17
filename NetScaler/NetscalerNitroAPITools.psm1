function Connect-NSAppliance {
  Param (
    [pscredential]$NSCred = (Get-Credential -UserName nsroot -Message 'Enter the Netscaler credentials'),
    [string]$NSMgmtIpAddress = '192.168.10.103'
  )
  $URL = "http://${NSMgmtIpAddress}/nitro/v1/config/login"
  $AuthInfo = @{
    login = @{
      username = $NSCred.GetNetworkCredential().UserName
      password = $NSCred.GetNetworkCredential().Password
    }
  }

  $JsonAuthInfo = $AuthInfo | ConvertTo-Json -Depth 8
  $RestMethodSplat = @{
    Method          = 'post'
    Uri             = $URL
    ContentType     = 'application/json'
    SessionVariable = 'NSSession'
    Body            = $JsonAuthInfo
    Headers         = @{NSIPAddress = $NSMgmtIpAddress}
  }
  Invoke-RestMethod @RestMethodSplat | Out-Null 
  return $NSSession
} 

function Get-NSConfiguration {
  Param (
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
    [ValidateSet()]
    [string]$APISyntax = 'lbvserver'
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $APISyntax = $APISyntax.TrimStart('/')
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/$APISyntax"
  $RestMethodSplat = @{
    Method          = 'get'
    Uri             = $URL
    ContentType     = 'application/json'
    WebSession      = $WebSession
  }
  $Result = Invoke-RestMethod @RestMethodSplat
  return $Result
}

function Set-NSConfiguration {
  Param (
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
    [ValidateSet()]
    [string]$APISyntax = 'lbvserver',
    [hashtable]$PayloadSyntax
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $APISyntax = $APISyntax.TrimStart('/')
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/$APISyntax"
  $Payload = $PayloadSyntax
  $JsonPayload = $Payload | ConvertTo-Json -Depth 8
  $RestMethodSplat = @{
    Method          = 'put'
    Uri             = $URL
    ContentType     = 'application/json'
    WebSession      = $WebSession
    Body            = $JsonPayload
  }
  $Result = Invoke-RestMethod @RestMethodSplat
  return $Result
}