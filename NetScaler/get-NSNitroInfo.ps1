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
  $CompactTable = $HtmlTableData -split "`n" -join ''
  $HeaderEnd = $CompactTable.IndexOf('</thead>') + 8
  $Headers = $CompactTable.Substring(0,$HeaderEnd)
  $Body = $CompactTable -replace "$Headers",''
  $SplitBody = ($Body -replace '</td></tr>',"</td></tr>`n" -replace '</?table>','' -replace '</?tbody>','') -split "`n"
  $CsvBody = foreach ($Line in $SplitBody) {
    $Line = $Line -replace '</?tr>','' -replace '<(.+?)></\1>','$1' -replace '\<td .+?\>','' -replace '&(lt|gt);','' -replace '<br>',' ' -replace '</?li>',''
    $RawConvert = $Line -replace '<td>(.+?)</td>','$1^' -replace '</td>',' '
    $RawConvert.trim('^') 
  }
  $CsvHeaders = ($Headers -replace '<.*?>',',' -replace ',+',',').trim(',') -split ','
  $TableToObject = $CsvBody | ConvertFrom-Csv -Delimiter '^' -Header $CsvHeaders
  return $TableToObject
}

$Obj = Convert-NitroApiWebTable
$Obj | fl