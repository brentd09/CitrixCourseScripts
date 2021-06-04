# script to use existing ssl certificate to encrypt Citrix XML Broker Port
# works with XD Controller and Cloud Connector
# use at own risk, credits to Daniel.Wipperfuerth@arrow.com
# more of this at seetricks.blogspot.com
# V2 2018-02-20

Write-Output "Gathering registry info..."
$myReg = get-childitem -Path Registry::HKEY_CLASSES_ROOT\Installer\Products | Get-ItemProperty | Where-Object {$_.productname -like "Citrix Broker Service"}
[guid]$myAppID = $myReg.PSChildName
Write-Output "Looking for a certificate..."
$myCert = gci Cert:\LocalMachine\my
$myCertChoice = 0
if ($myCert.Length -eq 1) {Write-Output "Found one single certificate. OK."}
elseif ($myCert.Length -gt 1) {
    Write-Output "Found more than one certificate..."
    for($i=0;$i-le $myCert.length-1;$i++) {"Certificate [{0}] = {1} '=>' {2}" -f $i,$myCert[$i].FriendlyName,$myCert[$i].Subject}
    $myCertChoice = Read-Host "Which Certificate should be bound to the Citrix Broker Service?"
    }
elseif ($myCert.Length -lt 1) {write-output "No Certificate found, operation aborted!";break}
Write-Output "Executing NetShell to bind certificate to Citrix XML Broker"
& netsh.exe http add sslcert ipport=0.0.0.0:443 certhash=$($myCert[$myCertChoice].thumbprint) appid="{$myAppID}"
Write-Output "Setting registry to ignore unencrypted traffic for Citrix XML Broker"
$silent = New-ItemProperty -Path HKLM:\SOFTWARE\Citrix\DesktopServer -Name XmlServicesEnableNonSsl -Value 0 -Propertytype dword -Force
Write-Output "All done. Maybe."
