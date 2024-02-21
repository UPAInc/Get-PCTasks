<#PSScriptInfo
.VERSION 1.1
.AUTHOR Eric Duncan
.COMPANYNAME University Physicians' Association (UPA) Inc.
.COPYRIGHT 2024
#>
$Script:IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem #Check if running account is system
$script:scriptname=($MyInvocation.MyCommand.Name).replace(".ps1",'') #Get the name of this script, trim removes the last s in the name.
$pc="$env:computername"
$file="..\$script.csv"

if (!($assetSerialURI)) {"Update $cfgFile"; break}
if (!($assetNameURI)) {"Update $cfgFile"; break}

##Functions##
function Trim-Length {
param (
    [parameter(Mandatory=$True,ValueFromPipeline=$True)] [string] $Str
  , [parameter(Mandatory=$True,Position=1)] [int] $Length
)
#Thank you StackOverflow! https://stackoverflow.com/questions/2336435/powershell-how-to-limit-string-to-n-characters
    $Str[0..($Length-1)] -join ""
}

function CheckWMI() {
	if (!(get-service winmgmt -ComputerName $pc | ? {$_.status -eq 'Running'})) {start-service winmgmt; sleep 5}
	}

function Web($info) {
	$pcattribs=(($info | gm -membertype NoteProperty  | select -ExpandProperty definition).replace('string ','') | convertto-json | out-string).Replace('[','').Replace(']','').Replace("`r`n",'').replace('    ','').Trim()
	#$pcattribs | out-file .\info.json -force
	#$htarray=@{"$($raw.name)"="$pcattribs"}
$body=@"
{
"$($info.name)":[$($pcattribs)]
}
"@

	#$body #Uncomment to troubleshoot.
	invoke-webrequest -method POST -uri $URI -headers $header -body $body | select statuscode
}

function get-crmid {
param(
[Parameter (Mandatory = $false)] [String]$Name,
[Parameter (Mandatory = $false)] [String]$Serial
)

	if ($serial) {
		$uri=$assetSerialURI
		$Header = @{
			"Content-Type" = "application/json"
			'Serial_Number'="$serial"
			}
		$crmID=((Invoke-WebRequest -Method POST -Uri $uri -Headers $Header).content | ConvertFrom-Json).id
		return $crmID
	}
	
	if ($Name) {
		$uri=$assetNameURI
		$Header = @{
			"Content-Type" = "application/json"
			'Name'="$name"
			}
		$crmID=((Invoke-WebRequest -Method POST -Uri $uri -Headers $Header).content | ConvertFrom-Json).id
		return $crmID
	}
}

function pcinfo() {
	#Get local user
	$user=get-WmiObject Win32_LoggedOnUser -ComputerName $pc |? {$_.Antecedent -match "utmck"}| Select Antecedent -Unique | %{"{0}\{1}" -f $_.Antecedent.ToString().Split('"')[1],$_.Antecedent.ToString().Split('"')[3]}

	#PC info
	$pcinfo=Get-WmiObject -Class Win32_ComputerSystem -ComputerName $pc
	$serial=Get-WmiObject win32_bios -ComputerName $pc | foreach Serialnumber
	$winver=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

	#CPU
	$CPUs=Get-WmiObject -class Win32_Processor -namespace root\CIMV2 -ComputerName $pc | ? {$_.deviceID -eq 'CPU0'}
	#$cores=($cpus.deviceid).count

	#Memory
	$getmemory=Get-CimInstance Win32_PhysicalMemoryArray -ComputerName $pc
	$memory=$getmemory.MaxCapacity / 1024000
	$MemSlots=$getmemory | foreach MemoryDevices

	#TPM
	$tpm=Get-WmiObject -class Win32_Tpm -namespace root\CIMV2\Security\MicrosoftTpm -ComputerName $pc | foreach SpecVersion | out-string
	if ($tpm) {$tpm=$tpm.Substring(0,3)} ELSE {$tpm="N/A"}
	
	#Networking
	$localIP=(Get-NetIPAddress -AddressFamily IPV4 | ? {$_.InterfaceAlias -NotLike "Loopback*"} | select InterfaceAlias,PrefixOrigin,IPAddress | convertto-csv -NoTypeInformation | select -skip 1).replace('"','') -join ";" | trim-length 250
	$mac=(Get-WmiObject win32_networkadapterconfiguration | ? {$_.macaddress -notlike ''} | select Description,macaddress | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";" | trim-length 250
	$PublicIP=(Invoke-WebRequest ifconfig.me/ip).Content.Trim()
	
	#Storage
	$Bitlocker=(Get-BitLockerVolume | ft MountPoint,VolumeStatus -HideTableHeaders |out-string).trim().Replace('  ','').Replace("`r`n",',').Trim(",")
	$BLPwd=(Get-BitLockerVolume -MountPoint C).KeyProtector.RecoveryPassword
	$CVol=((Get-Volume -DriveLetter C | ft -HideTableHeaders | out-string) -replace '\s+', ' ').trim()

	#Local Admins
	$Admins=(Get-LocalGroupMember -Group "Administrators" | foreach name | out-string).Replace("`r`n",',') | trim-length 1999

	#Software
	$apps1=(Get-WMIObject -computername $pc -Query "SELECT * FROM Win32_Product" | ? {$_.name -notlike '*Microsoft*'} | select name,version,installdate | sort -Property name | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";" 
	$apps2=(Get-AppxPackage | ? {$_.name -notlike '*Microsoft*'} | select name | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";"
	$apps="$apps1" + ';' + "$apps2" | trim-length 31950
	$updates1=(get-hotfix -computername $pc | select HotFixID, InstalledOn | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";"
	$updates2=(Get-WindowsPackage -Online | ? {$_.ReleaseType -eq 'Update'} | select PackageName,InstallTime | convertto-csv -NoTypeInformation | Select-Object -Skip 1).replace('"',"") -join ";"
	$updates="$updates1" + ';' + "$updates2" | trim-length 31950
	
$ht=[pscustomobject]@{
'Name'="$pc"
'Make'="$($pcinfo.Manufacturer)"
'Model'="$($pcinfo.Model)"
'Serial'="$($serial)"
'CPU Name'="$($cpus.Name)"
'CPU Description'="$($cpus.Caption)"
'CPU Cores'="$($cpus.numberofcores) Cores"
'Memory Size'="$memory GB"
'Memory Slots'="$($MemSlots) Slots"
'TPM Version'="TPM $tpm"
'Local IP'="$localIP"
'Public IP'="$publicIP"
'MAC Addresses'="$mac"
'Bitlocker'="$Bitlocker"
'BitLocker Recovery'="$BLPwd"
'Disk C'="$CVol"
'User'="$user"
'Local Admins'="$admins"
'Note'=""
'Software'="$apps"
'Updates'="$updates"
'Last Updated'="$(get-date)"
'Last'="$(get-date -Format yyyyMMdd)"
'OS'="$($winver.ProductName) $($winver.CurrentBuild).$($winver.UBR)"
} #End ht

return ,$ht
} #End hwinfo

function get-pcinfo() {
$now="$(get-date -Format yyyyMMdd)"
$newinfo=pcinfo
if (test-path $file) {$previousinfo=import-csv $file} ELSE {$previousinfo=""; $newinfo | export-csv $file -notypeinformation -Force}
$infochanged1=Compare-Object -ReferenceObject $previousinfo -DifferenceObject $newinfo -Property 'Local IP'
$infochanged2=Compare-Object -ReferenceObject $previousinfo -DifferenceObject $newinfo -Property User
$infochanged3=if ($newinfo.last -lt $now) {$true} ELSE {$false}
$newinfo
if ($infochanged1 -or $infochanged2 -or $infochanged3) {$newinfo | export-csv $file -notypeinformation -Force} ELSE {"PC info did not change"; break}


IF ($SaveToWeb) {Web -info $newinfo}
IF ($UpdateCRM) {
		#Attempts to find CRM record by Serial number then hostname if not found. If no ID returns, create a new record.
		$body=$newinfo | ConvertTo-Json #Convert inventory to web json format
		#$body | out-file .\crm.json -force
		"$($newinfo.Serial_Number)"
		$crmID=get-crmid -Serial $($newinfo.Serial_Number)
		"$crmID"
		IF (!($crmID)) {$crmID=get-crmid -Name $pc}
		IF ($crmID) {
			
			$Header = @{
				"Content-Type" = "application/json"
				'id'="$crmID"
			}
			Invoke-WebRequest -Method POST -Uri $UpdateCRMURI -Headers $Header -body $body #Update CRM record
		} ELSE {
			"No CRM ID found, creating record..."
			Invoke-WebRequest -Method POST -Uri $NewCRMURI -Headers $Header -body $body #Create new CRM record
			}
	}

}

if ($IsSystem) {
	$SaveToWeb=$True
	$UpdateCRM=$True
	get-pcinfo
}
write-host "$scriptname loaded..." -ForegroundColor yellow -BackgroundColor black