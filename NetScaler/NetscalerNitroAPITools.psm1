<#
.SYNOPSIS
  This module allows PowerShell to query and set configurations for a Citrix NetScaler
.DESCRIPTION
  There are only a few functions in this module as the modules to query different areas 
  of the NetScaler are the same except for the end of the URL that defines the API that
  is being queried. Firstly you must create a new Session to the NetScaler by using the 
  New-NSApplianceSession command, this will produce a Session Token object that then can 
  be used by every other command and will not require re-authentication. After creating 
  the TokenObject you can then run:
  Get-NSConfiguration -WebSession $Token -APISyntax lbvserver and this will list the Load
  Balancing Virtual Servers from the NetScaler
.NOTES
  Created by: Brent Denny
  Created on: 17-Sep-2024

  ChangeLog
  What                                                                        When
  ----                                                                        ----
  Reduced the number of functions to just three, reducing complexity          18-Sep-2024   
#>

function New-NSApplianceSession {
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
    [ValidateSet('lbvserver','lbvserver_binding?bulkbindings=yes','server','service','rewritepolicy',
                 'interface','nsip','responderpolicy','servicegroup','dnsnameserver'
    )]
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
