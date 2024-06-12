function Execute-GetOnUnity {
    param (
        [string]$UnityHost,
        [string]$Endpoint,
        [PSCredential]$Credential,
        [string]$OutputFileName,
        [string]$ResourceName
    )

    $PageNumber = 1

    $Url = $UnityHost + $Endpoint + "?rowsPerPage=2000&pageNumber=" + $PageNumber
    $OutputFilePath = "output-unity/" + $OutputFileName

    $Headers = @{
        "Accept" = "application/json"
    }

    $ResourcesArray = @()
    $Response = $null
    try {
        $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential
    }
    catch {
        $ResponseCode = $_.Exception.Response.StatusCode.value__
        if ($ResponseCode -eq 401 -or $ResponseCode -eq 403) {
            Write-Host "Wrong credentials or insufficient permissions." -ForegroundColor Red
            exit 1
        }
    }

    $Resources = $Response.$ResourceName
    $TotalResources = [int]$Response."@total"
    $ResourcesArray += $Resources
    
    while ($ResourcesArray.Count -lt $TotalResources) {
        $PageNumber++
        $Url = $UnityHost + $Endpoint + "?rowsPerPage=1&pageNumber=" + $PageNumber
        $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential
        $Resources = $Response.$ResourceName
        $ResourcesArray += $Resources
    }

    $JsonOutput = ConvertTo-Json $ResourcesArray
    $JsonOutput | Out-File -FilePath $OutputFilePath
    return $JsonOutput | ConvertFrom-Json
}

$Error.Clear()

$Credential = Get-Credential -Message "Insert Unity Username and Password"    
$UnityHost = Read-Host "Please enter the Unity server URL (ex: https://myunity.com/)"

New-Item -Name "output-unity" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/users" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/callhandlers" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/distributionlists" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/directoryhandlers" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/interviewhandlers" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/routingrules" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/partitions" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/schedules" -ItemType Directory -Force | Out-Null
New-Item -Name "output-unity/schedulesets" -ItemType Directory -Force | Out-Null

Execute-GetOnUnity $UnityHost 'vmrest/users/' $Credential 'users/list.json' 'User' | Out-Null
Write-Output "Finished getting users"

$CallHandlers = Execute-GetOnUnity $UnityHost 'vmrest/handlers/callhandlers' $Credential 'callhandlers/list.json' 'CallHandler' | Out-Null
Write-Output "Finished getting call handlers"

foreach ($CallHandler in $CallHandlers) {
    $FolderName = "callhandlers/" + $CallHandler.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/greetings") $Credential ($FolderName + '/greetings.json') 'Greeting' | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/transferoptions") $Credential ($FolderName + '/transferoptions.json') 'TransferOption' | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/menuentries") $Credential ($FolderName + '/menuentries.json') 'Menuentry' | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/callhandlerowners") $Credential ($FolderName + '/callhandlerowners.json') 'CallHandlerOwner' | Out-Null
}

$DistributionLists = Execute-GetOnUnity $UnityHost 'vmrest/distributionlists' $Credential 'distributionlists/list.json' 'DistributionList' | Out-Null
Write-Output "Finished getting distribution lists"

foreach ($DistributionList in $DistributionLists) {
    $FolderName = "distributionlists/" + $DistributionList.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/distributionlists/' + $DistributionList.ObjectId + "/distributionlistmembers") $Credential ($FolderName + '/distributionlistmembers.json') 'DistributionListMember' | Out-Null
}

Execute-GetOnUnity $UnityHost 'vmrest/handlers/directoryhandlers' $Credential 'directoryhandlers/list.json' 'DirectoryHandler' | Out-Null
Write-Output "Finished getting directory handlers"

$InterviewHandlers = Execute-GetOnUnity $UnityHost 'vmrest/handlers/interviewhandlers' $Credential 'interviewhandlers/list.json' 'InterviewHandler' | Out-Null
Write-Output "Finished getting interview handlers"

foreach ($InterviewHandler in $InterviewHandlers) {
    $FolderName = "interviewhandlers/" + $InterviewHandler.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/interviewhandlers/' + $InterviewHandler.ObjectId + "/interviewquestions") $Credential ($FolderName + '/interviewquestions.json') 'InterviewQuestion' | Out-Null
}

$RoutingRules = Execute-GetOnUnity $UnityHost 'vmrest/routingrules' $Credential 'routingrules/list.json' 'RoutingRule' | Out-Null
Write-Output "Finished getting routing rules"

foreach ($RoutingRule in $RoutingRules) {
    $FolderName = "routingrules/" + $RoutingRule.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/routingrules/' + $RoutingRule.ObjectId + "/routingruleconditions") $Credential ($FolderName + '/routingruleconditions.json') 'RoutingruleCondition' | Out-Null
}

Execute-GetOnUnity $UnityHost 'vmrest/partitions' $Credential 'partitions/list.json' 'Partition' | Out-Null
Write-Output "Finished getting partitions"

$Schedules = Execute-GetOnUnity $UnityHost 'vmrest/schedules' $Credential 'schedules/list.json' 'Schedule' | Out-Null
Write-Output "Finished getting schedules"

foreach ($Schedule in $Schedules) {
    $FolderName = "schedules/" + $Schedule.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/schedules/' + $Schedule.ObjectId + "/scheduledetails") $Credential ($FolderName + '/scheduledetails.json') 'ScheduleDetail' | Out-Null
}

$ScheduleSets = Execute-GetOnUnity $UnityHost 'vmrest/schedulesets' $Credential 'schedulesets/list.json' 'ScheduleSet' | Out-Null
Write-Output "Finished getting schedule sets"

foreach ($ScheduleSet in $ScheduleSets) {
    $FolderName = "schedulesets/" + $ScheduleSet.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Execute-GetOnUnity $UnityHost ('vmrest/schedulesets/' + $ScheduleSet.ObjectId + "/schedulesetmembers") $Credential ($FolderName + '/schedulesetmembers.json') 'SchedulesetMember' | Out-Null
}

$ZipFileName = (Get-Date -Format "dd-MM-yyyy_HH-mm-ss").ToString() + "_" + ([System.Uri]$UnityHost).Host + ".zip"

Compress-Archive -Path output-unity/* -DestinationPath $ZipFileName -Force | Out-Null
Remove-Item -Path output-unity -Recurse | Out-Null

if ($Error.Count -gt 0) {
    Write-Host "Something went wrong while running the script." -ForegroundColor Red
}
else {
    Write-Host "The script ran successfully" -ForegroundColor Green
}

$Error.Clear()