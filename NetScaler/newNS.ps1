Class NSSession {
  [pscredential]$NSCred
  [string]$NSMgmtIP
  [hashtable]$AuthInfo
  [string]$JsonAuthInfo


  NSSession ([PSCredential]$Credential = (Get-Credential), [string]$ManagementIP) {
    $this.NSCred = $Credential
    $this.NSMgmtIP = $ManagementIP
    $HashAuthInfo = @{
      login = @{
        username = $this.NSCred.GetNetworkCredential().UserName
        password = $this.NSCred.GetNetworkCredential().Password
      }
    } 
    $this.AuthInfo = $HashAuthInfo
    $this.JsonAuthInfo = $HashAuthInfo | ConvertTo-Json -Depth 8
  }

  [hashtable]GetAuthObject () {
    $ReturnObject = @{
      Method          = 'post'
      Uri             = "http://" + $this.NSMgmtIP + "/nitro/v1/config/login"
      ContentType     = 'application/json'
      SessionVariable = 'NSSession'
      Body            = $this.JsonAuthInfo
      Headers         = @{NSIPAddress = $this.NSMgmtIP}
      ErrorAction     = 'Stop'
    }
    return $ReturnObject
  }
}

Class NitroDetails {
  [string]$NitroFeatureName

  NitroDetails ($Feature) {
    $this.NitroFeatureName = $Feature
  }

  [PSObject]GetNitroProperties () {
    $URL = "https://developer-docs.netscaler.com/en-us/adc-nitro-api/current-release/configuration/lb/" + $this.NitroFeatureName + "#operations"
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
}

class NSConfig {
  [string]$NSMgmtIP
  [hashtable]$NSAuthentication
  [string]$NSConfigElement
  [string]$NSOperation
  [psobject]$NitroProperties
  [psobject]$Properties
  [string]$OperationJson
  [string]$FeatureName

  NSConfig ([string]$ManagementIP, [hashtable]$Authentication, [string]$ConfigElement, [string]$Operation, [psobject]$NitroProperties) {
    $this.NSAuthentication = $Authentication
    $this.NSMgmtIP = $ManagementIP
    $this.NSConfigElement = $ConfigElement
    $this.NitroProperties = $NitroProperties
    $this.NSOperation = $Operation
  }

  [void]ChooseProperties () {
    $this.Properties = $this.NitroProperties | Out-GridView -Title 'Select which properties to use' -OutputMode Multiple
  }

  [void]CreateOperationJson ($FeatureName) {
    if (-not $this.Properties) {$this.ChooseProperties()}
    $this.FeatureName = $FeatureName
    $ApiHashElements = [ordered]@{}
    Write-Host -ForegroundColor Green "Enter values for each of the API elements"
    foreach ($Property in $this.Properties) {
      Write-Host 
      Write-Host -ForegroundColor Yellow $Property.Description
      Write-Host -NoNewline -ForegroundColor DarkYellow "Type the value for the element - `"$($Property.Name)`": "
      $Value = Read-Host
      switch ($Property.DataType) {
        string    {[string]$TypeCastValue = $Value}
        string[]  {[string[]]$TypeCastValue = $Value}
        integer   {[int]$TypeCastValue = $Value}
        integer[] {[int]$TypeCastValue = $Value}
        double    {[double]$TypeCastValue = $Value}
        double[]  {[double[]]$TypeCastValue = $Value}
        Default   {[string]$TypeCastValue = $Value}
      }
      $ApiHashElements.Add($Property.Name,$TypeCastValue)
    }
    $NitroApiObject = [PSCustomObject]@{
      $FeatureName = $ApiHashElements
    }
    $JsonObject = $NitroApiObject | ConvertTo-Json -Depth 8 
    $this.OperationJson = $JsonObject
  }

  [psobject]ExecuteOperation () {
    $URL = "http://" + $this.NSMgmtIP + "/nitro/v1/config/" + $this.FeatureName 
    $RestMethodSplat = @{
      Method          = 'post'
      Uri             = $URL
      ContentType     = 'application/json'
      WebSession      = $this.NSAuthentication
      ErrorAction     = 'Stop'
      Body            = $this.OperationJson
    }
    $Result = Invoke-RestMethod @RestMethodSplat
    return $Result
  }
}




