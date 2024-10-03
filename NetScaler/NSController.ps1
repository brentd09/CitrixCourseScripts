<#
.SYNOPSIS
  Uses functions from the NetscalerNitroApiTools module to build NetScaler objects via Nitro API
.DESCRIPTION
  This is a controller script that uses the module NetscalerNitroApiTools to create JSON 
  content that can be used with the NetScaler Nitro API to create and manage NetScalers
.NOTES
  Created by: Brent Denny
  Created on: 3-Oct-2024
.PARAMETER NitroApiFeatureName
  This is the feature from the Nitro API documentation that will be used to create the JSON 
  data to manipulate the Netscaler configuration
.EXAMPLE
  NSController.ps1 -NitroApiFeatureName lbvserver
  This will create a JSON data block that will manage Load Balancing Virtual Servers
#>
[CmdletBinding()]
Param (
  [string]$NitroApiFeatureName
)
Import-Module NetscalerNitroApiTools

$NSSession = New-NSApplianceSession
$NitroObject = Convert-NitroWebContentToPSObject
$NitroJson = Select-NitroElementToJson -NitroFeatureName $NitroApiFeatureName -NitroObject $NitroObject
Set-NSConfiguration -WebSession $NSSession -NitroFeatureName $NitroApiFeatureName -NitroJsonBody $NitroJson