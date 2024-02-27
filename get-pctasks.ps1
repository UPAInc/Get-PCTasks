<#PSScriptInfo
.VERSION 2.8.4
.GUID 7834b86b-9448-46d0-8574-9296a70b1b98
.AUTHOR Eric Duncan
.COMPANYNAME University Physicians' Association (UPA) Inc.
.COPYRIGHT 2024
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
	202305011700 - 1.4
		Parse was running on a null var.
	202305020924 - 1.5
		Added Install-WinGet function.Thank you, Romain!
		1.5.1 - Replaced Add-AppxProvisionedPackage with DISM for all users.
		1.5.2 - tweaked install, set alias to system winget.
		1.5.3 - Updated screengrab function.
		1.5.4 - Added screenshot function.
		1.5.5 -	Added -local option for local execution. Defaults to 60 seconds execution time.
		1.5.6 -	Updated script info/help.
		1.5.7 - winget was prompting on a query stopping the script.
		1.5.8 - Added $freq / frequency option to screenshot.
				Install-Module will place a copy of ffmpeg from Winget dir to local bin.
				Screengrab is broken under the "system" user; it doesn't see the desktop. Might run it as a different task.
				Added a check/set for user permission to the .\temp and task folder.
				Added a second task imported from temp xml file. This runs as current user for screengrab.
				Screen grab now looks at local user and if system, start the task "Assist". If it is not system, it will run screengrab.
		1.5.9 - Changed $env:username to whoami. Was showing pc name.
	202305040930 - 1.6
		Installing BurntToast for simple notifications.
		Added IPv4 Addresses to script for logging.
		Added sending log to results web server.
		Changed scheduled task to import a file instead of cmd line.
	202305050931 - 1.6.1
		Task sched name error, added tn option to import xml.
		Updated params format.
		Added param for remote file server, checks if its alive.
		Started function to upload temp items (incomplete).
		1.6.2 - Added reboot option to DISABLEAD function.
		1.6.3 - Added power function to remote reboot or power off.
		1.6.4 - Set the log upload not to run when local is called.
				Updated the RunTasks to correctly call specific parameters.
				WindowsUpdate wasn't loading the module.
		1.6.5 - Added lock desktop to denyuser
				Added false option to undo the user deny.
	202305081131 - 1.6.6
		Added IE fix.
		Moved new array tasks under next if statement.
	202305151600 - 2.0
		Moved functions to their own file and folder in .\functions.
		Added path for FS share and SendTemp function runs each time.
		Cleaned up minor bugs and variable updates.
	202402091032 - 2.5
		Major overhaul of script.
		Moved config vars to external cfg.json file.
		Add self install.
		Added WinNuke to erase PC.
	202402151150 - 2.6
		Added more default paramaters.
		With issues with winget, added choco install when cfg is missing.
		Updated many of the functions.
		Added Cancel in CheckWebTasks to delete all tasks.
		Added enable winrm.
	202402151328 - 2.6.2
		Updated install detect path.
		Added pause for cfg file on install and look for cfg in temp.
		Added install BurntToast function for notifications.
	202402151713 - 2.6.3
		Disabled winget install.
		Fixed screenshot running as user.
		Added RunAsUser.
		Fixed task schedules.
		Enabled git pull.
	202402160948 - 2.6.4
		Testing new results upload.
		Sectioned things to only run as system user.
		Added admin check to script install.
		Added WPF notifications to notify function.
	202402161135 - 2.6.5
		Added IsSystem check when creating tasks and deleting.
	202402191015 - 2.7
		Added get-pwdfyi function, added to run with each script Run
		Added param to call a task from RunTask
		Added checks to CheckWebTasks to stop processing empty vars
	202402191054 - 2.7.1
		Updated log vars to capture user-level logging.
  	202402211320 - 2.8
		Added pc inventory function, enabled for each run.
  	202402211400 - 2.8.1
   		Copy cfg from local fs if avil.
		
	TODO:
		Add http upload function for screen grab/shots.
		Add combo function.
		Backup browser history file.
		Add action to WinNuke for safety.
		Clean up Get-PCTasks-results.
		
		
		
#>
<#
.SYNOPSIS
 A remote admin script that runs as a scheduled.

.DESCRIPTION
Remotely control or set paramaters for a PC using a REST API http service. Commands are returned in a semicolon delimited format: function;action;paramaters;start time;end time.
If winget doesn't work, place executable files such as ffmpeg in .\bin.

.PARAMETER CnCURI
Specify remote http server to receive commands from.

.PARAMETER local
Set -local $true to run from commandline. Use with -function <function name>.

.PARAMETER function
Specify the task/function name to run locally. Example: -function SCREENSHOT

.PARAMETER action
Optional paramater to modify function.

.PARAMETER options
Optional paramater to modify function and action.

.PARAMETER cfgFile
Specify the configuration file. Default file is cfg.json.

.INPUTS
 None. You cannot pipe objects to this script.
 
.OUTPUTS
 Defaults to log file.

.EXAMPLE
PS> .\get-pctasks.ps1 -CnCURI https://xxx
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $False)] [String] $GitURI = "https://github.com/UPAInc/Get-PCTasks.git",
	[Parameter(Mandatory = $False)] [String] $GitBranch = "main",
	[Parameter(Mandatory = $False)] [String] $CnCURI, 
	[Parameter(Mandatory = $False)] [String] $ResultsURI,
	[Parameter(Mandatory = $False)] [String] $RemoteFS,
	[Parameter(Mandatory = $False)] [String] $RemoteFSShare,
	[Parameter(Mandatory = $False)] [Switch] $local = $false,
	[Parameter(Mandatory = $False)] [String] $function,
	[Parameter(Mandatory = $False)] [String] $action,
	[Parameter(Mandatory = $False)] [String] $options,
	[Parameter(Mandatory = $False)] [String] $cfgFile = ".\cfg.json",
	[Parameter(Mandatory = $False)] [String] $Org = "UPA",
	[Parameter(Mandatory = $False)] [int64] $start = "$(get-date -Format yyyyMMddHHmm)",
	[Parameter(Mandatory = $False)] [int64] $end = "$((get-date).AddMinutes(30) | get-date -Format yyyyMMddHHmm)"
)

#Change PS execution
Set-ExecutionPolicy Bypass -Scope Process -Force

<# Load Config/VARIABLES #>
if (test-path $cfgFile)
	{
		$cfgIn=get-content $cfgFile -raw | convertfrom-json -ErrorAction Stop
		$cfg=@{}
		foreach ($setting in $cfgIn.PSObject.Properties)
			{
				$value=$setting.Value
				if ($value -is [System.Management.Automation.PSCustomObject]) {
					$value = ConvertTo-Hashtable -Object $value
					} elseif ($value -is [System.Array]) {
						$value = $value | ForEach-Object { ConvertTo-Hashtable -Object $_ }
					}
				$cfg[$setting.Name] = $value
				Set-Variable -Name $setting.Name -Value $Value
			}
   		if ($GitBranch -eq "main" -AND (test-path "\\$RemoteFS\$RemoteFSShare\cfg.json")) {copy "\\$RemoteFS\$RemoteFSShare\cfg.json" .\ -force} #get latest cfg file
	} ELSEIF (!(test-path "$env:programdata\$Org\get-pctasks")) {
		#Install if script folder not present
		$elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
			if ($elevated) {
			if (!(test-path "$env:programdata\$Org")) {mkdir "$env:programdata\$Org"}
			Set-Location "$env:programdata\$Org"
			Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
			$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
			choco install -y git
			git clone -b $GitBranch $GitURI
   			sleep 1
   			if (!(test-path "$env:programdata\$Org\get-pctasks")) {"git clone failed, please try again"; pause; break}
			write-host "Place configuration file $cfgFile in $env:programdata\$Org\get-pctasks\ to continue." -BackgroundColor white -ForegroundColor red
			if (test-path "c:\temp\cfg.json") {copy "c:\temp\cfg.json" "$env:programdata\$Org\get-pctasks" -force} ELSE {pause}
			Set-Location "$env:programdata\$Org\get-pctasks"
			& .\get-pctasks.ps1
			break
			} ELSE {"Run script as an Administrator"; break}
		} ELSE {"Configuration file $cfgFile not found"; break}

<# SCRIPT VARIABLES #>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8 #Console output encoding
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #TLS fix for older PS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
$Script:IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem #Check if running account is system
$script=($MyInvocation.MyCommand.Name).replace(".ps1",'') #Get the name of this script, trim removes the last s in the name.
$BaseDir="$env:programdata\$Org"
if (!(test-path $BaseDir)) {mkdir $BaseDir}
$ScriptDir="$BaseDir\$script"
$Script:RunDir=$ScriptDir
$BinDir="$RunDir\bin"
#if (!(test-path $BinDir)) {mkdir $BinDir}
IF ($IsSystem) {$TempDir="$RunDir\Temp"} ELSE {$TempDir="$env:temp\$org"; mkdir $TempDir -ErrorAction SilentlyContinue}
IF ($IsSystem) {$LogDir="$RunDir\Log"} ELSE {$LogDir=$TempDir}
IF ($IsSystem) {$log="$LogDir\$script"+".log"} ELSE {$log="$LogDir\$script"+".user.log"}
#$LogDir="$RunDir\Log"
#$log="$LogDir\$script"+".log"
$TaskDir="$RunDir\task"
$filenameDate=get-date -Format yyyyMMddmmss
$runbook="$TaskDir\$filenameDate.task" #name cannot change per instance
$head = @{
	'Content-Type'='application/json'
	'name'="$($env:computername.ToUpper())"
	}

#IE Fix
IF ($IsSystem) {
	$keyPath = 'Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main'
} ELSE {
	$keyPath = 'Registry::HKEY_CURRENT_USER\Software\Policies\Microsoft\Internet Explorer\Main'
}
if (!(Test-Path $keyPath)) {
	New-Item $keyPath -Force | Out-Null 
	New-ItemProperty -Path $keyPath -Name "DisableFirstRunCustomize" -Value 1 -PropertyType DWord
	} ELSE {Set-ItemProperty -Path $keyPath -Name "DisableFirstRunCustomize" -Value 1}

<# Script Logging #>
if (!(test-path $LogDir)) {mkdir $LogDir}
try {Stop-Transcript | Out-Null} catch {} #fix log when script is prematurely stopped
Start-Transcript $log -force

#Only run as system user
IF ($IsSystem) {
#Check winrm
winrm quickconfig -q -force

#Check for updates
git pull
}

<# LOAD LOCAL FUNCTIONS #>
Get-ChildItem "$RunDir\functions" | ForEach-Object { . $_.FullName }

<# MAIN #>
Set-Location $scriptDir


#Get IP addresses for logging
Get-NetIPAddress | ? {$_.AddressFamily -eq "IPv4"} | select InterfaceAlias,IPAddress | ft -HideTableHeaders #1.6

#Local execution
IF ($local) {
	#[int64]$start=get-date -Format yyyyMMddHHmm
	#$end=$start + 1
	IF ($function) {& $function $action $options} ELSE {write-host "No function specified" -ForegroundColor black -BackgroundColor red; get-help ".\$script.ps1" }
	} ELSE {

		#Gets tasks for this PC and returns hash of current task for file comparison
		IF ($IsSystem) {$WebTask=CheckWebTasks}

		#Get tasks saved on disk
		$taskbooks=get-childitem $TaskDir\*.task | % fullname
		
		if ($taskbooks) {
			$tasks=@()
			foreach ($file in $taskbooks) {
				
				$hash1=(Get-FileHash -Algorithm sha1 $file).hash
				if ($WebTask -eq $hash1 -AND $file -ne $runbook) {IF ($IsSystem) {remove-item $file -force; "Dup hash found, deleting $file"}} ELSE {
					$tasks+=$file
				} #end if webtask
			} #end foreach
		} ELSE {remove-variable tasks -ErrorAction SilentlyContinue} 
		

		if ($tasks) {
			foreach ($task in $tasks) {
				"$task"
				$time=get-date -Format yyyyMMddHHmm
				$CmdList=gc $task
				
				#Parse
				if ($CmdList[0]) {$function=$CmdList[0]}
				if ($CmdList[1]) {$action=$CmdList[1]}
				if ($CmdList[2]) {$options=$CmdList[2]}
				if ($CmdList[3]) {$start=$($CmdList[3]) | get-date -Format yyyyMMddHHmm}
				if ($CmdList[4]) {$end=$($CmdList[4]) | get-date -Format yyyyMMddHHmm}
				
				#Execution decision tree
				if ($time -gt $end) {remove-item $task -force; "Deleting expired tasks: $task"}
				if ($time -gt $start -AND $time -lt $end) {RunTask; "Start date and end date matched: $task"}
				elseif (!($start)) {RunTask; "No starting date"}
				#elseif ($CmdList[3] -ge $date ) {RunTask; "Start date matched"}
				remove-variable CmdList, time
			} #end foreach
		} #end if tasks
	}#End local ELSE

<#Run each time #>
IF ($IsSystem)
	{
	"Checking pc info..."; get-pcinfo
 	"Check password expiration..."; RunTask -calltask "get-pwdfyi" #starts user mode
	}

IF (!($IsSystem))
	{
	get-pwdfyi
 	}
  
<# Post Main Items #>
Stop-Transcript
if (!($local)) {
	#$ResultsLog=@{"$env:computername"="$(gc $LogDir\get-pctasks.log)"
 	$ResultsLog=@{"$env:computername-$env:username"="$(gc $Log)"
 	#$ResultsLog=@{"$env:computername"="$filenameDate $function $start $end"}
	Invoke-WebRequest -Method POST -Headers $head -Body $ResultsLog -Uri $ResultsURI | Select StatusCode
	}
}
IF (!($IsSystem))
	{
 	SendTemp
  	}
#EOF
