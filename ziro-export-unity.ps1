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

 
    $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential
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

Execute-GetOnUnity $UnityHost 'vmrest/users/' $Credential 'users/list.json' 'User'
$CallHandlers = Execute-GetOnUnity $UnityHost 'vmrest/handlers/callhandlers' $Credential 'callhandlers/list.json' 'CallHandler'

foreach ($CallHandler in $CallHandlers) {
    $FolderName = "callhandlers/" + $CallHandler.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/greetings") $Credential ($FolderName + '/greetings.json') 'Greeting'
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/transferoptions") $Credential ($FolderName + '/transferoptions.json') 'TransferOption'
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/menuentries") $Credential ($FolderName + '/menuentries.json') 'Menuentry'
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/callhandlerowners") $Credential ($FolderName + '/callhandlerowners.json') 'CallHandlerOwner'
}

$DistributionLists = Execute-GetOnUnity $UnityHost 'vmrest/distributionlists' $Credential 'distributionlists/list.json' 'DistributionList'


foreach ($DistributionList in $DistributionLists) {
    $FolderName = "distributionlists/" + $DistributionList.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force
    Execute-GetOnUnity $UnityHost ('vmrest/distributionlists/' + $DistributionList.ObjectId + "/distributionlistmembers") $Credential ($FolderName + '/distributionlistmembers.json') 'DistributionListMember'
}

Execute-GetOnUnity $UnityHost 'vmrest/handlers/directoryhandlers' $Credential 'directoryhandlers/list.json' 'DirectoryHandler'

$InterviewHandlers = Execute-GetOnUnity $UnityHost 'vmrest/handlers/interviewhandlers' $Credential 'interviewhandlers/list.json' 'InterviewHandler'

foreach ($InterviewHandler in $InterviewHandlers) {
    $FolderName = "interviewhandlers/" + $InterviewHandler.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force
    Execute-GetOnUnity $UnityHost ('vmrest/handlers/interviewhandlers/' + $InterviewHandler.ObjectId + "/interviewquestions") $Credential ($FolderName + '/interviewquestions.json') 'InterviewQuestion'
}

$RoutingRules = Execute-GetOnUnity $UnityHost 'vmrest/routingrules' $Credential 'routingrules/list.json' 'RoutingRule'

foreach ($RoutingRule in $RoutingRules) {
    $FolderName = "routingrules/" + $RoutingRule.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force
    Execute-GetOnUnity $UnityHost ('vmrest/routingrules/' + $RoutingRule.ObjectId + "/routingruleconditions") $Credential ($FolderName + '/routingruleconditions.json') 'RoutingruleCondition'
}

Execute-GetOnUnity $UnityHost 'vmrest/partitions' $Credential 'partitions/list.json' 'Partition'
$Schedules = Execute-GetOnUnity $UnityHost 'vmrest/schedules' $Credential 'schedules/list.json' 'Schedule'

foreach ($Schedule in $Schedules) {
    $FolderName = "schedules/" + $Schedule.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force
    Execute-GetOnUnity $UnityHost ('vmrest/schedules/' + $Schedule.ObjectId + "/scheduledetails") $Credential ($FolderName + '/scheduledetails.json') 'ScheduleDetail'
}

$ScheduleSets = Execute-GetOnUnity $UnityHost 'vmrest/schedulesets' $Credential 'schedulesets/list.json' 'ScheduleSet'

foreach ($ScheduleSet in $ScheduleSets) {
    $FolderName = "schedulesets/" + $ScheduleSet.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force
    Execute-GetOnUnity $UnityHost ('vmrest/schedulesets/' + $ScheduleSet.ObjectId + "/schedulesetmembers") $Credential ($FolderName + '/schedulesetmembers.json') 'SchedulesetMember'
}

$ZipFileName = (Get-Date -Format "dd-MM-yyyy_HH-mm-ss").ToString() + "_" + ([System.Uri]$UnityHost).Host + ".zip"

Compress-Archive -Path output-unity/* -DestinationPath $ZipFileName -Force
Remove-Item -Path output-unity -Recurse

if ($Error.Count -gt 0) {
    Write-Host "Something went wrong while running the script." -ForegroundColor Red
}
else {
    Write-Host "The script ran successfully" -ForegroundColor Green
}

$Error.Clear()