
<# Vars #>
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

$pcinfo=Get-ComputerInfo
$user=Get-CimInstance -ClassName Win32_LoggedOnUser |? {$_.Antecedent -match "$env:USERDOMAIN"}| Select Antecedent -Unique | %{"{1}\{0}" -f $_.Antecedent.ToString().Split('"')[1],$_.Antecedent.ToString().Split('"')[3]}

#Network
$pcnet=foreach ($nic in ($pcinfo.CsNetworkAdapters | where {$_.ipaddresses -ne $NULL})) {
	$netinfo=($nic | select * -ExcludeProperty IPAddresses).psobject.properties.value -join ","
	$netip=($nic | foreach ipaddresses) -join ","
	$netmac=Get-NetAdapter | ? {$_.name -eq $nic.ConnectionID} | foreach MacAddress
	$mac+="$($nic.ConnectionID) ${netmac};" | trim-length 250 -ErrorAction SilentlyContinue
	$netjoin="${netinfo},${netip};" | trim-length 250 -ErrorAction SilentlyContinue
	$netjoin
}
$PublicIP=(Invoke-WebRequest ifconfig.me/ip).Content.Trim()
if (Get-Command get-geoloc -ErrorAction SilentlyContinue) {$gep=get-geoloc}

#Hardware
$memSlots=(Get-CimInstance -ClassName Win32_PhysicalMemoryArray).MemoryDevices
$tpm=(Get-CimInstance -Namespace 'root/cimv2/Security/MicrosoftTpm' -Class 'Win32_Tpm').SpecVersion
if ($tpm) {$tpm=$tpm.Substring(0,3)} ELSE {$tpm="N/A"}
#$biostag=Get-CimInstance -ClassName Win32_SystemEnclosure | Select-Object -ExpandProperty SMBIOSAssetTag
$biostag=(Get-CimInstance -ClassName Win32_SystemEnclosure | foreach SMBIOSAssetTag ).trim()
if (!($biostag)) {$biostag="N/A"}

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
'BIOS Tag'="$($biostag)"
'CPU Name'="$(($pcinfo.CsProcessors[0]).name)"
'CPU Description'="$(($pcinfo.CsProcessors[0]).description)"
'CPU Cores'="$($pcinfo.CsNumberOfProcessors) Cores"
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

invoke-webrequest -method POST -uri $FlowUri -headers $header -body $body

