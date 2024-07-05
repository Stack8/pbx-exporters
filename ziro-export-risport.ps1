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
                  <model></model>
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

      $bodySelectItemsList = $DeviceNames | ForEach-Object { @"
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

      throw "An unexpected error occurred when getting device registration statuses"
   }
}

function Get-Devices {
   param (
      [CucmConnector]$CucmConnector
   )

   $allDevices = New-Object System.Collections.Generic.List[object]
   $skip = 0
   $first = 2000
   $response = $CucmConnector.ListPhone($skip, $first)
   
   while (!($response.GetElementsByTagName('return').IsEmpty)) {
      $pageDevices = [object[]]($response.GetElementsByTagName('return').phone)
      $allDevices.AddRange($pageDevices)
      $skip += $first
      $response = $CucmConnector.ListPhone($skip, $first)
   }

   return $allDevices
}

function Get-DeviceRegistrationStatuses {
   param (
      [string[]]$DeviceNames,
      [CucmConnector]$CucmConnector
   )

   $registrationStatuses = @{}
   $maxReturnedDevices = 2000  # The endpoint allows querying a max of 2000 devices at a time
   $windowStartIndex = 0

   while ($windowStartIndex -lt $DeviceNames.Length) {
      $progressParameters = @{
         Activity        = 'Fetching device registrations statuses...'
         Status          = "Fetched: $windowStartIndex of $($DeviceNames.Length)"
         PercentComplete = ($windowStartIndex / $DeviceNames.Length) * 100
      }

      Write-Progress @progressParameters

      $windowEndIndex = $windowStartIndex + $maxReturnedDevices - 1
      # powershell doesn't throw an out-of-bounds error when accessing an index that is past the end of array
      $devicesToQuery = $DeviceNames[$windowStartIndex..$windowEndIndex]  # upper bound is inclusive
      $response = $CucmConnector.SelectCmDevice($devicesToQuery)
      $totalDevicesFound = $response.Envelope.Body.selectCmDeviceResponse.selectCmDeviceReturn.SelectCmDeviceResult.TotalDevicesFound

      if ($totalDevicesFound -gt 0) {
         $devicesPerNode = $response.Envelope.Body.selectCmDeviceResponse.selectCmDeviceReturn.SelectCmDeviceResult.CmNodes.item.CmDevices 
         | Where-Object { $_.HasChildNodes }

         foreach ($nodeDevices in $devicesPerNode) {
            $nodeDevices.item | Select-Object -Property Name, Status, StatusReason, TimeStamp 
            | ForEach-Object { $registrationStatuses.Add($_.Name, $_) }
         }
      }

      $windowStartIndex = $windowStartIndex + $maxReturnedDevices
      Start-Sleep -Seconds 1  # a pinch of throttling to help with rate limits
   }

   return $registrationStatuses
}


$serverUrl = Read-Host 'CUCM server URL (https://mycucm.company.com)'
$credential = Get-Credential -Message 'Enter username and password'
$cucmConnector = [CucmConnector]::new($serverUrl, $credential) 

try {
   Write-Host "Fetching devices from CUCM server..."
   $devices = Get-Devices -CucmConnector $cucmConnector
   Write-Host "Found [$($devices.Length)] devices"
   Write-Host "Getting device registration statuses..."
   $registrationStatuses = Get-DeviceRegistrationStatuses -DeviceNames $devices.name -CucmConnector $cucmConnector
   $registrationStatuses
   $registrationStatuses
   $exportResults = New-Object System.Collections.Generic.List[Hashtable]

   foreach ($device in $devices) {
      if ($registrationStatuses.ContainsKey($device.name)) {
         $matchingStatus = $registrationStatuses[$device.name]
         $exportResults.Add(@{
               Name         = $device.name
               Status       = $matchingStatus.Status
               StatusReason = $matchingStatus.StatusReason
               TimeStamp    = $matchingStatus.TimeStamp
               Model        = $device.model
            })
      }
      else {
         $exportResults.Add(@{
               Name         = $device.name
               Status       = "Unknown"
               StatusReason = ""
               TimeStamp    = ""
               Model        = $device.model
            })
      }
   }

   # Export to JSON file
   $serverHost = ([System.Uri]$serverUrl).Host
   $date = (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').ToString()
   $outputFileName = "${date}_${serverHost}.json"
   $outputFile = $exportResults | ConvertTo-Json -depth 100 -AsArray | New-Item -Path . -Name $outputFileName -ItemType File
   Write-Host "RISport information export was successful: $outputFile"
   exit 0
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
      Write-Error "Ran into errors when exporting RISport information: $_"
   }

   Write-Error "RISport information export failed"
   exit 1
}
