#Requires -Version 7.0
#Requires -Modules Posh-SSH

function Wait-UntilTerminalIsReady {
    param (
        [Renci.SshNet.ShellStream]$ShellStream
    )
    $retry = 0
    $streamOut = $ShellStream.Read()

    # Wait until we can select terminal type and choose ossi
    while (-Not ($streamOut).Contains("Terminal Type") -and $retry -le 10) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
        $retry++
    }

    if ($retry -gt 10) {
        throw "Timed out whie initializing waiting for terminal type prompt"
    }

    $retry = 0
    $ShellStream.WriteLine('ossi')
    
    # Read until stream is empty before starting to send commands
    while (($streamOut).length -ne 0 -and $retry -le 10) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
    }

    if ($retry -gt 10) {
        throw "Timed out whie initializing OSSI terminal"
    }
}

function Write-CommandsToSshStream {
    param (
        [string[]]$Commands,
        [Renci.SshNet.ShellStream]$ShellStream
    )

    $retry = 0
    foreach ($Command in $Commands) {
        $ShellStream.WriteLine($Command)
    }
    $ShellStream.WriteLine('t')

    $streamOut = $ShellStream.Read()
    while (($streamOut).length -eq 0 -and $retry -le 10) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
        $retry++
    }

    return $streamOut
}

function Get-AvayaSubEntities {
    param (
        $EntitiesId,
        [string]$EntitiesName,
        [string[]]$Commands,
        [Renci.SshNet.ShellStream]$ShellStream
    ) 
    $progressCount = 0
    foreach ($EntityId in $EntitiesId) {
        # Remove the trailing d in all the Avaya ids
        $EntityId = $EntityId.substring(1)

        foreach ($Command in $Commands) {
            Get-AvayaEntities "$Command $EntityId" $ShellStream | Out-Null
        }

        $progressCount++
        Write-Progress -activity "Getting $EntitiesName information..." -status "Fetched: $progressCount of $($EntitiesId.Count)" -percentComplete (($progressCount / $EntitiesId.Count) * 100)
    }
}

function Get-AvayaEntities {
    param (
        [string[]]$Commands,
        [Renci.SshNet.ShellStream]$ShellStream
    )
    $retry = 0
    $commandOutput = Write-CommandsToSshStream $Commands $ShellStream
    
    while (([string]::IsNullOrEmpty($commandOutput) -or ($commandOutput).Contains('Terminator received but no command active')) -and $retry -le 5) {
        Start-Sleep -s 1
        $commandOutput = Write-CommandsToSshStream $Commands $ShellStream
        $retry++
    }

    if ($retry -gt 5) {
        Write-Warning "Failed to get result for commands $Commands"
    }

    Add-Content -Path "output-avaya/avaya.txt" -Value $commandOutput
    return $commandOutput.Split("`n") | Where-Object { $_.Trim("") -and $Commands -notcontains $_ -and $_ -ne 'n' -and $_ -ne 't' }
}


function Write-EntitiesProgressToHost {
    param (
        [Int]$PbxProgressCount
    )
    Write-Progress -activity "Gathering PBX information..." -status "Fetched: $PbxProgressCount of 42" -percentComplete (($PbxProgressCount / 42) * 100)
}

function Get-CdrInformation {
    param (
        [string[]]$ServerUrl
    )
    $answer = Read-Host "Do you want to also export CDRs information [y/n]? "
    if ($answer -eq 'y') { 
        New-Item -Name "output-avaya/CDR" -ItemType Directory -Force | Out-Null
        $credential = Get-Credential -Message 'Enter CDR username and password'
    } else {
        Write-Output "Skipping CDRs export..."
    }
}

$sshsession = $null;
$stream = $null;
try {
    $serverUrl = Read-Host 'Avaya FQDN or IP Address (avayacm.mycompany.com)'
    $credential = Get-Credential -Message 'Enter username and password'

    New-Item -Name "output-avaya" -ItemType Directory -Force | Out-Null
    New-Item -ItemType File -Name "output-avaya/avaya.txt" -Force | Out-Null

    Get-CdrInformation $serverUrl
    
    $sshsession = New-SSHSession -ComputerName $serverurl -Credential $credential -Port 5022 -AcceptKey
    $stream = New-SSHShellStream -SSHSession $sshsession

    Wait-UntilTerminalIsReady $stream

    $pbxProgressCount = 0

    Get-AvayaEntities 'cdisplay system-parameters cdr' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist hunt-group' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist pickup-group' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay alias station' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay tenant 1' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 1' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 2' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 3' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 4' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 5' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 6' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 7' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 8' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 9' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay coverage remote 10' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay feature-access-codes' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount
    
    Get-AvayaEntities 'clist coverage path' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay ip-network-map' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'cdisplay capacity' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist user-profiles' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist route-pattern' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist integrated-annc-boards' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount
    
    Get-AvayaEntities 'clist ars analysis' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist media-gateway' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist public-unknown-numbering' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist off-pbx-telephone station-mapping' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist intercom-group' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist abbreviated-dialing personal' $stream |  Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist station' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist trunk-group' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist vector' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist vdn' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist ip-network-region monitor' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaEntities 'clist announcement' $stream | Out-Null
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $extensionIds = Get-AvayaEntities @('clist station', 'f8005ff00') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $corIds = Get-AvayaEntities @('clist station', 'f8001ff00') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $cosIds = Get-AvayaEntities @('clist station', 'f8002ff00') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $trunkGroupIds = Get-AvayaEntities @('clist trunk-group', 'f800bff00') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $vectorIds = Get-AvayaEntities @('clist vector', 'f0001ff01') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $vdnIds = Get-AvayaEntities @('clist vdn', 'f8005ff01') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $ipNetworkRegionMonitorIds = Get-AvayaEntities @('clist ip-network-region monitor', 'f6c00ff00') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    $announcementIds = Get-AvayaEntities @('clist announcement', 'f8005ff00') $stream
    $pbxProgressCount++
    Write-EntitiesProgressToHost $pbxProgressCount

    Get-AvayaSubEntities $extensionIds 'Extensions' @('cdisplay station', 'clist bridged-extensions', 'cdisplay button-labels') $stream
    Get-AvayaSubEntities $corIds 'CORs' 'cdisplay cor' $stream
    Get-AvayaSubEntities $cosIds 'COSs' 'cdisplay cos' $stream
    Get-AvayaSubEntities $trunkGroupIds 'Trunk Groups' @('cdisplay trunk-group', 'cdisplay inc-call-handling-trmt trunk-group') $stream
    Get-AvayaSubEntities $vectorIds 'Vectors' 'cdisplay vector' $stream
    Get-AvayaSubEntities $vdnIds 'VDNs' 'cdisplay vdn' $stream
    Get-AvayaSubEntities $ipNetworkRegionMonitorIds 'IP Network Regions' 'cstatus ip-network-region' $stream
    Get-AvayaSubEntities $announcementIds 'Announcements' 'cdisplay announcement' $stream

    Get-AvayaEntities "clogoff" $stream | Out-Null

    $ZipFileName = "avaya_" + (Get-Date -Format "dd-MM-yyyy_HH-mm-ss").ToString() + ".zip"

    Compress-Archive -Path output-avaya/* -DestinationPath $ZipFileName -Force 
    Remove-Item -Path output-avaya -Recurse 
    
    Write-Host "The script ran successfully" -ForegroundColor Green
    exit 0
}
catch { 
    Write-host -f red "Encountered Error:"$_.Exception.Message
    Write-Error "Avaya information export failed"
    exit 1
}
finally {
    if ($null -ne $sshsession) {
        Remove-SSHSession -SSHSession $sshsession | Out-Null
    }
}