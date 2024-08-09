#Requires -Version 7.0
#Requires -Modules Posh-SSH



function Initialize-OssiTerminal {
    param (
        [Renci.SshNet.ShellStream]$SshSession
    )
    $stream.WriteLine('ossi')

    $streamOut = $stream.Read()
    while (-Not ($streamOut).Contains("ossi")) {
        Start-Sleep -s 1
        $streamOut = $stream.Read()
    }
}


function Invoke-CommandOnAyavaSshStream {
    param (
        [string]$Command,
        [Renci.SshNet.ShellStream]$SshSession
    )
    $stream.WriteLine($Command)
    $stream.WriteLine('t')

    $streamOut = $stream.Read()
    while (($streamOut).length -eq 0) {
        Start-Sleep -s 1
        $streamOut = $stream.Read()
    }

    Write-Output $streamOut
}


$serverUrl = Read-Host 'Avaya FQDN or IP Address (avayacm.mycompany.com)'
$credential = Get-Credential -Message 'Enter username and password'

$sshsession = New-SSHSession -ComputerName $serverurl -Credential $credential -Port 5022

$stream = New-SSHShellStream -SSHSession $sshsession

Initialize-OssiTerminal($stream)
Invoke-CommandOnAyavaSshStream('clist hunt-group', $stream)

Remove-SSHSession -SSHSession $sshsession
