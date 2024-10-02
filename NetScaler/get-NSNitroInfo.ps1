function Get-NitroApiInfo {
  [CmdletBinding()]
  Param (
    [string]$URL
  )
  $WebContent = Invoke-WebRequest -Uri $URL
  return $WebContent
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