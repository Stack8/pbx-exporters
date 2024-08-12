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
        # Remove the trailing d
        $EntityId = $EntityId.substring(1)

        foreach ($Command in $Commands) {
            Invoke-CommandOnAyavaSshStream "$Command $EntityId" $ShellStream | Out-Null
            $ProgressCount++
            Write-Progress -activity "Getting $EntitiesName information..." -status "Fetched: $ProgressCount of $($EntitiesId.Count)" -percentComplete (($ProgressCount / $EntitiesId.Count) * 100)
        }
    }
}

function Invoke-CommandOnAyavaSshStream {
    param (
        [string[]]$Commands,
        [Renci.SshNet.ShellStream]$ShellStream
    )
    $retry = 0

    foreach ($Command in $Commands) {
        Write-Host "Running command $Command"
        $ShellStream.WriteLine($Command)
    }
    $ShellStream.WriteLine('t')

    $streamOut = $ShellStream.Read()
    while (($streamOut).length -eq 0 -and $retry -le 10) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
        $retry++
    }

    if ([string]::IsNullOrEmpty($streamOut)) {
        throw "Failed to get result for commands $Commands"
    }

    Add-Content -Path "output-avaya/avaya.txt" -Value $streamOut
    return $streamOut.Split("`n") | Where-Object { $_.Trim("") -and $Commands -notcontains $_ -and $_ -ne 'n' -and $_ -ne 't' }
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

    Invoke-CommandOnAyavaSshStream 'clist hunt-group' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist pickup-group' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay alias station' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay tenant 1' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 1' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 2' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 3' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 4' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 5' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 6' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 7' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 8' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 9' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 10' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay feature-access-codes' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist coverage path' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay ip-network-map' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'cdisplay capacity' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist user-profiles' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist route-pattern' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist integrated-annc-boards' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist ars analysis' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist media-gateway' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist public-unknown-numbering' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist off-pbx-telephone station-mapping' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist intercom-group' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist abbreviated-dialing personal' $stream |  Out-Null
    Invoke-CommandOnAyavaSshStream 'clist station' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist trunk-group' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist vector' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist vdn' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist ip-network-region monitor' $stream | Out-Null
    Invoke-CommandOnAyavaSshStream 'clist announcement' $stream | Out-Null

    $extensionIds = Invoke-CommandOnAyavaSshStream @('clist station', 'f8005ff00') $stream
    Get-AvayaSubEntities $extensionIds 'Extensions' @('cdisplay station', 'clist bridged-extensions', 'cdisplay button-labels') $stream

    $corIds = Invoke-CommandOnAyavaSshStream @('clist station', 'f8001ff00') $stream
    Get-AvayaSubEntities $corIds 'CORs' 'cdisplay cor' $stream

    $cosIds = Invoke-CommandOnAyavaSshStream @('clist station', 'f8002ff00') $stream
    Get-AvayaSubEntities $cosIds 'COSs' 'cdisplay cos' $stream

    $trunkGroupIds = Invoke-CommandOnAyavaSshStream @('clist trunk-group', 'f800bff00') $stream
    Get-AvayaSubEntities $trunkGroupIds 'Trunk Groups' @('cdisplay trunk-group', 'inc-call-handling-trmt trunk-group') $stream

    $vectorIds = Invoke-CommandOnAyavaSshStream @('clist vector', 'f0001ff01') $stream
    Get-AvayaSubEntities $vectorIds 'Vectors' 'cdisplay vector' $stream

    $vdnIds = Invoke-CommandOnAyavaSshStream @('clist vdn', 'f8003ff02') $stream
    Get-AvayaSubEntities $vdnIds 'VDNs' 'cdisplay vdn' $stream

    $ipNetworkRegionMonitorIds = Invoke-CommandOnAyavaSshStream @('clist ip-network-region monitor', 'f6c00ff00') $stream
    Get-AvayaSubEntities $ipNetworkRegionMonitorIds 'IP Network Regions' 'cstatus ip-network-region' $stream

    $announcementIds = Invoke-CommandOnAyavaSshStream @('clist announcement', 'f8005ff00') $stream
    Get-AvayaSubEntities $announcementIds 'Announcements' 'cdisplay announcement' $stream

    Write-Host "The script ran successfully" -ForegroundColor Green
    exit 0
}
catch { 
    Write-host -f red "Encountered Error:"$_.Exception.Message
    Write-Error "Avaya information export failed"
    exit 1
}
finally {
    if ($null -ne $stream) {
        Invoke-CommandOnAyavaSshStream "clogoff" $stream | Out-Null
    }
    if ($null -ne $sshsession) {
        Remove-SSHSession -SSHSession $sshsession | Out-Null
    }
}