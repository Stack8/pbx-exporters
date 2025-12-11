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
        Write-Host "Fetched page 1 of $ResName ($($ResourcesArray.Count) of $TotalResources)"
        
        while ($ResourcesArray.Count -lt $TotalResources) {
            $PageNumber++
            $Url = $Host + $Endpoint + "?rowsPerPage=1&pageNumber=" + $PageNumber
            $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Cred
            $Resources = $Response.$ResName
            $ResourcesArray += $Resources
            Write-Host "Fetched page $PageNumber of $ResName ($($ResourcesArray.Count) of $TotalResources)"
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
        $ResourcesArray = $JobWrapper.Job | Wait-Job | Receive-Job -ErrorAction Stop
        
        if ($JobWrapper.Job.State -eq 'Failed') {
            $JobWrapper.Job.ChildJobs[0].Error | ForEach-Object { throw $_ }
        }
        
        $JsonOutput = ConvertTo-Json $ResourcesArray
        
        if ($JobWrapper.OutputFileName) {
            $OutputFilePath = "output-unity/" + $JobWrapper.OutputFileName
            $JsonOutput | Out-File -FilePath $OutputFilePath
        }
        
        $Results[$JobWrapper.Endpoint] = $JsonOutput | ConvertFrom-Json
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

function Export-CallHandlers {
    param (
        $CallHandlers
    )
    $ProgressCount = 0
    foreach ($CallHandler in $CallHandlers) {
        $FolderName = "callhandlers/" + $CallHandler.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        $Greetings = Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/greetings") $Credential ($FolderName + '/greetings.json') 'Greeting'
        
        $IsPrimary = [System.Convert]::ToBoolean($CallHandler.IsPrimary)

        if ($IsPrimary -eq $false) {
            Export-Greetings $Greetings $CallHandler.ObjectId $FolderName
            Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/transferoptions") $Credential ($FolderName + '/transferoptions.json') 'TransferOption'
            Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/menuentries") $Credential ($FolderName + '/menuentries.json') 'Menuentry'
            Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/callhandlerowners") $Credential ($FolderName + '/callhandlerowners.json') 'CallHandlerOwner'
        }
        else {
            Write-Output "Primary call handler [$($CallHandler.ObjectId)] - skipping greetings, transfer options, menu entries, and owners"
        }
        
        $ProgressCount++
        Write-Progress -activity "Getting call handlers information..." -status "Fetched: $ProgressCount of $($CallHandlers.Count)" -percentComplete (($ProgressCount / $CallHandlers.Count) * 100)
    }
    Write-Output "Finished getting call handlers"
}

function Export-DistributionLists {
    param (
        $DistributionLists
    )
    $ProgressCount = 0
    foreach ($DistributionList in $DistributionLists) {
        $FolderName = "distributionlists/" + $DistributionList.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        Invoke-GetOnUnity $UnityHost ('/vmrest/distributionlists/' + $DistributionList.ObjectId + "/distributionlistmembers") $Credential ($FolderName + '/distributionlistmembers.json') 'DistributionListMember'
        $ProgressCount++
        Write-Progress -activity "Getting distribution lists information..." -status "Fetched: $ProgressCount of $($DistributionLists.Count)" -percentComplete (($ProgressCount / $DistributionLists.Count) * 100)
    }
    Write-Output "Finished getting distribution lists"
}

function Export-InterviewHandlers {
    param (
        $InterviewHandlers
    )
    $ProgressCount = 0
    foreach ($InterviewHandler in $InterviewHandlers) {
        $FolderName = "interviewhandlers/" + $InterviewHandler.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        Invoke-GetOnUnity $UnityHost ('/vmrest/handlers/interviewhandlers/' + $InterviewHandler.ObjectId + "/interviewquestions") $Credential ($FolderName + '/interviewquestions.json') 'InterviewQuestion'
        $ProgressCount++
        Write-Progress -activity "Getting interview handlers information..." -status "Fetched: $ProgressCount of $($InterviewHandlers.Count)" -percentComplete (($ProgressCount / $InterviewHandlers.Count) * 100)
    }
    Write-Output "Finished getting interview handlers"
}

function Export-RoutingRules {
    param (
        $RoutingRules
    )
    $ProgressCount = 0
    foreach ($RoutingRule in $RoutingRules) {
        $FolderName = "routingrules/" + $RoutingRule.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        Invoke-GetOnUnity $UnityHost ('/vmrest/routingrules/' + $RoutingRule.ObjectId + "/routingruleconditions") $Credential ($FolderName + '/routingruleconditions.json') 'RoutingruleCondition'
        $ProgressCount++
        Write-Progress -activity "Getting routing rules information..." -status "Fetched: $ProgressCount of $($RoutingRules.Count)" -percentComplete (($ProgressCount / $RoutingRules.Count) * 100)
    }
    Write-Output "Finished getting routing rules"
}

function Export-Schedules {
    param (
        $Schedules
    )
    $ProgressCount = 0
    foreach ($Schedule in $Schedules) {
        $FolderName = "schedules/" + $Schedule.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        Invoke-GetOnUnity $UnityHost ('/vmrest/schedules/' + $Schedule.ObjectId + "/scheduledetails") $Credential ($FolderName + '/scheduledetails.json') 'ScheduleDetail'
        $ProgressCount++
        Write-Progress -activity "Getting schedules information..." -status "Fetched: $ProgressCount of $($Schedules.Count)" -percentComplete (($ProgressCount / $Schedules.Count) * 100)
    }
    Write-Output "Finished getting schedules"
}

function Export-ScheduleSets {
    param (
        $ScheduleSets
    )
    $ProgressCount = 0
    foreach ($ScheduleSet in $ScheduleSets) {
        $FolderName = "schedulesets/" + $ScheduleSet.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        Invoke-GetOnUnity $UnityHost ('/vmrest/schedulesets/' + $ScheduleSet.ObjectId + "/schedulesetmembers") $Credential ($FolderName + '/schedulesetmembers.json') 'SchedulesetMember'
        $ProgressCount++
        Write-Progress -activity "Getting schedule sets information..." -status "Fetched: $ProgressCount of $($ScheduleSets.Count)" -percentComplete (($ProgressCount / $ScheduleSets.Count) * 100)
    }
    Write-Output "Finished getting schedule sets"
}

$Error.Clear()

$UnityHost = Read-Host "Please enter the Unity server URL (ex: https://myunity.com)"
$Credential = Get-Credential -Message "Insert Unity Username and Password"

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

try {
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

    Export-CallHandlers $CallHandlers
    Export-DistributionLists $DistributionLists
    Export-InterviewHandlers $InterviewHandlers
    Export-RoutingRules $RoutingRules
    Export-Schedules $Schedules
    Export-ScheduleSets $ScheduleSets

    $ZipFileName = (Get-Date -Format "dd-MM-yyyy_HH-mm-ss").ToString() + "_" + ([System.Uri]$UnityHost).Host + ".zip"

    Write-Output "Creating archive: $ZipFileName"
    Compress-Archive -Path output-unity/* -DestinationPath $ZipFileName -Force 
    Write-Output "Removing temporary output directory"
    Remove-Item -Path output-unity -Recurse 

    Write-Host "The script ran successfully" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Remove-Item -Path output-unity -Recurse -ErrorAction SilentlyContinue
    exit 1
}
