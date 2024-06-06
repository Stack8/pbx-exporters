# Display logged in user and provide option to use different credentials
$loggedInUser = $Env:UserName
$userName = Read-Host "Running as [$Env:UserName]. Provide a different username or hit ENTER to continue as [$Env:UserName]"

if ($userName) {
    $password = Read-Host -AsSecureString -Prompt ('Password for [' + $userName + ']')
    $creds = New-Object System.Management.Automation.PSCredential ($userName, $password)
}

$defaultHostname = Get-ADDomainController | Select-Object HostName
$defaultHostname = $defaultHostname.hostname

# Provide option to point to a different AD host 
$hostname = Read-Host "[OPTIONAL] Hit Enter to query AD Host [$defaultHostname] or provide a different hostname"

# Prompt for optional AD filter
$filter = Read-Host "[OPTIONAL] Provide a filter, (hit enter to skip)"

# Prompt for optional Search Base
$searchBase = Read-Host -Prompt '[OPTIONAL] Provide Search Base (ex. DC=contoso,DC=com), hit enter to skip'

# Prompt for additional properties to add to CSV that could be relevant to the migration
$additionalProperties = Read-Host -Prompt "[OPTIONAL] Provide Comma Seperated list of additional attributes to export (by default, it will extract SamAccountName', 'UserPrincipalName','LastLogonDate', 'ipPhone', 'telephoneNumber', 'ObjectCategory')"

	
# build default set of properties
$propertiesToReturn = New-Object -TypeName System.Collections.ArrayList
$propertiesToReturn.AddRange(@('SamAccountName', 'UserPrincipalName', 'LastLogonDate', 'ipPhone', 'telephoneNumber', 'ObjectCategory'))

# add additional properties if provided
if ($additionalProperties) {
    $propertiesToReturn.AddRange($additionalProperties.Split(","))
}


# setup defaults
$params = @{
    Properties = $propertiesToReturn
    Filter     = "*"
}

# change filter, if provided
if ($filter) {
    $params["Filter"] = $filter
}  

# add optional creds if provided
if ($creds) {
    $params["Credential"] = $creds
    $params["filter"] = "*"
}

#add optional hostname if provided
if ($hostname) {
    $params["Server"] = $hostname
}

# add optional searchBase if provided
if ($searchBase) {
    $params["searchBase"] = $searchBase
}

# Run the export and dumpt it to ziro-ad-export.csv
Get-ADUser @params |  Select-Object $propertiesToReturn | Export-csv ziro-ad-export.csv -NoTypeInformation

# Open it
Invoke-Item "ziro-ad-export.csv"
