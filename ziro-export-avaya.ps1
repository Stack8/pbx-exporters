#Requires -Version 7.0


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

function Get-AvayaSubEntities {
    param (
        $EntitiesId,
        [string]$EntitiesName,
        [string[]]$Commands,
        [Renci.SshNet.ShellStream]$ShellStream
    ) 
    $ProgressCount = 0
    foreach ($EntityId in $EntitiesId) {
        # Remove the trailing d in all the Avaya ids
        $EntityId = $EntityId.substring(1)

        foreach ($Command in $Commands) {
            Get-AvayaEntity "$Command $EntityId" $ShellStream | Out-Null
        }

        $ProgressCount++
        Write-Progress -activity "Getting $EntitiesName information..." -status "Fetched: $ProgressCount of $($EntitiesId.Count)" -percentComplete (($ProgressCount / $EntitiesId.Count) * 100)
    }
}

function Get-AvayaEntity {
    param (
        [string[]]$Commands,
        [Renci.SshNet.ShellStream]$ShellStream
    )
    $retry = 0
    $streamOut = Write-CommandsToSshStream $Commands $ShellStream
    
    if ([string]::IsNullOrEmpty($streamOut)) {
        throw "$Commands isn't returning a response. Exiting..."
    }

    while (($streamOut).Contains('Terminator received but no command active') -and $retry -le 3) {
        Start-Sleep -s 1
        $streamOut = Write-CommandsToSshStream $Commands $ShellStream
        $retry++
    }

    if ($retry -gt 3) {
        Write-Warning "Failed to get result for commands $Commands"
    }

    Add-Content -Path "output-avaya/avaya.txt" -Value $streamOut
    return $streamOut.Split("`n") | Where-Object { $_.Trim("") -and $Commands -notcontains $_ -and $_ -ne 'n' -and $_ -ne 't' }
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

$sshsession = $null;
$stream = $null;
try {
    Import-Module $PSScriptRoot/modules/Posh-SSH/

    $serverUrl = Read-Host 'Avaya FQDN or IP Address (avayacm.mycompany.com)'
    $credential = Get-Credential -Message 'Enter username and password'

    $sshsession = New-SSHSession -ComputerName $serverurl -Credential $credential -Port 5022
    $stream = New-SSHShellStream -SSHSession $sshsession

    New-Item -Name "output-avaya" -ItemType Directory -Force | Out-Null
    New-Item -ItemType File -Name "output-avaya/avaya.txt" -Force | Out-Null

    Wait-UntilTerminalIsReady $stream

    Get-AvayaEntity 'clist hunt-group' $stream | Out-Null
    Get-AvayaEntity 'clist pickup-group' $stream | Out-Null
    Get-AvayaEntity 'cdisplay alias station' $stream | Out-Null
    Get-AvayaEntity 'cdisplay tenant 1' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 1' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 2' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 3' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 4' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 5' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 6' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 7' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 8' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 9' $stream | Out-Null
    Get-AvayaEntity 'cdisplay coverage remote 10' $stream | Out-Null
    Get-AvayaEntity 'cdisplay feature-access-codes' $stream | Out-Null
    Get-AvayaEntity 'clist coverage path' $stream | Out-Null
    Get-AvayaEntity 'cdisplay ip-network-map' $stream | Out-Null
    Get-AvayaEntity 'cdisplay capacity' $stream | Out-Null
    Get-AvayaEntity 'clist user-profiles' $stream | Out-Null
    Get-AvayaEntity 'clist route-pattern' $stream | Out-Null
    Get-AvayaEntity 'clist integrated-annc-boards' $stream | Out-Null
    Get-AvayaEntity 'clist ars analysis' $stream | Out-Null
    Get-AvayaEntity 'clist media-gateway' $stream | Out-Null
    Get-AvayaEntity 'clist public-unknown-numbering' $stream | Out-Null
    Get-AvayaEntity 'clist off-pbx-telephone station-mapping' $stream | Out-Null
    Get-AvayaEntity 'clist intercom-group' $stream | Out-Null
    Get-AvayaEntity 'clist abbreviated-dialing personal' $stream |  Out-Null
    Get-AvayaEntity 'clist station' $stream | Out-Null
    Get-AvayaEntity 'clist trunk-group' $stream | Out-Null
    Get-AvayaEntity 'clist vector' $stream | Out-Null
    Get-AvayaEntity 'clist vdn' $stream | Out-Null
    Get-AvayaEntity 'clist ip-network-region monitor' $stream | Out-Null
    Get-AvayaEntity 'clist announcement' $stream | Out-Null
    $extensionIds = Get-AvayaEntity @('clist station', 'f8005ff00') $stream
    $corIds = Get-AvayaEntity @('clist station', 'f8001ff00') $stream
    $cosIds = Get-AvayaEntity @('clist station', 'f8002ff00') $stream
    $vectorIds = Get-AvayaEntity @('clist vector', 'f0001ff01') $stream
    $vdnIds = Get-AvayaEntity @('clist vdn', 'f8005ff01') $stream
    $ipNetworkRegionMonitorIds = Get-AvayaEntity @('clist ip-network-region monitor', 'f6c00ff00') $stream
    $announcementIds = Get-AvayaEntity @('clist announcement', 'f8005ff00') $stream

    Get-AvayaSubEntities $extensionIds 'Extensions' @('cdisplay station', 'clist bridged-extensions', 'cdisplay button-labels') $stream
    Get-AvayaSubEntities $corIds 'CORs' 'cdisplay cor' $stream
    Get-AvayaSubEntities $cosIds 'COSs' 'cdisplay cos' $stream
    Get-AvayaSubEntities $trunkGroupIds 'Trunk Groups' @('cdisplay trunk-group', 'cdisplay inc-call-handling-trmt trunk-group') $stream
    Get-AvayaSubEntities $vectorIds 'Vectors' 'cdisplay vector' $stream
    Get-AvayaSubEntities $vdnIds 'VDNs' 'cdisplay vdn' $stream
    Get-AvayaSubEntities $ipNetworkRegionMonitorIds 'IP Network Regions' 'cstatus ip-network-region' $stream
    Get-AvayaSubEntities $announcementIds 'Announcements' 'cdisplay announcement' $stream

    Get-AvayaEntity "clogoff" $stream | Out-Null

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