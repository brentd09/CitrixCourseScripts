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

function Get-NSLoadBalancing {
  Param (
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/lbvserver"
  $RestMethodSplat = @{
    Method          = 'get'
    Uri             = $URL
    ContentType     = 'application/json'
    WebSession      = $WebSession
  }
  $Result = Invoke-RestMethod @RestMethodSplat
  return $Result
}

function Get-NSLoadBalancingServiceBinding {
  Param (
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/lbvserver_service_binding?bulkbindings=yes"
  $RestMethodSplat = @{
    Method          = 'get'
    Uri             = $URL
    ContentType     = 'application/json'
    WebSession      = $WebSession
  }
  $Result = Invoke-RestMethod @RestMethodSplat
  return $Result
}

function Get-NSMonitorBinding {
  Param (
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/lbmonitor_binding?bulkbindings=yes"
  $RestMethodSplat = @{
    Method          = 'get'
    Uri             = $URL
    ContentType     = 'application/json'
    WebSession      = $WebSession
  }
  $Result = Invoke-RestMethod @RestMethodSplat
  return $Result
}

function Get-NSInformation {
  Param (
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
    [string]$APISyntax = 'lbserver'
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