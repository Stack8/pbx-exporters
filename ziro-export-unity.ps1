#Requires -Version 7.0

$MaxConcurrentJobs = 10

# Builds a job specification for deferred execution with pagination support
# Returns a hashtable containing the ScriptBlock, arguments, endpoint, and output file path.
# The actual job execution is deferred to the concurrency manager (Invoke-GetOnUnityWithLimit).
function Build-GetOnUnityJob {
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
            $Url = $UnityHost + $Endpoint + "?rowsPerPage=1&pageNumber=" + $PageNumber
            $Response = Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Cred
            $Resources = $Response.$ResName
            $ResourcesArray += $Resources
        }
        
        return $ResourcesArray
    }
    
    return @{
        ScriptBlock    = $ScriptBlock
        Arguments      = @($UnityHost, $Endpoint, $Credential, $ResourceName)
        Endpoint       = $Endpoint
        OutputFileName = $OutputFileName
    }
}

# Executes job specifications with concurrency limiting
# Queues all job specs and starts them in batches up to $MaxConcurrentJobs.
# Monitors their progress, starts new jobs as slots become available,
# collects results when complete, and saves JSON output to specified files.
function Invoke-GetOnUnityWithLimit {
    param([array]$AsyncJobs)
    
    $ActiveJobs = @()
    $JobIndex = 0
    
    # Start initial batch of jobs
    while ($JobIndex -lt $AsyncJobs.Count -and $ActiveJobs.Count -lt $MaxConcurrentJobs) {
        $JobSpec = $AsyncJobs[$JobIndex++]
        $Job = Start-Job -ScriptBlock $JobSpec.ScriptBlock -ArgumentList $JobSpec.Arguments
        $ActiveJobs += @{
            Job            = $Job
            Endpoint       = $JobSpec.Endpoint
            OutputFileName = $JobSpec.OutputFileName
        }
    }
    
    $CompletedJobs = @()
    
    # Monitor and manage job concurrency
    while ($ActiveJobs.Count -gt 0) {
        $StillRunning = @()
        
        foreach ($JobWrapper in $ActiveJobs) {
            if ($JobWrapper.Job.State -in @('Completed', 'Failed')) {
                $CompletedJobs += $JobWrapper
            }
            else {
                $StillRunning += $JobWrapper
            }
        }
        
        $ActiveJobs = $StillRunning
        
        # Start new jobs if slots are available
        while ($JobIndex -lt $AsyncJobs.Count -and $ActiveJobs.Count -lt $MaxConcurrentJobs) {
            $JobSpec = $AsyncJobs[$JobIndex++]
            $Job = Start-Job -ScriptBlock $JobSpec.ScriptBlock -ArgumentList $JobSpec.Arguments
            $ActiveJobs += @{
                Job            = $Job
                Endpoint       = $JobSpec.Endpoint
                OutputFileName = $JobSpec.OutputFileName
            }
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    # Process completed jobs and save results
    $Results = @{}
    
    foreach ($JobWrapper in $CompletedJobs) {
        # Ensure job is complete
        if ($JobWrapper.Job.State -notin @('Completed', 'Failed')) {
            $JobWrapper.Job | Wait-Job | Out-Null
        }
        
        # Get results
        $ResourcesArray = $JobWrapper.Job | Receive-Job -ErrorAction Stop
        
        # Handle failures
        if ($JobWrapper.Job.State -eq 'Failed') {
            $JobWrapper.Job.ChildJobs[0].Error | ForEach-Object { throw $_ }
        }
        
        # Save to file if specified
        $JsonOutput = ConvertTo-Json $ResourcesArray
        if ($JobWrapper.OutputFileName) {
            $OutputFilePath = "output-unity/" + $JobWrapper.OutputFileName
            $JsonOutput | Out-File -FilePath $OutputFilePath
        }
        
        # Store results by endpoint
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
    foreach ($Greeting in $Greetings) {

        $PlayWhat = [int]$Greeting.PlayWhat
        $Enabled = [System.Convert]::ToBoolean($Greeting.Enabled)

        if ($PlayWhat -eq 1 -and $Enabled -eq $true) {
            $JobSpec = Build-GetOnUnityJob $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandlerId + "/greetings/" + $Greeting.GreetingType + "/greetingstreamfiles") $Credential $null 'GreetingStreamFile'
            $GreetingStreamFiles = $JobSpec.ScriptBlock.Invoke($JobSpec.Arguments)

            foreach ($GreetingStreamFile in $GreetingStreamFiles) {
                $Url = $UnityHost + ('/vmrest/handlers/callhandlers/' + $CallHandlerId + "/greetings/" + $Greeting.GreetingType + "/greetingstreamfiles/" + $GreetingStreamFile.LanguageCode + "/audio")

                $Headers = @{
                    "Accept" = "application/json"
                }

                Invoke-RestMethod -Uri $Url -Headers $Headers -SkipCertificateCheck -Credential $Credential -OutFile ("output-unity/" + $FolderName + '/gr_' + $Greeting.GreetingType + "_" + $GreetingStreamFile.LanguageCode + ".wav")
            }
        }
    }
}

function Export-CallHandlers {
    param (
        $CallHandlers
    )
    $PendingJobs = @()
    
    foreach ($CallHandler in $CallHandlers) {
        $FolderName = "callhandlers/" + $CallHandler.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        $IsPrimary = [System.Convert]::ToBoolean($CallHandler.IsPrimary)

        if ($IsPrimary -eq $false) {
            $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/greetings") $Credential ($FolderName + '/greetings.json') 'Greeting'
            $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/transferoptions") $Credential ($FolderName + '/transferoptions.json') 'TransferOption'
            $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/menuentries") $Credential ($FolderName + '/menuentries.json') 'Menuentry'
            $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/handlers/callhandlers/' + $CallHandler.ObjectId + "/callhandlerowners") $Credential ($FolderName + '/callhandlerowners.json') 'CallHandlerOwner'
        }
        else {
            Write-Output "Primary call handler [$($CallHandler.ObjectId)] - skipping greetings, transfer options, menu entries, and owners"
        }
    }

    Write-Output "Processing $($PendingJobs.Count) call handler jobs with max $MaxConcurrentJobs concurrent..."
    Invoke-GetOnUnityWithLimit $PendingJobs | Out-Null

    Write-Output "Finished getting call handlers"
}

function Export-DistributionLists {
    param (
        $DistributionLists
    )
    $PendingJobs = @()
    
    foreach ($DistributionList in $DistributionLists) {
        $FolderName = "distributionlists/" + $DistributionList.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/distributionlists/' + $DistributionList.ObjectId + "/distributionlistmembers") $Credential ($FolderName + '/distributionlistmembers.json') 'DistributionListMember'
    }
    
    Write-Output "Processing $($PendingJobs.Count) distribution list jobs with max $MaxConcurrentJobs concurrent..."
    Invoke-GetOnUnityWithLimit $PendingJobs | Out-Null
    Write-Output "Finished getting distribution lists"
}

function Export-InterviewHandlers {
    param (
        $InterviewHandlers
    )
    $PendingJobs = @()
    
    foreach ($InterviewHandler in $InterviewHandlers) {
        $FolderName = "interviewhandlers/" + $InterviewHandler.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/handlers/interviewhandlers/' + $InterviewHandler.ObjectId + "/interviewquestions") $Credential ($FolderName + '/interviewquestions.json') 'InterviewQuestion'
    }
    
    Write-Output "Processing $($PendingJobs.Count) interview handler jobs with max $MaxConcurrentJobs concurrent..."
    Invoke-GetOnUnityWithLimit $PendingJobs | Out-Null
    Write-Output "Finished getting interview handlers"
}

function Export-RoutingRules {
    param (
        $RoutingRules
    )
    $PendingJobs = @()
    
    foreach ($RoutingRule in $RoutingRules) {
        $FolderName = "routingrules/" + $RoutingRule.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/routingrules/' + $RoutingRule.ObjectId + "/routingruleconditions") $Credential ($FolderName + '/routingruleconditions.json') 'RoutingruleCondition'
    }
    
    Write-Output "Processing $($PendingJobs.Count) routing rule jobs with max $MaxConcurrentJobs concurrent..."
    Invoke-GetOnUnityWithLimit $PendingJobs | Out-Null
    Write-Output "Finished getting routing rules"
}

function Export-Schedules {
    param (
        $Schedules
    )
    $PendingJobs = @()
    
    foreach ($Schedule in $Schedules) {
        $FolderName = "schedules/" + $Schedule.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/schedules/' + $Schedule.ObjectId + "/scheduledetails") $Credential ($FolderName + '/scheduledetails.json') 'ScheduleDetail'

    }
    
    Write-Output "Processing $($PendingJobs.Count) schedule jobs with max $MaxConcurrentJobs concurrent..."
    Invoke-GetOnUnityWithLimit $PendingJobs | Out-Null
    Write-Output "Finished getting schedules"
}

function Export-ScheduleSets {
    param (
        $ScheduleSets
    )
    $PendingJobs = @()
    
    foreach ($ScheduleSet in $ScheduleSets) {
        $FolderName = "schedulesets/" + $ScheduleSet.ObjectId
        New-Item -Name ("output-unity/" + $FolderName)  -ItemType Directory -Force | Out-Null
        $PendingJobs += Build-GetOnUnityJob $UnityHost ('/vmrest/schedulesets/' + $ScheduleSet.ObjectId + "/schedulesetmembers") $Credential ($FolderName + '/schedulesetmembers.json') 'SchedulesetMember'
    }
    
    Write-Output "Processing $($PendingJobs.Count) schedule set jobs with max $MaxConcurrentJobs concurrent..."
    Invoke-GetOnUnityWithLimit $PendingJobs | Out-Null
    Write-Output "Finished getting schedule sets"
}


$Error.Clear()

$UnityHost = Read-Host "Please enter the Unity server URL (ex: https://myunity.com)"
$Credential = Get-Credential -Message "Insert Unity Username and Password"

$ScriptStartTime = Get-Date
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
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/users/' $Credential 'users/list.json' 'User'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/handlers/callhandlers' $Credential 'callhandlers/list.json' 'CallHandler'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/handlers/directoryhandlers' $Credential 'directoryhandlers/list.json' 'DirectoryHandler'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/handlers/interviewhandlers' $Credential 'interviewhandlers/list.json' 'InterviewHandler'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/distributionlists' $Credential 'distributionlists/list.json' 'DistributionList'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/routingrules' $Credential 'routingrules/list.json' 'RoutingRule'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/partitions' $Credential 'partitions/list.json' 'Partition'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/schedules' $Credential 'schedules/list.json' 'Schedule'
    $InitialJobs += Build-GetOnUnityJob $UnityHost '/vmrest/schedulesets' $Credential 'schedulesets/list.json' 'ScheduleSet'

    Write-Output "Fetching 9 resource collections in parallel..."
    $InitialResults = Invoke-GetOnUnityWithLimit $InitialJobs

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

    $ScriptEndTime = Get-Date
    $Elapsed = $ScriptEndTime - $ScriptStartTime
    Write-Host ("The script ran successfully in {0:hh\:mm\:ss} (hh:mm:ss)" -f $Elapsed) -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
    Remove-Item -Path output-unity -Recurse -ErrorAction SilentlyContinue
    $ScriptEndTime = Get-Date
    $Elapsed = $ScriptEndTime - $ScriptStartTime
    Write-Host ("Script failed after {0:hh\:mm\:ss} (hh:mm:ss)" -f $Elapsed) -ForegroundColor Yellow
    exit 1
}
