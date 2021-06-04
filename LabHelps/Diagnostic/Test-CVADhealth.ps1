[cmdletbinding()]
Param(
  [string[]]$ComputerName = @('localhost'),
  [string]$HTMLFilePath = 'c:\report.html' 
)

function Get-CVADServiceStatus {
  Param (
    [string[]]$AdminAddress = 'localhost'
  )
  foreach ($DeliveryController in $AdminAddress) {
    Invoke-Command -ComputerName $DeliveryController -ScriptBlock {
      $ServiceStatusCmds = Get-Command -Module citrix* -Verb get -Noun *servicestatus
      $ServiceStatusCmds | ForEach-Object { 
        $props = [ordered]@{
          Name = $_.Noun
          Status = (Invoke-Expression $_.name).ServiceStatus
        }
        New-Object -TypeName PSobject -Property $props 
      }
    } | Select-Object Name,Status,@{n='MachineName';e={$_.PSComputerName}} 
  }
}

function Get-CVADDBConnection {
  Param (
    [string[]]$AdminAddress = 'localhost'
  )
  foreach ($DeliveryController in $AdminAddress) {    
    Invoke-Command -ComputerName $DeliveryController -ScriptBlock {
      $DBCmds = Get-Command -Module citrix* -Verb get -Noun *dbconnection
      $DBCmds | ForEach-Object { 
        $props = [ordered]@{
          Name = $_.Noun
          DBConString = Invoke-Expression $_.name
        }
        New-Object -TypeName PSobject -Property $props 
      }
    } | Select-Object Name,DBConString,@{n='MachineName';e={$_.PSComputerName}}
  }
}

function Test-CVADDBConnection {
  Param (
    [string[]]$AdminAddress = 'localhost'
  )
  foreach ($DeliveryController in $AdminAddress) {    
    Invoke-Command -ComputerName $DeliveryController -ScriptBlock {
      $DBCmds = Get-Command -Module citrix* -Verb get -Noun *dbconnection
      $DBCmds | ForEach-Object { 
        $connString = Invoke-Expression $_.Name
        $props = [ordered]@{
          Name = $_.Noun
          DBConnectionStatus =  Invoke-Expression ('Test-' + $_.Noun + ' -DBConnection ' + "`'$connString`'")
        }
        New-Object -TypeName PSobject -Property $props 
      }
    } | Select-Object Name,DBConnectionStatus,@{n='MachineName';e={$_.PSComputerName}}
  }
}
$CSS = @'
<style>
table {
  font-family: Arial, Helvetica, sans-serif;
  border-collapse: collapse;
  width: 100%;
}
td, th {
  border: 1px solid #ddd;
  padding: 8px;
}
tr:nth-child(even){background-color: #f2f2f2;}
tr:hover {background-color: #ddd;}
th {
  padding-top: 12px;
  padding-bottom: 12px;
  text-align: left;
  background-color: #04AA6D;
  color: white;
}
</style>
'@
$FileCreation = $true
$HTMLSvcStatus = Get-CVADServiceStatus -AdminAddress $ComputerName | ConvertTo-Html -Fragment -PreContent '<h2>Service Status</h2>' | Out-String 
$HTMLDBConn = Get-CVADDBConnection -AdminAddress $ComputerName | ConvertTo-Html -Fragment -PreContent '<h2>DB Connection Strings</h2>' | Out-String 
$HTMLDBStatus = Test-CVADDBConnection -AdminAddress $ComputerName | ConvertTo-Html -Fragment -PreContent '<h2>Database Connection Status</h2>' | Out-String
try {ConvertTo-Html -Head $CSS -Body $HTMLSvcStatus,$HTMLDBConn,$HTMLDBStatus | Out-File $HTMLFilePath -ErrorAction Stop}
catch {Write-Warning "Could not create the HTML file $HTMLFilePath";$FileCreation = $false}
if ($FileCreation -eq $true) {Write-Verbose "The HTML file was written to $HTMLFilePath"}