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
   	 Write-Output "Lat: $lat Long: $long - $($components.house_number) $($components.road), $($city) ($($components.hamlet)) $($components.state) $($components.postcode) $($components.country) $($components.continent)"
		} else {Write-Output "Failed. Status: $($response.status.message)"
	}

} else {Write-Output "No coordinates"}
}

<# Main #>
$findmy=get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -name "Value" | foreach value
$ifsvc=Get-Service lfsvc | foreach status

if (!($findmy)) {
Remove-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Services\lfsvc\TriggerInfo\" -Name "3"

set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -name "LocationSyncEnabled" -value 1
set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -name "Value" -value 1

set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Value "Allow" -Name "Value"
set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\activity" -Value "Allow" -Name "Value"

set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Components\General\Settings" -name "EnableActiveCollection" -value "1"

set-ItemProperty -Path "HKLM:\\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -name "DisableLocation" -value "1"
set-ItemProperty -Path "HKCU:\\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -name "DisableLocation" -value "1"

# Restart the Location service
Restart-Service -Name lfsvc -Force

# Notify the system of the changes
Get-Service lfsvc | Start-Service
}

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

get-geoloc