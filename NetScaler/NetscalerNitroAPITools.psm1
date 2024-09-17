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

  $JsonAuthInfo = $AuthInfo | ConvertTo-Json
  $RestMethodSplat = @{
    Method          = 'post'
    Uri             = $URL
    ContentType     = 'Application/json'
    SessionVariable = 'NSSession'
    Body            = $JsonAuthInfo
  }
  Invoke-RestMethod @RestMethodSplat | Out-Null 
  return $NSSession
} 

Get-NSLoadBalancing {
  Param (
    [websession]$WebSession
  )
}