if (-not $Creds) {$Creds = Get-Credential} 
$LoginNS = @{
  login = @{
    username = $Creds.UserName
    password = $Creds.GetNetworkCredential().Password
  }
}

$CreateLBVS = @{
  lbvserver = @{
    name = 'lbvs-test2'
    servicetype = 'HTTP'
    ipv46 = '172.21.10.112'
    port = '80'
  }
}

$JSONLogin = $LoginNS | ConvertTo-Json -Depth 5
$JSONPayload = $CreateLBVS | ConvertTo-Json -Depth 5

$CommonParams = @{
  Method = 'Post'
  ContentType = 'application/json'
}
$LoginParam = @{
  Uri = 'http://192.168.10.103/nitro/v1/config/login'
  Body = $JSONLogin;SessionVariable = 'NSSession'
}
$CreateLBParam = @{
  Uri = 'http://192.168.10.103/nitro/v1/config/lbvserver'
  WebSession = $NSSession
  Body = $JSONPayload
}
Invoke-RestMethod @CommonParams @LoginParam
Invoke-RestMethod @CommonParams @CreateLBParam
