<#PSScriptInfo
.VERSION 1.4
.GUID 7834b86b-9448-46d0-8574-9296a70b1b98
.AUTHOR Eric Duncan
.COMPANYNAME University Physicians' Association (UPA) Inc.
.COPYRIGHT 2023
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>

.TAGS

.LICENSEURI http://unlicense.org

.PROJECTURI https://github.com/UPAInc/Get-PCTasks

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
	20230501 - 1.0
		Init release.
	202305011625 - 1.3
		Minor updates.

#>

<#
.SYNOPSIS
 A remote admin script that runs as a scheduled.

.DESCRIPTION
Remotely control or set paramaters for a PC using a REST API http service.

.PARAMETER CnCURI
Specify remote http server to receive commands from.

.INPUTS
 None. You cannot pipe objects to this script.
 
.OUTPUTS
 Defaults to log file.

.EXAMPLE
PS> .\get-pctasks.ps1 -CnCURI https://xxx
#>
param ($CnCURI,$task,$run,$params,$args)


<# VARIABLES #>
if (!($CnCURI)) {$CnCURI="https://eoj5o3nkdop6ami.m.pipedream.net"} #Override commandline switch
$GitURI="https://github.com/UPAInc/Get-PCTasks"

<# SCRIPT VARIABLES #>
$script=($MyInvocation.MyCommand.Name).replace(".ps1",'') #Get the name of this script, trim removes the last s in the name.
$BaseDir="$env:programdata\UPA"
$ScriptDir="$BaseDir\$script"
$BinDir="$ScriptDir\bin"
$TempDir="$ScriptDir\Temp"
$LogDir="$ScriptDir\Log"
$log="$LogDir\$script"+".log"
$TaskDir="$ScriptDir\task"
$filenameDate=get-date -Format yyyyMMddmmss
$runbook="$TaskDir\$filenameDate.task" #name cannot change per instance
$head = @{
	'Content-Type'='application/json'
	'name'="$($env:computername.ToUpper())"
	}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #TLS fix for older PS

<# Script Logging #>
if (!(test-path $LogDir)) {mkdir $LogDir}
try {Stop-Transcript | Out-Null} catch {} #fix log when script is prematurely stopped
Start-Transcript $log -force

<# FUNCTIONS #>
function SCREENGRAB($alt,$time) {
	$vid="$TempDir\$env:computername-$(get-date -Format yyyyMMddmmss).mkv" #video filename
	if (!($time)) {$time="00:01:00"} #default time to capture screen
	if (!(winget show ffmpeg)) {winget install ffmpeg --scope machine --accept-package-agreements --disable-interactivity} #install ffmpeg via winget
	$ffmpeg="$(Get-ChildItem -Recurse "C:\Program Files\WinGet\Packages" | ? {$_.name -eq "ffmpeg.exe"} | % fullname)" #set ffmpeg exe
	if (!(test-path $ffmpeg)) {$ffmpeg = "$BinDir\ffmpeg.exe"} #set backup ffmpeg exe if needed
	if ($alt) {& $ffmpeg -filter_complex ddagrab=0,hwdownload,format=bgra -c:v libx264 -crf 40 -preset medium -tune stillimage -t $time $vid}
		ELSE {& $ffmpeg -f gdigrab -framerate 25 -i desktop -t $time -c:v libx264 -preset medium -crf 40 -tune stillimage $vid}
}

function DENYUSER($user) {
	& $BinDir\ntrights.exe +r SeDenyInteractiveLogonRight -u "$user"
	}
	
function DISABLEAD($mode) {
	$path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
	$name="CachedLogonsCount"
	
	function updatereg() {
		IF (test-path $path) {
		"Set and check reg value"
		set-itemproperty -path $path -name $name -value $value
		Get-ItemProperty -Path $path | foreach $name
		} ELSE {
		"Make key"
		New-Item -Path "$path" -force
		New-ItemProperty -Path "$path" -PropertyType 'String' -Name $name -Value $value
		Get-ItemProperty -Path $path | foreach $name
		}
	}
	
	switch($mode) {
		enable {$value="0" ; updatereg}
		disable {$value="10" ; updatereg}
	}
	
}

function RUN($type,$run,$options) {
	<#
	Examples:
	RUN -type cmd -run dir -options c:\users
	RUN -type pshell -run dir -options c:\users
	RUN -type process c:\myapp.exe -options silent
	#>
	
	#Hashtable for start-process
	$syntax=@{
		NoNewWindow=$true
		wait=$true
		}
	
	#Add arguments to hashtable depending on command
	if ($type -eq 'cmd') {
		$cmdarg=@("/c", "$run", "$options")
		$syntax.add('ArgumentList',"$cmdarg")
		$syntax.add('FilePath','C:\Windows\System32\cmd.exe')
		} ELSE {
			$cmdarg=@("$run", "$options")
			$syntax.add('ArgumentList',"$cmdarg")
			$syntax.add('FilePath',"$run")
			}
	
	#Execute based on type
	switch ($type) {
		pshell {$both="$run $options"; Invoke-Expression -Command $both}
		process {start-process @syntax}
		cmd {start-process @syntax}
	}
	
} #End Rund

function UPDATE() {}

function DOWNLOAD($type,$url,$file) {
	switch ($type) {
		bits {
			Import-Module BitsTransfer
			Start-BitsTransfer -Source $url -Destination $path_to_file
		}
		default {Invoke-WebRequest $url -OutFile $file}
	}
}

function LOCKDESKTOP() {
	& $ENV:windir\System32\Rundll32.exe user32.dll,LockWorkStation
	}

function ECHOTEST($stuff) {
	write-host "You sent the command $($line.name) $stuff"
}

function NETWORK($action) {
	#Disable all network adapters.
	switch ($action) {
		disable {Get-NetAdapter | Disable-NetAdapter -Confirm:$false}
		enable {Get-NetAdapter | Enable-NetAdapter -Confirm:$false}
	}
}

function Install-Update() {
	#Install Git and script.
	if (!(winget show git.git)) {winget install git.git --scope machine --accept-package-agreements --disable-interactivity} #install git via winget
	if (!(test-path $scriptDir)) {git clone $GitURI $scriptDir} ELSE {Set-Location $scriptDir; git pull}
}

function schtask($URL) {
	#Create a scheduled task to run script.
	#Default is daily in 30 minute increments.
	$querytask=& $env:windir\system32\schtasks.exe /query /tn $script
	IF ($querytask) {
		#Make sure the task is enabled.
		& $env:windir\system32\schtasks.exe /change /enable /TN $script
	} ELSE {
	& $env:windir\system32\schtasks.exe /s "localhost" /ru "SYSTEM" /Create /SC "DAILY" /RI 15 /ST 08:00 /TN "$script" /TR "powershell.exe -file $scriptDir\$script.ps1 -CnCURI $CnCURI" /RL HIGHEST /HRESULT
	}
}

function WindowsUpdate() {
	$module = "PSWindowsUpdate"
	$WU = "Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreUserInput -AutoReboot -verbose *>&1 | Out-File $LogDir\PSWindowsUpdate.log"
	if (Get-Module -ListAvailable | ? {$_.name -match $module}) {& $WU	} ELSE 
	{
		#Check
		Unregister-PSRepository -Name PSGallery
		sleep 2
		Register-PSRepository -Default -InstallationPolicy trusted
		sleep 2
		Install-Module -Name PackageManagement
		Install-Module -Name PowerShellGet
		Install-Module -Name PSWindowsUpdate
		Install-PackageProvider -Name NuGet
		Install-Module $module -force
		& $WU
	}
}

function CheckWebTasks() {
	if (!(test-path $TaskDir)) {mkdir  $TaskDir}
	#Check for published tasks
	$WebCommand=(Invoke-WebRequest -Method POST -Headers $head -URI $CnCURI).content

	#Check for JSON format
	if ($WebCommand -match '{"') {
		$CmdList0=($WebCommand | convertfrom-json).psobject.properties | select name,value 
		foreach ($line in $CmdList0) {$CmdList=$line.name, $line.value }
		$CmdList=$CmdList.split(';')
		} ELSE {
			#Non-JSON
			$CmdList=$WebCommand.split(';')
			}

	#Create task runbook
	
	$CmdList | out-file $runbook
	$hash=(Get-FileHash -Algorithm sha1 $runbook).hash
	return $hash
}

function RunTask() {
	switch ($function) {
		ECHOTEST {& $function $CmdList}
		LOCKDESKTOP {& $function}
		DOWNLOAD {& $function $action $options}
		RUN {& $function $action $options}
		DISABLEAD {& $function $action}
		schtask {& $function -url $options}
		NETWORK {& $function $action}
		SCREENGRAB {& $function $action $options}
	}
}

<# MAIN #>

#Run functions in this order
Install-Update

#Check dirs in case install fails
if (!(test-path $TempDir)) {mkdir $TempDir}
if (!(test-path $BinDir)) {mkdir $BinDir}

#Check for scheduled task, enable or create.
schtask -url $CnCURI

#Gets tasks for this PC and returns hash of current task for file comparison
$WebTask=CheckWebTasks

#Get tasks saved on disk
$tasks=@()
$taskbooks=get-childitem $TaskDir\*.task | % fullname
if ($taskbooks) {
	foreach ($file in $taskbooks) {
		$hash1=(Get-FileHash -Algorithm sha1 $file).hash
		if ($WebTask -eq $hash1 -AND $file -ne $runbook) {remove-item $file; "Dup hash found, deleting $file"} ELSE {
			$tasks+=$file
		}
	}
} ELSE {remove-variable tasks}

if ($tasks) {
	foreach ($task in $tasks) {
		
		$time=get-date -Format yyyyMMddHHmm
		$CmdList=gc $task
		
		#Parse
		if ($CmdList[0]) {$function=$CmdList[0]}
		if ($CmdList[1]) {$action=$CmdList[1]}
		if ($CmdList[2]) {$options=$CmdList[2]}
		if ($CmdList[3]) {$start=$($CmdList[3]) | get-date -Format yyyyMMddHHmm}
		if ($CmdList[4]) {$end=$($CmdList[4]) | get-date -Format yyyyMMddHHmm}
		
		#Execution decision tree
		if ($time -gt $end) {rm $task -force; "Deleting expired tasks: $task"}
		if ($time -gt $start -AND $time -lt $end) {RunTask; "Start date and end date matched: $task"}
		elseif (!($start)) {RunTask; "No starting date"}
		#elseif ($CmdList[3] -ge $date ) {RunTask; "Start date matched"}
		remove-variable CmdList, time
	}
}

<# Post Main Items #>
Stop-Transcript
