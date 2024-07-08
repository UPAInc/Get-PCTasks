<#PSScriptInfo
.VERSION 1.4
.AUTHOR Eric Duncan
.COMPANYNAME University Physicians' Association (UPA) Inc.
.COPYRIGHT 2024
#>

<# Vars #>
$Script:IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem #Check if running account is system
$script:scriptname=($MyInvocation.MyCommand.Name).replace(".ps1",'')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-CoordByIP() {
# Define the API endpoint
$url = "http://ipinfo.io/json"

# Make the web request
$response = Invoke-RestMethod -Uri $url

if ($response.loc) {
# Extract location data
$location = $response.loc -split ","
$latitude = $location[0]
$longitude = $location[1]

# Display the location data
Write-Output "Lat: $latitude Long: $longitude $($response.city) $($response.region) $($response.country)"
}
}

function Get-CoordByGPS() {
#https://stackoverflow.com/questions/46287792/powershell-getting-gps-coordinates-in-windows-10-using-windows-location-api
Add-Type -AssemblyName System.Device #Required to access System.Device.Location namespace
$GeoWatcher = New-Object System.Device.Location.GeoCoordinateWatcher #Create the required object
$GeoWatcher.Start() #Begin resolving current locaton

while (($GeoWatcher.Status -ne 'Ready') -and ($GeoWatcher.Permission -ne 'Denied')) {
    Start-Sleep -Milliseconds 100 #Wait for discovery.
}  

if ($GeoWatcher.Permission -eq 'Denied'){
    Write-Error 'Access Denied for Location Information'
} else {
    $GeoWatcher.Position.Location | Select Latitude,Longitude #Select the relevent results.
}
}

function get-citystate ($lat,$long) {
# Define your OpenCage API key
$apiKey = "c6bfe1d5b7a74b30aea1e4621c515863"

# Input latitude and longitude coordinates
$latitude = "$lat"
$longitude = "$long"

# Define the API endpoint with the coordinates and API key
$endpoint = "https://api.opencagedata.com/geocode/v1/json?q=$latitude+$longitude&key=$apiKey"

# Make the web request
if ($lat -and $long) {
	$response = Invoke-RestMethod -Uri $endpoint
	# Check if the response contains results
	if ($response.status.code -eq 200) {
   	 # Extract the components
    	$components = $response.results[0].components

    	# Initialize variables to store city and state
    	if ($components.city) {$city = $components.city} ELSE {$city = $components._normalized_city}
	    # Display the city and state
	Write-Output "Find my Device: ${findmy}; Lat: $lat Long: ${long}; $($components.house_number) $($components.road), $($city) $($components.state) $($components.postcode) $($components.country) $($components.continent)"
		} else {Write-Output "Find my Device: ${findmy}; Failed. Status: $($response.status.message)"
	}

} else {Write-Output "Find my Device: ${findmy}; No coordinates"}
}

<# Main #>
$findmy=get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -name "Value" -ErrorAction SilentlyContinue | foreach value
$ifsvc=Get-Service lfsvc | foreach status

if (!($findmy)) {
Remove-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\lfsvc\TriggerInfo\" -Name "3" -ErrorAction SilentlyContinue

New-Item -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -name "Value" -value 1 -Type string -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -name "LocationSyncEnabled" -value 1 -type dword -force

set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Value "Allow" -Name "Value"
set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\activity" -Value "Allow" -Name "Value"

set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Components\General\Settings" -name "EnableActiveCollection" -value "1"

set-ItemProperty -Path "HKLM:\\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -name "DisableLocation" -value "0"
set-ItemProperty -Path "HKCU:\\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -name "DisableLocation" -value "0"
set-ItemProperty -Path "HKLM:\\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -name "DisableLocationScripting" -value "0"
set-ItemProperty -Path "HKLM:\\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -name "DisableWindowsLocationProvider" -value "0"

# Restart the Location service
Restart-Service -Name lfsvc -Force

# Notify the system of the changes
Get-Service lfsvc | Start-Service

$findmy="Set to Enabled"
} else {$findmy="Enabled"}

if ($ifsvc -ne "Running") {
Set-Service -Name "lfsvc" -StartupType Automatic
Start-Service -Name lfsvc
}

function get-geoloc(){
$gps=Get-CoordByGPS
if ($gps) {
get-citystate -lat $gps.Latitude -long $gps.Longitude
} else {Get-CoordByIP}
}

#get-geoloc

write-host "$scriptname loaded..." -ForegroundColor yellow -BackgroundColor black