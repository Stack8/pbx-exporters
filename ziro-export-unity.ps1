function Execute-GetOnUnity {
    param (
        [string]$UnityHost,
        [string]$Endpoint,
        [PSCredential]$Credential,
        [string]$OutputFileName
    )

    $PageNumber = 1

    $Url = $UnityHost + $Endpoint + "?rowsPerPage=2000&pageNumber=" + $PageNumber
    $OutputFilePath = "output-unity/" + $OutputFileName

    $Headers = @{
        "Accept" = "application/json"
    }

 
    $response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential | ConvertTo-Json
    $response | Out-File -FilePath $OutputFilePath
}

$Credential = Get-Credential -Message "Insert Unity Username and Password"    
$UnityHost = Read-Host "Please enter the Unity server URL (ex: https://myunity.com/)"

New-Item -Name "output-unity" -ItemType Directory -Force
New-Item -Name "output-unity/users" -ItemType Directory -Force
New-Item -Name "output-unity/callhandlers" -ItemType Directory -Force
New-Item -Name "output-unity/distributionlists" -ItemType Directory -Force
New-Item -Name "output-unity/directoryhandlers" -ItemType Directory -Force
New-Item -Name "output-unity/interviewhandlers" -ItemType Directory -Force
New-Item -Name "output-unity/routingrules" -ItemType Directory -Force
New-Item -Name "output-unity/partitions" -ItemType Directory -Force
New-Item -Name "output-unity/schedules" -ItemType Directory -Force
New-Item -Name "output-unity/schedulesets" -ItemType Directory -Force

Execute-GetOnUnity $UnityHost 'vmrest/users/' $Credential 'users/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/handlers/callhandlers' $Credential 'callhandlers/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/distributionlists' $Credential 'distributionlists/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/handlers/directoryhandlers' $Credential 'directoryhandlers/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/handlers/interviewhandlers' $Credential 'interviewhandlers/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/routingrules' $Credential 'routingrules/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/partitions' $Credential 'partitions/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/schedules' $Credential 'schedules/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/schedulesets' $Credential 'schedulesets/list.json'

Compress-Archive -Path output-unity/* -DestinationPath output-unity.zip -Force
Remove-Item -Path output-unity -Recurse