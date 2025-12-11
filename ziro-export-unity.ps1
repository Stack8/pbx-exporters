#Requires -Version 7.0

function Invoke-GetOnUnity {
    param (
        [string]$UnityHost,
        [string]$Endpoint,
        [PSCredential]$Credential,
        [string]$OutputFileName,
        [string]$ResourceName
    )

    $ScriptBlock = {
        param(
            [string]$UnityHost,
            [string]$Endpoint,
            [PSCredential]$Cred,
            [string]$ResName
        )
        
        $PageNumber = 1
        $Url = $UnityHost + $Endpoint + "?rowsPerPage=2000&pageNumber=" + $PageNumber
        $Headers = @{ "Accept" = "application/json" }
        
        $ResourcesArray = @()
        try {
            $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Cred
        }
        catch {
            $ResponseCode = $_.Exception.Response.StatusCode.value__
            if ($ResponseCode -eq 401 -or $ResponseCode -eq 403) {
                throw "Wrong credentials or insufficient permissions."
            }
            throw $_
        }
        
        $Resources = $Response.$ResName
        $TotalResources = [int]$Response."@total"
        $ResourcesArray += $Resources
        
        while ($ResourcesArray.Count -lt $TotalResources) {
            $PageNumber++
            $Url = $Host + $Endpoint + "?rowsPerPage=1&pageNumber=" + $PageNumber
            $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Cred
            $Resources = $Response.$ResName
            $ResourcesArray += $Resources
        }
        
        return $ResourcesArray
    }
    
    $Job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $UnityHost, $Endpoint, $Credential, $ResourceName
    
    return @{
        Job            = $Job
        Endpoint       = $Endpoint
        OutputFileName = $OutputFileName
    }
}

function Wait-AsyncGetOnUnity {
    param(
        [array]$AsyncJobs
    )
    
    $Results = @{}
    
    foreach ($JobWrapper in $AsyncJobs) {
        try {
            $ResourcesArray = $JobWrapper.Job | Wait-Job | Receive-Job
            $JsonOutput = ConvertTo-Json $ResourcesArray
            
            if ($JobWrapper.OutputFileName) {
                $OutputFilePath = "output-unity/" + $JobWrapper.OutputFileName
                $JsonOutput | Out-File -FilePath $OutputFilePath
            }
            
            $Results[$JobWrapper.Endpoint] = $JsonOutput | ConvertFrom-Json
        }
        catch {
            Write-Error "Error fetching endpoint $($JobWrapper.Endpoint): $_"
            if ($_ -match "Wrong credentials") {
                Remove-Item -Path output-unity -Recurse -ErrorAction SilentlyContinue
                exit 1
            }
        }
        finally {
            Remove-Job -Job $JobWrapper.Job -ErrorAction SilentlyContinue
        }
    }
    
    return $Results
}

function Export-Greetings {
    param (
        $Greetings,
        [string]$CallHandlerId,
        [string]$FolderName
    ) 
    $ProgressCount = 0
    foreach ($Greeting in $Greetings) {
        $ProgressCount++

        $PlayWhat = [int]$Greeting.PlayWhat
        $Enabled = [System.Convert]::ToBoolean($Greeting.Enabled)

        if ($PlayWhat -eq 1 -and $Enabled -eq $true) {
            $GreetingStreamFiles = Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandlerId + "/greetings/" + $Greeting.GreetingType + "/greetingstreamfiles") $Credential $null 'GreetingStreamFile'
        
            foreach ($GreetingStreamFile in $GreetingStreamFiles) {
                $Url = $UnityHost + ('/vmrest/handlers/callhandlers/' + $CallHandlerId + "/greetings/" + $Greeting.GreetingType + "/greetingstreamfiles/" + $GreetingStreamFile.LanguageCode + "/audio")

                $Headers = @{
                    "Accept" = "application/json"
                }

                Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential -OutFile ("output-unity/" + $FolderName + '/gr_' + $Greeting.GreetingType + "_" + $GreetingStreamFile.LanguageCode + ".wav")
            }
        }

        Write-Progress -activity "Getting greetings information for call handler [$CallHandlerId]..." -status "Fetched: $ProgressCount of $($Greetings.Count)" -percentComplete (($ProgressCount / $Greetings.Count) * 100)
    }
    
}

$Error.Clear()

$UnityHost = Read-Host "Please enter the Unity server URL (ex: https://myunity.com)"
$Credential = Get-Credential -Message "Insert Unity Username and Password"

Write-Output "Running script with $MaxConcurrentRestCalls number of REST calls to make in parallel..."

$ProgressCount = 0

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

$InitialJobs = @()
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/users/' $Credential 'users/list.json' 'User'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/handlers/callhandlers' $Credential 'callhandlers/list.json' 'CallHandler'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/handlers/directoryhandlers' $Credential 'directoryhandlers/list.json' 'DirectoryHandler'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/handlers/interviewhandlers' $Credential 'interviewhandlers/list.json' 'InterviewHandler'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/distributionlists' $Credential 'distributionlists/list.json' 'DistributionList'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/routingrules' $Credential 'routingrules/list.json' 'RoutingRule'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/partitions' $Credential 'partitions/list.json' 'Partition'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/schedules' $Credential 'schedules/list.json' 'Schedule'
$InitialJobs += Invoke-GetOnUnity $UnityHost '/vmrest/schedulesets' $Credential 'schedulesets/list.json' 'ScheduleSet'

Write-Output "Fetching 9 resource collections in parallel..."
$InitialResults = Wait-AsyncGetOnUnity $InitialJobs

$CallHandlers = $InitialResults['/vmrest/handlers/callhandlers']
$InterviewHandlers = $InitialResults['/vmrest/handlers/interviewhandlers']
$DistributionLists = $InitialResults['/vmrest/distributionlists']
$RoutingRules = $InitialResults['/vmrest/routingrules']
$Schedules = $InitialResults['/vmrest/schedules']
$ScheduleSets = $InitialResults['/vmrest/schedulesets']

Write-Output "Finished getting all primary resources"

foreach ($CallHandler in $CallHandlers) {
    $FolderName = "callhandlers/" + $CallHandler.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    $Greetings = Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/greetings") $Credential ($FolderName + '/greetings.json') 'Greeting'
    
    $IsPrimary = [System.Convert]::ToBoolean($CallHandler.IsPrimary)

    if ($IsPrimary -eq $false) {
        Export-Greetings $Greetings $CallHandler.ObjectId $FolderName
        Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/transferoptions") $Credential ($FolderName + '/transferoptions.json') 'TransferOption' | Out-Null
        Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/menuentries") $Credential ($FolderName + '/menuentries.json') 'Menuentry' | Out-Null
        Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/callhandlerowners") $Credential ($FolderName + '/callhandlerowners.json') 'CallHandlerOwner' | Out-Null
    }
    else {
        Write-Output "Primary call handler [$($CallHandler.ObjectId)] - skipping greetings, transfer options, menu entries, and owners"
    }
    
    $ProgressCount++
    Write-Progress -activity "Getting call handlers information..." -status "Fetched: $ProgressCount of $($CallHandlers.Count)" -percentComplete (($ProgressCount / $CallHandlers.Count) * 100)
}
$ProgressCount = 0

foreach ($DistributionList in $DistributionLists) {
    $FolderName = "distributionlists/" + $DistributionList.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Invoke-GetOnUnity $UnityHost ('/vmrest/distributionlists/' + $DistributionList.ObjectId + "/distributionlistmembers") $Credential ($FolderName + '/distributionlistmembers.json') 'DistributionListMember' | Out-Null
    $ProgressCount++
    Write-Progress -activity "Getting distribution lists information..." -status "Fetched: $ProgressCount of $($DistributionLists.Count)" -percentComplete (($ProgressCount / $DistributionLists.Count) * 100)
}
$ProgressCount = 0

foreach ($InterviewHandler in $InterviewHandlers) {
    $FolderName = "interviewhandlers/" + $InterviewHandler.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/interviewhandlers/' + $InterviewHandler.ObjectId + "/interviewquestions") $Credential ($FolderName + '/interviewquestions.json') 'InterviewQuestion' | Out-Null
    $ProgressCount++
    Write-Progress -activity "Getting interview handlers information..." -status "Fetched: $ProgressCount of $($InterviewHandlers.Count)" -percentComplete (($ProgressCount / $InterviewHandlers.Count) * 100)
}
$ProgressCount = 0

foreach ($RoutingRule in $RoutingRules) {
    $FolderName = "routingrules/" + $RoutingRule.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Invoke-GetOnUnity $UnityHost ('/vmrest/routingrules/' + $RoutingRule.ObjectId + "/routingruleconditions") $Credential ($FolderName + '/routingruleconditions.json') 'RoutingruleCondition' | Out-Null
    $ProgressCount++
    Write-Progress -activity "Getting routing rules information..." -status "Fetched: $ProgressCount of $($RoutingRules.Count)" -percentComplete (($ProgressCount / $RoutingRules.Count) * 100)
}
$ProgressCount = 0

foreach ($Schedule in $Schedules) {
    $FolderName = "schedules/" + $Schedule.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Invoke-GetOnUnity $UnityHost ('/vmrest/schedules/' + $Schedule.ObjectId + "/scheduledetails") $Credential ($FolderName + '/scheduledetails.json') 'ScheduleDetail' | Out-Null
    $ProgressCount++
    Write-Progress -activity "Getting schedules information..." -status "Fetched: $ProgressCount of $($Schedules.Count)" -percentComplete (($ProgressCount / $Schedules.Count) * 100)
}
$ProgressCount = 0

foreach ($ScheduleSet in $ScheduleSets) {
    $FolderName = "schedulesets/" + $ScheduleSet.ObjectId
    New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
    Invoke-GetOnUnity $UnityHost ('/vmrest/schedulesets/' + $ScheduleSet.ObjectId + "/schedulesetmembers") $Credential ($FolderName + '/schedulesetmembers.json') 'SchedulesetMember' | Out-Null
    $ProgressCount++
    Write-Progress -activity "Getting schedule sets information..." -status "Fetched: $ProgressCount of $($ScheduleSets.Count)" -percentComplete (($ProgressCount / $ScheduleSets.Count) * 100)
}

$ZipFileName = (Get-Date -Format "dd-MM-yyyy_HH-mm-ss").ToString() + "_" + ([System.Uri]$UnityHost).Host + ".zip"

Compress-Archive -Path output-unity/* -DestinationPath $ZipFileName -Force 
Remove-Item -Path output-unity -Recurse 

$ScriptRanSuccessfully = $Error.Count -eq 0
$Error.Clear()

if ($ScriptRanSuccessfully) {
    Write-Host "The script ran successfully" -ForegroundColor Green
} 
else {
    Write-Host "Something went wrong while running the script." -ForegroundColor Red
}

exit !$ScriptRanSuccessfully
