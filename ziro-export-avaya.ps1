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
        [string]$Command,
        [Renci.SshNet.ShellStream]$ShellStream
    )
    $retry = 0

    $ShellStream.WriteLine($Command)
    $ShellStream.WriteLine('t')

    $streamOut = $ShellStream.Read()
    while (($streamOut).length -eq 0 -and $retry -le 10) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
        $retry++
    }

    if ([string]::IsNullOrEmpty($streamOut)) {
        throw "Failed to get result for command $Command"
    }

    Add-Content -Path "output-avaya/avaya.txt" -Value $streamOut
}


$serverUrl = Read-Host 'Avaya FQDN or IP Address (avayacm.mycompany.com)'
$credential = Get-Credential -Message 'Enter username and password'

$sshsession = New-SSHSession -ComputerName $serverurl -Credential $credential -Port 5022
$stream = New-SSHShellStream -SSHSession $sshsession

New-Item -Name "output-avaya" -ItemType Directory -Force | Out-Null
New-Item -ItemType File -Name "output-avaya/avaya.txt" -Force | Out-Null

Wait-UntilTerminalIsReady $stream

Invoke-CommandOnAyavaSshStream 'clist hunt-group' $stream
Invoke-CommandOnAyavaSshStream 'clist pickup-group' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay alias station' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay tenant 1' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 1' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 2' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 3' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 4' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 5' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 6' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 7' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 8' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 9' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay coverage remote 10' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay feature-access-codes' $stream
Invoke-CommandOnAyavaSshStream 'clist coverage path' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay ip-network-map' $stream
Invoke-CommandOnAyavaSshStream 'cdisplay capacity' $stream
Invoke-CommandOnAyavaSshStream 'clist user-profiles' $stream
Invoke-CommandOnAyavaSshStream 'clist route-pattern' $stream
Invoke-CommandOnAyavaSshStream 'clist integrated-annc-boards' $stream
Invoke-CommandOnAyavaSshStream 'clist ars analysis' $stream
Invoke-CommandOnAyavaSshStream 'clist media-gateway' $stream
Invoke-CommandOnAyavaSshStream 'clist public-unknown-numbering' $stream
Invoke-CommandOnAyavaSshStream 'clist off-pbx-telephone station-mapping' $stream
Invoke-CommandOnAyavaSshStream 'clist intercom-group' $stream
Invoke-CommandOnAyavaSshStream 'clist abbreviated-dialing personal' $stream
Invoke-CommandOnAyavaSshStream 'clist station' $stream

Remove-SSHSession -SSHSession $sshsession | Out-Null
