<#PSScriptInfo
.VERSION 2.0.2
.AUTHOR Eric Duncan
.COMPANYNAME University Physicians' Association (UPA) Inc.
.COPYRIGHT 2024
#>

<# Vars #>
#Temp var for migration
$FlowUri="https://flow.zoho.com/856508634/flow/webhook/incoming?zapikey=1001.52f88f3f448f5ea9373e8cc92f2cbee7.3e9d7aad966a7f5856075426e28dc125&isdebug=false"
$pcinfofile=".\pcinfo.csv"
$Script:IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem #Check if running account is system
$script:scriptname=($MyInvocation.MyCommand.Name).replace(".ps1",'') #Get the name of this script, trim removes the last s in the name.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Header = @{
	"Content-Type" = "application/json"
}

<# Functions #>

function Trim-Length {
param (
    [parameter(Mandatory=$True,ValueFromPipeline=$True)] [string] $Str
  , [parameter(Mandatory=$True,Position=1)] [int] $Length
)
#Thank you StackOverflow! https://stackoverflow.com/questions/2336435/powershell-how-to-limit-string-to-n-characters
    $Str[0..($Length-1)] -join ""
}

<# Main #>
function get-pcinfo() {
$pcinfo=Get-ComputerInfo
$user=Get-CimInstance -ClassName Win32_LoggedOnUser |? {$_.Antecedent -match "$env:USERDOMAIN"}| Select Antecedent -Unique | %{"{1}\{0}" -f $_.Antecedent.ToString().Split('"')[1],$_.Antecedent.ToString().Split('"')[3]}

#Network
$pcnet=foreach ($nic in ($pcinfo.CsNetworkAdapters | where {$_.ipaddresses -ne $NULL})) {
	$netinfo=($nic | select * -ExcludeProperty IPAddresses).psobject.properties.value -join ","
	$netip=($nic | foreach ipaddresses)[0] -join ","
	$netmac=Get-NetAdapter | ? {$_.name -eq $nic.ConnectionID} | foreach MacAddress
	$mac+="$($nic.ConnectionID) ${netmac};" 
	$netjoin+="${netinfo},${netip};"
	$netjoin
}
$pcnet=$pcnet | trim-length 254 -ErrorAction SilentlyContinue
$PublicIP=(Invoke-WebRequest ifconfig.me/ip).Content.Trim()
#$findmy=get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice" -name "Value" | foreach value
#$findmy=if ($findmy -eq "1") {"Enabled"} else {"Disabled"}
if (Get-Command get-geoloc -ErrorAction SilentlyContinue) {$geo=get-geoloc} else {import-module .\get-geoloc.ps1; $geo=get-geoloc}
#$geo="Find My Device: ${findmy};" + "$geo"

#Hardware
$memSlots=(Get-CimInstance -ClassName Win32_PhysicalMemoryArray).MemoryDevices
$tpm=(Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -Class 'Win32_Tpm').SpecVersion
if ($tpm) {$tpm=$tpm.Substring(0,3)} ELSE {$tpm="N/A"}
$biostag=(Get-CimInstance -ClassName Win32_SystemEnclosure | foreach SMBIOSAssetTag ).trim()
if (!($biostag)) {$biostag="NA"}

#Storage
$Bitlocker=(Get-BitLockerVolume | ft MountPoint,VolumeStatus -HideTableHeaders |out-string).trim().Replace('  ','').Replace("`r`n",',').Trim(",")
$BLPwd=(Get-BitLockerVolume -MountPoint C).KeyProtector.RecoveryPassword
$CVol=((Get-Volume -DriveLetter C | ft -HideTableHeaders | out-string) -replace '\s+', ' ').trim().replace(' ',',')

#Local Admins
$Admins=(Get-LocalGroupMember -Group "Administrators" | foreach name | out-string).Replace("`r`n",',') | trim-length 1999

#Software
$registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
foreach ($path in $registryPaths) {$applist+=@(Get-ItemProperty -Path $path | ? {$_.publisher -notlike '*Microsoft*'} | Select-Object DisplayName, DisplayVersion, InstallDate)}
$apps1=($applist | ? {$_.DisplayName -ne $NULL} | Sort-Object -Property DisplayName | Out-String -Stream ).trim().replace('  ','') -join ","
$apps2=(Get-AppxPackage | ? {$_.publisher -notlike '*Microsoft*'} | select name | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";"
$apps="$apps1" + ';' + "$apps2" | trim-length 31950
$updates1=(get-hotfix | select HotFixID, InstalledOn | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";"
$updates2=(Get-WindowsPackage -Online | ? {$_.ReleaseType -eq 'Update'} | select PackageName,InstallTime | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";"
$updates="$updates1" + ';' + "$updates2" | trim-length 31950

$ht=[pscustomobject]@{
'Name'="$($pcinfo.csname)"
'Make'="$($pcinfo.CsManufacturer)"
'Model'="$($pcinfo.CSModel)"
'Serial'="$($pcinfo.BiosSeralNumber)"
'BIOS Tag'="$biostag"
'CPU Name'="$(($pcinfo.CsProcessors[0]).name)"
'CPU Description'="$(($pcinfo.CsProcessors[0]).description)"
'CPU Cores'="$($pcinfo[0].CsProcessors.NumberOfCores) Cores"
'Memory Size'="$([int32]($pcinfo.OsTotalVisibleMemorySize / 1000000)) GB"
'Memory Slots'="$($MemSlots) Slots"
'TPM Version'="$tpm"
'Local IP'="$($pcnet)"
'Public IP'="$publicIP"
'MAC Addresses'="$($mac)"
'Bitlocker'="$Bitlocker"
'BitLocker Recovery'="$BLPwd"
'Disk C'="$CVol"
'User'="$user"
'Local Admins'="$admins"
'Note'="$($pcinfo.CsPCSystemType) Computer BIOS Version: $($pcinfo.BiosBIOSVersion)"
'Software'="$apps"
'Updates'="$updates"
'Last Updated'="$(get-date)"
'Last'="$(get-date -Format yyyyMMdd)"
'OS'="$($pcinfo.OsName) $($pcinfo.OSDisplayVersion) $($pcinfo.OsArchitecture)"
'Geo'="$geo"
} #End ht

#$ht
$body=$ht | convertto-json
#$body

$now="$(get-date -Format yyyyMMdd)"
$newinfo=$ht
if (test-path $pcinfofile) {$previousinfo=import-csv $pcinfofile} ELSE {$previousinfo=""; $newinfo | export-csv $pcinfofile -notypeinformation -Force}
$infochanged1=Compare-Object -ReferenceObject $previousinfo -DifferenceObject $newinfo -Property 'Local IP'
$infochanged2=Compare-Object -ReferenceObject $previousinfo -DifferenceObject $newinfo -Property User
$infochanged3=if ($newinfo.last -lt $now) {$true} ELSE {$false}
"Checking for pc info changes..."
$infochanged1
$infochanged2
$infochanged3

if ($infochanged1 -or $infochanged2 -or $infochanged3) {
	$newinfo | export-csv $pcinfofile -notypeinformation -Force
	invoke-webrequest -method POST -uri $FlowUri -headers $header -body $body | select StatusCode
	} ELSE {"PC info did not change"}

}

write-host "$scriptname loaded..." -ForegroundColor yellow -BackgroundColor black
