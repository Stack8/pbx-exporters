#Requires -Version 7.0
#Requires -Modules Posh-SSH


function Wait-UntilTerminalIsReady {
    param (
        [Renci.SshNet.ShellStream]$ShellStream
    )
    $streamOut = $ShellStream.Read()

    # Wait until we can select terminal type and choose ossi
    while (-Not ($streamOut).Contains("Terminal Type")) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
    }
    $ShellStream.WriteLine('ossi')

    # Wait until stream is empty before starting to send commands
    while (($streamOut).length -ne 0) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
    }
}


function Invoke-CommandOnAyavaSshStream {
    param (
        [string]$Command,
        [Renci.SshNet.ShellStream]$ShellStream
    )
    $ShellStream.WriteLine($Command)
    $ShellStream.WriteLine('t')

    $streamOut = $ShellStream.Read()
    while (($streamOut).length -eq 0) {
        Start-Sleep -s 1
        $streamOut = $ShellStream.Read()
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

Remove-SSHSession -SSHSession $sshsession | Out-Null
