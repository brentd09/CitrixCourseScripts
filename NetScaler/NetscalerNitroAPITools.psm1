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
  Invoke-RestMethod @RestMethodSplat -Headers| Out-Null 
  return $NSSession
} 

Get-NSLoadBalancing {
  Param (
    [WebRequestSession]$WebSession
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/lbserver"
  $RestMethodSplat = @{
    Method          = 'get'
    Uri             = $URL
    ContentType     = 'application/json'
    SessionVariable = 'NSSession'
    Body            = $NSLoadBalanceJson
  }
  $LoadBalance = Invoke-RestMethod @RestMethodSplat
  return $LoadBalance
}