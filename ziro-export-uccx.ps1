class UccxConnector {
    [string] $BaseUrl
    [PSCredential] $Credential

    UccxConnector(
        [string] $BaseUrl,
        [PSCredential] $Credential
    ) {
        $this.BaseUrl = $BaseUrl
        $this.Credential = $Credential
    }

    [PSCustomObject] InvokeGet([string]$Path) {
        $headers =  @{
            'Accept' = 'application/json'
        }
        $uri = $this.BaseUrl + $Path
        return Invoke-RestMethod -Method 'Get' -Uri $uri -Credential $this.Credential -Headers $headers -SkipCertificateCheck
    }
}

function Export-UccxEntities([UccxConnector]$Connector, [string]$Path, $ExportDirectory, [string]$EntityName) {
    try 
    {
        $entities = $Connector.InvokeGet($Path)
        $entityDirectory = New-Item -Path $ExportDirectory -Name $EntityName -ItemType Directory
        $entities | ConvertTo-Json -depth 100 | Set-Content -Path "${entityDirectory}/list.json"
    }
    catch 
    {
        Write-Error "Error exporting ${EntityName}: $_"
        return $false
    }

    Write-Host "Finished exporting ${EntityName}"
    return $true
} 

function Export-Skills([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/skill'
        ExportDirectory = $ExportDirectory
        EntityName      = 'skills'
    }
    return Export-UccxEntities @parameters
}

function Export-Resources([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/resource'
        ExportDirectory = $ExportDirectory
        EntityName      = 'resources'
    }
    return Export-UccxEntities @parameters
}

function Export-ResourceGroups([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/resourceGroup'
        ExportDirectory = $ExportDirectory
        EntityName      = 'resourceGroups'
    }
    return Export-UccxEntities @parameters
}

function Export-Csqs([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/csq'
        ExportDirectory = $ExportDirectory
        EntityName      = 'csqs'
    }
    return Export-UccxEntities @parameters
}

function Export-Teams([UccxConnector]$Connector, $ExportDirectory) {
    try 
    {
        $teams = $Connector.InvokeGet('/adminapi/team')
        $teamsDirectory = New-Item -Path $ExportDirectory -Name 'teams' -ItemType Directory
        $teams | ConvertTo-Json -depth 100 | Set-Content -Path "${teamsDirectory}/list.json"
    }
    catch 
    {
        Write-Error "Error exporting teams: $_"
        return $false
    }

    for ($i=0; $i -lt $teams.team.Length; $i++) {
        $progressParameters = @{
            Activity         = 'Exporting team information...'
            Status           = "Fetched: $i of $($teams.team.Length)"
            PercentComplete  = ($i / $teams.team.Length) * 100
        }

        Write-Progress @progressParameters

        try
        {
            $teamId = $teams.team[$i].teamId
            $Connector.InvokeGet("/adminapi/team/${teamId}") | ConvertTo-Json -depth 100 | Set-Content -Path "${teamsDirectory}/${teamId}.json"
        }
        catch
        {
            Write-Error "Error exporting team with teamId=${teamId}: $_"
        }
    }

    Write-Host "Finished exporting teams"
    return $true
}

function Export-CallControlGroups([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/callControlGroup'
        ExportDirectory = $ExportDirectory
        EntityName      = 'callControlGroups'
    }
    return Export-UccxEntities @parameters
}

function Export-Triggers([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/trigger'
        ExportDirectory = $ExportDirectory
        EntityName      = 'triggers'
    }
    return Export-UccxEntities @parameters
}

function Export-HttpsTriggers([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/httpTrigger'
        ExportDirectory = $ExportDirectory
        EntityName      = 'httpTriggers'
    }
    return Export-UccxEntities @parameters
}

function Export-Applications([UccxConnector]$Connector, $ExportDirectory) {
    try 
    {
        $applications = $Connector.InvokeGet('/adminapi/application')
        $applicationsDirectory = New-Item -Path $ExportDirectory -Name 'applications' -ItemType Directory
        $applications | ConvertTo-Json -depth 100 | Set-Content -Path "${applicationsDirectory}/list.json"
    }
    catch 
    {
        Write-Error "Error exporting applications: $_"
        return $false
    }

    for ($i=0; $i -lt $applications.application.Length; $i++) {
        $progressParameters = @{
            Activity         = 'Exporting application information...'
            Status           = "Fetched: $i of $($applications.application.Length)"
            PercentComplete  = ($i / $applications.application.Length) * 100
        }

        Write-Progress @progressParameters

        try
        {
            $applicationName = $applications.application[$i].applicationName
            $Connector.InvokeGet("/adminapi/application/${applicationName}?allScriptParams") | ConvertTo-Json -depth 100 | Set-Content -Path "${applicationsDirectory}/${applicationName}.json"
        }
        catch
        {
            Write-Error "Error exporting application with script sarameters for application ${applicationName}: $_"
        }
    }

    Write-Host "Finished exporting applications"
    return $true
}

function Export-Campaigns([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/campaign'
        ExportDirectory = $ExportDirectory
        EntityName      = 'campaigns'
    }
    return Export-UccxEntities @parameters
}

function Export-AreaCodes([UccxConnector]$Connector, $ExportDirectory) {
    $parameters = @{
        Connector       = $Connector
        Path            = '/adminapi/areaCode'
        ExportDirectory = $ExportDirectory
        EntityName      = 'areaCodes'
    }
    return Export-UccxEntities @parameters
}


$serverUrl = Read-Host 'UCCX server URL (https://myuccx.company.com)'
$credential = Get-Credential -Message 'Enter username and password'
$uccxConnector = [UccxConnector]::new($serverUrl, $credential)

# Smoke-test URL and credentials
try 
{
    $allResources = $uccxConnector.InvokeGet('/adminapi/resource')
}
catch
{
    $responseCode = $_.Exception.Response.StatusCode.value__

    if ($responseCode -eq 401) {
        Write-Error "Invalid credentials (401 Unauthorized): $_"
    } elseif ($responseCode -eq 403) {
        Write-Error "Insufficient permissions (403 Forbidden): $_"
    } else {
        Write-Error "Error when trying to connect to UCCX server: $_"
    }

    exit 1
}

# Create main export directory
$serverHost = ([System.Uri]$serverUrl).Host
$date = (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').ToString()
$exportDirectoryName = "${date}_${serverHost}"
$exportDirectory = New-Item -Name $exportDirectoryName -ItemType Directory

# Export UCCX data
$exportIsSuccessful = $true
$exportIsSuccessful = (Export-Skills -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-Resources -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-ResourceGroups -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-Csqs -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-Teams -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-CallControlGroups -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-Triggers -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-HttpsTriggers -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-Applications -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-Campaigns -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful
$exportIsSuccessful = (Export-AreaCodes -Connector $uccxConnector -ExportDirectory $exportDirectory) -and $exportIsSuccessful

# Zip & clean up
$exportDirectory | Compress-Archive -DestinationPath "${exportDirectoryName}.zip"
$exportDirectory | Remove-Item -Recurse

if ($exportIsSuccessful) {
    Write-Host "UCCX configuration export was successful (${exportDirectory})"
} else {
    Write-Error 'Ran into errors when exporting UCCX configuration'
}

# Need to flip the bool to get the proper exit code
exit !$exportIsSuccessful