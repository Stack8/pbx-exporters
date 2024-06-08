function Execute-GetOnUnity {
    param (
        [string]$UnityHost,
        [string]$Endpoint,
        [PSCredential]$Credential,
        [string]$OutputFileName
    )

    $Url = $UnityHost + $Endpoint
    $OutputFilePath = "output/" + $OutputFileName

    $Headers = @{
        "Accept" = "application/json"
    }

 
    $response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential | ConvertTo-Json
    $response | Out-File -FilePath $OutputFilePath
}

$Credential = Get-Credential -Message "Insert Unity Username and Password"    
$UnityHost = Read-Host "Please enter the Unity server URL (ex: https://myunity.com/)"

New-Item -Name "output" -ItemType Directory -Force
New-Item -Name "output/users" -ItemType Directory -Force
New-Item -Name "output/callhandlers" -ItemType Directory -Force
New-Item -Name "output/distributionlists" -ItemType Directory -Force
New-Item -Name "output/directoryhandlers" -ItemType Directory -Force
New-Item -Name "output/interviewhandlers" -ItemType Directory -Force
New-Item -Name "output/routingrules" -ItemType Directory -Force
New-Item -Name "output/partitions" -ItemType Directory -Force
New-Item -Name "output/schedules" -ItemType Directory -Force
New-Item -Name "output/schedulesets" -ItemType Directory -Force

Execute-GetOnUnity $UnityHost 'vmrest/users/' $Credential 'users/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/handlers/callhandlers' $Credential 'callhandlers/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/distributionlists' $Credential 'distributionlists/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/handlers/directoryhandlers' $Credential 'directoryhandlers/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/handlers/interviewhandlers' $Credential 'interviewhandlers/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/routingrules' $Credential 'routingrules/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/partitions' $Credential 'partitions/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/schedules' $Credential 'schedules/list.json'
Execute-GetOnUnity $UnityHost 'vmrest/schedulesets' $Credential 'schedulesets/list.json'

Compress-Archive -Path output/* -DestinationPath output.zip -Force
Remove-Item -Path output -Recurse