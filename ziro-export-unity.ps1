$Credential = Get-Credential -Message "Insert Unity Username and Passsword"    
$UnityHost = Read-Host "Please enter the Unity server URL"

$headers = @{
    "Accept" = "application/json"
}

$response = Invoke-WebRequest -Uri $UnityHost -Headers $headers -SkipCertificateCheck -Credential $Credential
