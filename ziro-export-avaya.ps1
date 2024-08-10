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
    return $streamOut
}
try {
    Import-Module $PSScriptRoot/modules/Posh-SSH/

    $serverUrl = Read-Host 'Avaya FQDN or IP Address (avayacm.mycompany.com)'
    $credential = Get-Credential -Message 'Enter username and password'

    $sshsession = New-SSHSession -ComputerName $serverurl -Credential $credential -Port 5022
    $stream = New-SSHShellStream -SSHSession $sshsession

    New-Item -Name "output-avaya" -ItemType Directory -Force | Out-Null
    New-Item -ItemType File -Name "output-avaya/avaya.txt" -Force | Out-Null

    Wait-UntilTerminalIsReady $stream

    $stations = Invoke-CommandOnAyavaSshStream @('clist station', 'f8005ff00') $stream

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

    Remove-SSHSession -SSHSession $sshsession | Out-Null
    Write-Host "The script ran successfully" -ForegroundColor Green
    exit 0
}
catch { 
    Write-host -f red "Encountered Error:"$_.Exception.Message
    Write-Error "Avaya information export failed"
    exit 1
}