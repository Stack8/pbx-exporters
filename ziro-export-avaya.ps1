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
    return $streamOut.Split("`n") | Where-Object { $_.Trim("") -and $Commands -notcontains $_ -and $_ -ne 'n' -and $_ -ne 't'}
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

    $extensions = Invoke-CommandOnAyavaSshStream @('clist station', 'f8005ff00') $stream

    foreach ($extension in $extensions) {
        $extension = $extension.substring(1)
        Invoke-CommandOnAyavaSshStream "cdisplay station $extension" $stream | Out-Null
        Invoke-CommandOnAyavaSshStream "clist bridged-extensions $extension" $stream | Out-Null
        Invoke-CommandOnAyavaSshStream "cdisplay button-labels $extension" $stream | Out-Null
    }

    $cors = Invoke-CommandOnAyavaSshStream @('clist station', 'f8001ff00') $stream

    foreach ($cor in $cors) {
        $cor = $cor.substring(1)
        Invoke-CommandOnAyavaSshStream "cdisplay cor $cor" $stream | Out-Null
    }

    $coss = Invoke-CommandOnAyavaSshStream @('clist station', 'f8002ff00') $stream

    foreach ($cos in $coss) {
        $cos = $cos.substring(1)
        Invoke-CommandOnAyavaSshStream "cdisplay cos $cos" $stream | Out-Null
    }

    $trunkGroups = Invoke-CommandOnAyavaSshStream @('clist trunk-group', 'f800bff00') $stream

    foreach ($trunkGroup in $trunkGroups) {
        $trunkGroup = $trunkGroup.substring(1)
        Invoke-CommandOnAyavaSshStream "cdisplay trunk-group $trunkGroup" $stream | Out-Null
        Invoke-CommandOnAyavaSshStream "inc-call-handling-trmt trunk-group $trunkGroup" $stream | Out-Null
    }

    $vectors = Invoke-CommandOnAyavaSshStream @('clist vector', 'f0001ff01') $stream

    foreach ($vector in $vectors) {
        $vector = $vector.substring(1)
        Invoke-CommandOnAyavaSshStream "cdisplay vector $vector" $stream | Out-Null
    }

    Invoke-CommandOnAyavaSshStream "clogoff" $stream | Out-Null

    Remove-SSHSession -SSHSession $sshsession | Out-Null
    Write-Host "The script ran successfully" -ForegroundColor Green
    exit 0
}
catch { 
    Write-host -f red "Encountered Error:"$_.Exception.Message
    Write-Error "Avaya information export failed"
    exit 1
}