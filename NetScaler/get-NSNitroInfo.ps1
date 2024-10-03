function Get-HtmlContent {
  [CmdletBinding()]
  Param (
    [string]$URL = 'https://developer-docs.netscaler.com/en-us/adc-nitro-api/current-release/configuration/lb/lbvserver#operations'
  )
  $WebResult = Invoke-WebRequest -Uri $URL
  return $WebResult.Content
}

function Convert-HtmlTableToPSObject {
  param (
    $WebContent
  )
  $SplitContent = $WebContent -split "`n"
  $MinifiedContent = $SplitContent -join '' -replace '\s{2,}',''
  $TableStartIndex = $MinifiedContent.IndexOf('<table')
  $TableEndIndex   = $MinifiedContent.IndexOf('</table>') + 8
  $EntireHtmlTable = $MinifiedContent.Substring($TableStartIndex,($TableEndIndex-$TableStartIndex))
  $HtmlTableHeader = ($EntireHtmlTable -replace '.+(\<thead.+\<\/thead>).+','$1') -replace '\</?thead>',''
  $HtmlTableBody   = ($EntireHtmlTable -replace '.+(\<tbody.+\<\/tbody>).+','$1') -replace '\</?tbody>',''
  $CsvTableHeader = ($HtmlTableHeader -replace '<.+?><.+?>', ',' -replace '\s+','').trim(',') -split ',' 
  $SplitTableBody = ($HtmlTableBody -replace '\<\/td\>\<\/tr\>',"`n") -replace '\<\/td\>\<td.*?\>','^' -split '^' -replace '\<tr\>\<td\>','' -replace '<(.+?)></\1>','$1' -replace '&(lt|gt);',''
  $TableObject = $SplitTableBody | ConvertFrom-Csv -Delimiter '^' -Header $CsvTableHeader
  return $TableObject
}

function Select_NitroApiElement {
  param (
    $TableObject
  )
  $SelectedApiElements = $TableObject | Out-GridView -Title 'Select the elements you need for the API configuration' -OutputMode Multiple
  return $SelectedApiElements 
}

function New-NitroApiObject {
  param (
    $SelectedApiElements
  )
  $ApiHashElements = @{}
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
  return $ApiHashElements
}

New-NitroJson {
  param (
    $NitroFeatureName,
    $ApiHashElements
  )
  $ApiHash = $ApiObject | convertto-
  $NitroApiObject = [PSCustomObject]@{
    $NitroFeatureName = $ApiHashElements
  }
  $JsonObject = $NitroApiObject | ConvertTo-Json -Depth 8 
  return $JsonObject
}

function Convert-NitroApiWebTable {
  Param (
    [string]$URL = 'https://developer-docs.netscaler.com/en-us/adc-nitro-api/current-release/configuration/lb/lbvserver#operations'
  )
  $ExtractedWebInfo = Get-NitroApiInfo -URL $URL

  $StartOfTable = $ExtractedWebInfo.Content.IndexOf('<table')
  $IndexOfTableEnd   = $ExtractedWebInfo.Content.IndexOf('</table>')
  $EndOfTable = $IndexOfTableEnd + 8
  $LengthOfTable = $EndOfTable - $StartOfTable
  $HtmlTableData = $ExtractedWebInfo.Content.Substring($StartOfTable,$LengthOfTable)
  $SplitData = $HtmlTableData -split "`n"
  $CompactTable = $SplitData -join ''
  $NetscalerFeature = ($ExtractedWebInfo.Content -split "`n" | Where-Object {$_ -match '\<title\>'}) -replace '.*\<title\>([a-z0-9_]+).*','$1' 
  $HeaderEnd = $CompactTable.IndexOf('</thead>') + 8
  $Headers = $CompactTable.Substring(0,$HeaderEnd)
  $Body = $CompactTable -replace "$Headers",''
  $SplitBody = ($Body -replace '</td></tr>',"</td></tr>`n" -replace '</?table>','' -replace '</?tbody>','') -split "`n"
  $CsvBody = foreach ($Line in $SplitBody) {
    $Line = $Line -replace '</?tr>','' -replace '<(.+?)></\1>','$1' -replace '\<td .+?\>','' -replace '&(lt|gt);','' -replace '<br>',' ' -replace '</?li>',''
    $RawConvert = $Line -replace '<td>(.+?)</td>','$1^' -replace '</td>',' '
    $RawConvert.trim('^') 
  }
  $CsvHeaders = ($Headers -replace '<.*?>',',' -replace ',+',',').trim(',') -split ',' -replace '\s+',''
  $TableToObject = $CsvBody | ConvertFrom-Csv -Delimiter '^' -Header $CsvHeaders
  $NitroApiConfig = $TableToObject | Out-GridView -Title 'Select which elements will be included in the configuration' -OutputMode Multiple 
  $NitroApiObject = [PSCustomObject]@{
    $NetscalerFeature = $NitroApiConfig
  }
  return $NitroApiObject
}


function ConvertTo-NetscalerNitroJson {
  param (
    $NitroApiObject
  )
  $PropertyName = ($NitroApiObject | Get-Member -MemberType Properties).Name
  $ApiConfig = [ordered]@{}
  foreach ($Object in $NitroApiObject.$PropertyName) {
    Write-Host -ForegroundColor Cyan "`n`nDesciption:`n$($Object.Description)"
    Write-Host -ForegroundColor Yellow -NoNewline "`nType a Value for `"$($Object.Name)`": "
    $Value = Read-Host 
    switch ($Object.DataType) {
      integer { [int]$TypeCastValue = $Value  }
      string  { [string]$TypeCastValue = $Value  }
      Default {}
    }
    $ApiConfig.Add($Object.Name,$TypeCastValue)
  }
  $APIComplete = @{
    $PropertyName = $ApiConfig
  }
  $ApiJson = $APIComplete | ConvertTo-Json -Depth 9
  return $ApiJson
}

$Obj = Convert-NitroApiWebTable
$Json = ConvertTo-NetscalerNitroJson -NitroApiObject $Obj
$Json