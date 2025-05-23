<#
NOTES
  Created by: Brent Denny
  Created on: 17-Sep-2024

  ChangeLog
  What                                                                        When
  ----                                                                        ----
  Reduced the number of functions to just two, reducing complexity            18-Sep-2024   
  Added Error checking and added help                                         19-Sep-2024
  Removed the ValidateSet as it was too restrictive                           20-Sep-2024 
#>

function New-NSApplianceSession {
  <#
  .SYNOPSIS
    This creates a login session to a Citrix NetScaler
  .DESCRIPTION
    When connecting to the Citrix NetScaler this command requires an IP of the NetScaler.
    It will then prompt for a username and password, typically nsroot and a password.
    This will attempt to access the netscaler and if successful it creates a token 
    object that can be used by subsequent cmdlets to access the NetScaler without 
    re-authentication, this cmdlet further modifies the default token by adding an IP
    header into the token that stores the NetScaler IP address so that subsequent cmdlets
    can use it to direct themselves to the NetScaler, this negates the need to supply the 
    IP address as parameter for every cmdlet executed.
  .NOTES
    Created By: Brent Denny
  .PARAMETER NSCred
    This holds the login credentials for the NetScaler Login
  .PARAMETER NSMgmtIpAddress
    This is the address of the management IP of the NetScaler
  .EXAMPLE
    $Session = New-NSApplianceSession -NSMgmtIpAddress 192.168.10.103
    This will prompt for the login credentials for the NetScaler and then connect, authenticate
    and finally create a token object that will be stored in the variable "Session"
  #>
  [CmdletBinding()]
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
    ErrorAction     = 'Stop'
  }
  try {Invoke-RestMethod @RestMethodSplat | Out-Null}
  catch {
    Write-Warning "The Netscaler with IPaddress $NSMgmtIpAddress cannot complete the authentication, check and try again"
    break
  } 
  return $NSSession
} 
function Get-NSConfiguration {
  <#
  .SYNOPSIS
    This PowerShell tool gets information from a Citrix NetScaler using Nitro API calls
  .DESCRIPTION
    When getting configuration information from the NetScaler via Nitro API calls, it is 
    apparent that there is very little difference in the API call's URI and so this cmdlet 
    can retrieve any information from the NetScaler by doing these simple steps:
    1.Authenticating to the NetScaler and setting up a session object, this object has been further 
      Enhanced to include the IP addrfess of the NetScaler so that subsequent commands do not 
      need to be supplied with this detail)
      Example: $NSSession = New-NSAppliance Session -NSMmgmtIPAddress 192.168.10.103
    2.This presents you with a credential dialog box to enter the nsroot and password for the 
      NS appliance.
    3.Once the session information is captured this cmdlet can retireive information by doing the 
      following:
      Example $LBVS = Get-NSConfiguration -WebSession $NSSession -NitroApiFeatureName lbvserver
              $LBVS.lbvserver | Format-Table
  .NOTES
    Created By: Brent Denny
    Created on: 19-Sep-2024
  .PARAMETER WebSession
    Before getting the configuration from the NetScaler, it is best to create a session to authenticate to the 
    NetScaler using $NSSession = New-NSApplianceSession -NSMgmtIpAddress 192.168.10.103. Once the session 
    variable is established you can then use the following command: 
    Get-NSConfiguration -WebSession $NSSession -APISyntax lbvserver
    The WebSession parameter accepts the token produced by the session in the New-NSApplianceSession cmdlet. 
  .PARAMETER NitroApiFeatureName
    When getting configuration information from the NetScaler by the API calls the API syntax is very similar 
    across all of the different API calls, they all have the following syntax for configuration: 
    Nitro API Docs: https://developer-docs.netscaler.com/en-us/adc-nitro-api/current-release/configuration
     
    URL: http://<netscaler-ip-address>/nitro/v1/config/lbvserver 
    URL: http://<netscaler-ip-address>/nitro/v1/config/lbvserver_binding
    
    The NitroApiFeatureName parameter just requires the information after the http://<netscaler-ip-address>/nitro/v1/config/
    So the NitroApiFeatureName parameter just requires the last part of the URL: lbvserver or lbvserver_binding etc.
     
  .EXAMPLE
    Get-NSConfiguration -WebSession $NSSession -NitroApiFeatureName lbvserver
    This will produce an object that shows the exit code from the API call and a property "lbvserver" that
    contains all of the Load Balancing Virtual Servers from the NetScaler
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
    [Parameter(Mandatory=$true)]
    [string]$NitroApiFeatureName 
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $NitroApiFeatureName = $NitroApiFeatureName.TrimStart('/')
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/$NitroApiFeatureName"
  $RestMethodSplat = @{
    Method          = 'get'
    Uri             = $URL
    ContentType     = 'application/json'
    WebSession      = $WebSession
    ErrorAction     = 'Stop'
  }
  try {$Result = Invoke-RestMethod @RestMethodSplat}
  catch {
    Write-Warning "The Netscaler with IPaddress $($WebSession.Headers.NSIPAddress) cannot complete the API request, check and try again"
    break
  } 
  return $Result
}
function Set-NSConfiguration {
  <#
  .SYNOPSIS
    This PowerShell tool modifies configuration in a Citrix NetScaler using Nitro API calls
  .DESCRIPTION
    When setting configuration information from the NetScaler via Nitro API calls, it is 
    apparent that there is very little difference in the API call's URI and so this cmdlet 
    can retrieve any information from the NetScaler by doing these simple steps:
    1.Authenticating to the NetScaler and setting up a session object, this object has been further 
      Enhanced to include the IP addrfess of the NetScaler so that subsequent commands do not 
      need to be supplied with this detail)
      Example: $NSSession = New-NSAppliance Session -NSMmgmtIPAddress 192.168.10.103
    2.This presents you with a credential dialog box to enter the nsroot and password for the 
      NS appliance.
    3.Once the session information is captured this cmdlet can modify configuration by doing the 
      following:
      Example $Result = Set-NSConfiguration -WebSession $NSSession -APISyntax $HashTable-of-Changes
      
  .NOTES
    Created By: Brent Denny
  .PARAMETER WebSession
    Before getting the configuration from the NetScaler, it is best to create a session to authenticate to the 
    NetScaler using $NSSession = New-NSApplianceSession -NSMgmtIpAddress 192.168.10.103. Once the session 
    variable is established you can then use the following command: 
    Set-NSConfiguration -WebSession $NSSession -APISyntax lbvserver
    The WebSession parameter accepts the token produced by the session in the New-NSApplianceSession cmdlet. 
  .PARAMETER APISyntax
    When setting configuration information from the NetScaler by the API calls the API syntax is very similar 
    across all of the different API calls, they all have the following syntax for configuration: 
    Nitro API Docs: https://developer-docs.netscaler.com/en-us/adc-nitro-api/current-release/configuration
     
    URL: http://<netscaler-ip-address>/nitro/v1/config/lbvserver 
    URL: http://<netscaler-ip-address>/nitro/v1/config/lbvserver_binding
    
    The APISyntax parameter just requires the information after the http://<netscaler-ip-address>/nitro/v1/config/
    So the APISyntax parameter just requires the last part of the URL: lbvserver or lbvserver_binding etc.
     
  .EXAMPLE
    Set-NSConfiguration -WebSession $NSSession -NitroFeatureName lbvserver -NitroJsonBody $NitroBody 
    This will create a load balancing virtual server based on the configuration that is in the 
    $NitroBody JSON format. 
  #>
  [CmdletBinding()]
  Param (
    [Parameter(Mandatory=$true)]
    [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
    [Parameter(Mandatory=$true)]
    [string]$NitroApiFeatureName,
    [Parameter(Mandatory=$true)]
    [string]$NitroJsonBody
  )
  if (-not $WebSession) {$WebSession = Connect-NSAppliance}
  $NitroApiFeatureName = $NitroApiFeatureName.TrimStart('/')
  $URL = "http://$($WebSession.Headers.NSIPAddress)/nitro/v1/config/$NitroApiFeatureName"
  $RestMethodSplat = @{
    Method          = 'post'
    Uri             = $URL
    ContentType     = 'application/json'
    WebSession      = $WebSession
    ErrorAction     = 'Stop'
    Body            = $NitroJsonBody
  }
  try {$Result = Invoke-RestMethod @RestMethodSplat}
  catch {
    Write-Warning "The Netscaler with IPaddress $($WebSession.Headers.NSIPAddress) cannot complete the API request, check and try again"
    break
  } 
  return $Result
}
function Convert-NitroWebContentToPSObject {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [string]$NitroApiFeatureName
  )
  $URL = "https://developer-docs.netscaler.com/en-us/adc-nitro-api/current-release/configuration/lb/${NitroApiFeatureName}#operations"
  $WebResult = Invoke-WebRequest -Uri $URL
  $WebContent      = $WebResult.Content
  $SplitContent    = $WebContent -split "`n"
  $MinifiedContent = $SplitContent -join '' -replace '\s{2,}',''
  $TableStartIndex = $MinifiedContent.IndexOf('<table')
  $TableEndIndex   = $MinifiedContent.IndexOf('</table>') + 8
  $EntireHtmlTable = $MinifiedContent.Substring($TableStartIndex,($TableEndIndex-$TableStartIndex))
  $HtmlTableHeader = ($EntireHtmlTable -replace '.+(\<thead.+\<\/thead>).+','$1') -replace '\</?thead>',''
  $HtmlTableBody   = ($EntireHtmlTable -replace '.+(\<tbody.+\<\/tbody>).+','$1') -replace '\</?tbody>',''
  $CsvTableHeader  = ($HtmlTableHeader -replace '<.+?><.+?>', ',' -replace '\s+','').trim(',') -split ',' 
  $SplitTableBody  = ($HtmlTableBody -replace '\<\/td\>\<\/tr\>',"`n") -replace '\<\/td\>\<td.*?\>','^' -split '^' -replace '\<tr\>\<td\>','' -replace '<(.+?)></\1>','$1' -replace '&(lt|gt);',''
  $TableObject     = $SplitTableBody | ConvertFrom-Csv -Delimiter '^' -Header $CsvTableHeader
  return $TableObject
}
function Select-NitroElementToJson {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [string]$NitroFeatureName,
    [Parameter(Mandatory=$true)]
    [PSCustomObject]$TableObject
  )
  $SelectedApiElements = $TableObject | Out-GridView -Title 'Select the elements you need for the API configuration' -OutputMode Multiple
  $ApiHashElements = [ordered]@{}
  Write-Host -ForegroundColor Green "Enter values for each of the API elements"
  foreach ($Element in $SelectedApiElements) {
    Write-Host 
    Write-Host -ForegroundColor Yellow $Element.Description
    Write-Host -NoNewline -ForegroundColor DarkYellow "Type the value for the element - `"$($Element.Name)`": "
    $Value = Read-Host
    switch ($Element.DataType) {
      string    {[string]$TypeCastValue = $Value}
      string[]  {[string[]]$TypeCastValue = $Value}
      integer   {[int]$TypeCastValue = $Value}
      integer[] {[int]$TypeCastValue = $Value}
      double    {[double]$TypeCastValue = $Value}
      double[]  {[double[]]$TypeCastValue = $Value}
      Default   {[string]$TypeCastValue = $Value}
    }
    $ApiHashElements.Add($Element.Name,$TypeCastValue)
  }
  $NitroApiObject = [PSCustomObject]@{
    $NitroFeatureName = $ApiHashElements
  }
  $JsonObject = $NitroApiObject | ConvertTo-Json -Depth 8 
  return $JsonObject
}
