#Requires -Version 7.0

class CucmConnector {
   [string] $BaseUrl
   [PSCredential] $Credential

   CucmConnector(
      [string] $BaseUrl,
      [PSCredential] $Credential
   ) {
      $this.BaseUrl = $BaseUrl
      $this.Credential = $Credential
   }

   [System.Xml.XmlDocument] ListPhone([int]$Skip, [int]$First) {
      $uri = "{0}/axl/" -f $this.BaseUrl
      $headers = @{
         'Content-Type' = 'text/xml'
         'SOAPAction'   = 'CUCM:DB ver=11.5 listPhone'
      }

      $requestBody = @"
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns="http://www.cisco.com/AXL/API/11.5">
         <soapenv:Header/>
         <soapenv:Body>
            <ns:listPhone>
               <searchCriteria>
                  <name>SEP%</name>
               </searchCriteria>
               <returnedTags>
                  <name></name>
               </returnedTags>
               <skip>${Skip}</skip>
               <first>${First}</first>
            </ns:listPhone>
         </soapenv:Body>
      </soapenv:Envelope>
"@
      
      return Invoke-RestMethod -Method 'Post' -Authentication Basic -Credential $this.Credential -Headers $headers -Uri $uri -Body $requestBody -SkipCertificateCheck
   }
   
   [System.Xml.XmlDocument] SelectCmDevice([string[]]$DeviceNames) {
      $uri = "{0}/realtimeservice2/services/RISService70" -f $this.BaseUrl
      $headers = @{
         'Content-Type' = 'text/xml; charset=UTF-8'
      }  

      $bodySelectItemsList = $deviceNames | ForEach-Object { @"
         <soap:item>
            <soap:Item>${PSItem}</soap:Item>
         </soap:item>
"@}

      $requestBody = @"
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soap="http://schemas.cisco.com/ast/soap">
         <soapenv:Header/>
         <soapenv:Body>
            <soap:selectCmDevice>
               <soap:StateInfo></soap:StateInfo>
               <soap:CmSelectionCriteria>
                  <soap:MaxReturnedDevices>2000</soap:MaxReturnedDevices>
                  <soap:DeviceClass>Phone</soap:DeviceClass>
                  <soap:Model>255</soap:Model>
                  <soap:Status>Any</soap:Status>
                  <soap:NodeName></soap:NodeName>
                  <soap:SelectBy>Name</soap:SelectBy>
                  <soap:SelectItems>
                     ${bodySelectItemsList}
                  </soap:SelectItems>
                  <soap:Protocol>Any</soap:Protocol>
                  <soap:DownloadStatus>Any</soap:DownloadStatus>
               </soap:CmSelectionCriteria>
            </soap:selectCmDevice>
         </soapenv:Body>
      </soapenv:Envelope>
"@
      
      $maxNumAttemptsForRateLimitError = 7

      for ($attempt = 1; $attempt -le $maxNumAttemptsForRateLimitError; $attempt++) {
         try {
            return Invoke-RestMethod -Method 'Post' -Authentication Basic -Credential $this.Credential -Headers $headers -Uri $uri -Body $requestBody -SkipCertificateCheck
         }
         catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            # Handle rate limit errors
            if ($PSItem.ErrorDetails.Message.Contains('Exceeded allowed rate for Rea')) {
               if ($attempt -lt $maxNumAttemptsForRateLimitError) {
                  Write-Host "Encountered rate limit error when getting device registration statuses [attempt=${attempt}]. Retrying in 10 sec..."
                  Start-Sleep -Seconds 10
                  continue
               }
               else {
                  Write-Host -ForegroundColor Red "Reached max. attempts ${maxNumAttemptsForRateLimitError} for rate limit error when getting device registration statuses"
                  throw
               }
            }

            throw
         }
      }

      throw "An unexpected error occured when getting device registration statuses"
   }
}

function Get-DeviceNames {
   param (
      [CucmConnector]$CucmConnector
   )

   $allDeviceNames = New-Object System.Collections.Generic.HashSet[string]
   $skip = 0
   $first = 2000
   $response = $CucmConnector.ListPhone($skip, $first)
   
   while (!($response.GetElementsByTagName('return').IsEmpty)) {
      $pageDeviceNames = [string[]]($response.GetElementsByTagName('return').phone.name)
      $allDeviceNames.UnionWith($pageDeviceNames)
      $skip += $first
      $response = $CucmConnector.ListPhone($skip, $first)
   }

   return $allDeviceNames
}

function Get-DeviceRegistrationStatuses {
   param (
      [string[]]$DeviceNames,
      [CucmConnector]$CucmConnector
   )

   $registrationStatuses = [System.Collections.Generic.List[object]]::new()

   $maxReturnedDevices = 2000  # The endpoint allows querying a max of 2000 devices at a time
   $windowStartIndex = 0

   while ($windowStartIndex -lt $DeviceNames.Length) {
      $progressParameters = @{
         Activity        = 'Fetching device registrations statuses...'
         Status          = "Fetched: $windowStartIndex of $($DeviceNames.Length)"
         PercentComplete = ($windowStartIndex / $DeviceNames.Length) * 100
      }

      Write-Progress @progressParameters

      $windowEndIndex = $windowStartIndex + $maxReturnedDevices
      # powershell doesn't throw an out-of-bounds error when accessing an index that is past the end of array
      $devicesToQuery = $DeviceNames[$windowStartIndex..$windowEndIndex]  
      $response = $CucmConnector.SelectCmDevice($devicesToQuery)
      $totalDevicesFound = $response.Envelope.Body.selectCmDeviceResponse.selectCmDeviceReturn.SelectCmDeviceResult.TotalDevicesFound

      if ($totalDevicesFound -gt 0) {
         $devicesPerNode = $response.Envelope.Body.selectCmDeviceResponse.selectCmDeviceReturn.SelectCmDeviceResult.CmNodes.item.CmDevices 
         | Where-Object { $_.HasChildNodes }

         foreach ($nodeDevices in $devicesPerNode) {
            $formattedDeviceStatuses = [object[]]($nodeDevices.item | Select-Object -Property Name, Status, StatusReason, TimeStamp, Model)
            $registrationStatuses.AddRange($formattedDeviceStatuses)
         }
      }

      # Upper bound of range made using the '..' operator is inclusive. so we need an additional increment
      $windowStartIndex = $windowStartIndex + $maxReturnedDevices + 1
      Start-Sleep -Seconds 1  # a pinch of throttling to help with rate limits
   }

   return $registrationStatuses
}


$serverUrl = Read-Host 'CUCM server URL (https://mycucm.company.com)'
$credential = Get-Credential -Message 'Enter username and password'

$cucmConnector = [CucmConnector]::new($serverUrl, $credential) 

try {
   $deviceNames = Get-DeviceNames -CucmConnector $cucmConnector
   Write-Host "Found $($deviceNames.Length) devices"
   $registrationStatuses = Get-DeviceRegistrationStatuses -DeviceNames $deviceNames -CucmConnector $cucmConnector
}
catch {
   $responseCode = $_.Exception.Response.StatusCode.value__

   if ($responseCode -eq 401) {
       Write-Error "Invalid credentials (401 Unauthorized): $_"
   }
   elseif ($responseCode -eq 403) {
       Write-Error "Insufficient permissions (403 Forbidden): $_"
   }
   else {
       Write-Error "Error when trying to connect to CUCM server: $_"
   }

   exit 1
}

# Export to JSON file
$serverHost = ([System.Uri]$serverUrl).Host
$date = (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').ToString()
$outputFileName = "${date}_${serverHost}"
$registrationStatuses | ConvertTo-Json -depth 100 | Set-Content -Path "${outputFileName}.json"
