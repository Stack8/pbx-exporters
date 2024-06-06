function Execute-GetOnUnity {
    param (
        [string]$UnityHost,
        [string]$Endpoint,
        [PSCredential]$Credential,
        [string]$OutputFileName
    )

    $Url = $UnityHost + $Endpoint
    $Headers = @{
        "Accept" = "application/json"
    }
 
    $response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential | ConvertTo-Json
    $response | Out-File -FilePath $OutputFileName
}

$Credential = Get-Credential -Message "Insert Unity Username and Password"    
$UnityHost = Read-Host "Please enter the Unity server URL (ex: https://myunity.com/)"

New-Item -Name "users" -ItemType "directory" -Force
New-Item -Name "callhandlers" -ItemType "directory" -Force
New-Item -Name "distributionlists" -ItemType "directory" -Force
New-Item -Name "directoryhandlers" -ItemType "directory" -Force
New-Item -Name "interviewhandlers" -ItemType "directory" -Force
New-Item -Name "routingrules" -ItemType "directory" -Force
New-Item -Name "partitions" -ItemType "directory" -Force
New-Item -Name "schedules" -ItemType "directory" -Force
New-Item -Name "schedulesets" -ItemType "directory" -Force

Execute-GetOnUnity $UnityHost 'vmrest/users/' $Credential 'users/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/handlers/callhandlers' $Credential 'callhandlers/list.json'