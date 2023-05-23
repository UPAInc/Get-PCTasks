<#PSScriptInfo
.VERSION 2.2
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
	20230523 - 2.2
		Window was showing in user mode, added a window hide.
		Screengrab had a path issue.
		
	TODO:
		Add http upload function for screen grab/shots.
		Backup browser history file.
		
		
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

.INPUTS
 None. You cannot pipe objects to this script.
 
.OUTPUTS
 Defaults to log file.

.EXAMPLE
PS> .\get-pctasks.ps1 -CnCURI https://xxx
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $False)] [String] $GitURI = "https://github.com/UPAInc/Get-PCTasks", 
	[Parameter(Mandatory = $False)] [String] $CnCURI = "https://eoj5o3nkdop6ami.m.pipedream.net", 
	[Parameter(Mandatory = $False)] [String] $ResultsURI = "https://eoutai8j6ad3igb.m.pipedream.net",
	[Parameter(Mandatory = $False)] [String] $RemoteFS = "172.16.133.45",
	[Parameter(Mandatory = $False)] [String] $RemoteFSShare = 'ScriptsUpload$',
	[Parameter(Mandatory = $False)] [Switch] $local = $false,
	[Parameter(Mandatory = $False)] [String] $function,
	[Parameter(Mandatory = $False)] [String] $action,
	[Parameter(Mandatory = $False)] [String] $options
)

<# SCRIPT VARIABLES #>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8 #Console output encoding
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 #TLS fix for older PS
$Script:IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem #Check if running account is system
$script=($MyInvocation.MyCommand.Name).replace(".ps1",'') #Get the name of this script, trim removes the last s in the name.
$Script:RunDir = $PSScriptRoot #Get the Working Dir
$BaseDir="$env:programdata\UPA"
$ScriptDir="$BaseDir\$script"
$BinDir="$RunDir\bin"
$TempDir="$RunDir\Temp"
$LogDir="$RunDir\Log"
$log="$LogDir\$script"+".log"
$TaskDir="$RunDir\task"
$filenameDate=get-date -Format yyyyMMddmmss
$runbook="$TaskDir\$filenameDate.task" #name cannot change per instance
$head = @{
	'Content-Type'='application/json'
	'name'="$($env:computername.ToUpper())"
	}

#Hide user execution
#https://stackoverflow.com/questions/1802127/how-to-run-a-powershell-script-without-displaying-a-window
IF (!($IsSystem)) {
$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
add-type -name win -member $t -namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)
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

<# FUNCTIONS #>
Get-ChildItem "$RunDir\functions" | ForEach-Object {import-module $_.FullName -force}

<# MAIN #>

#Get IP addresses for logging
Get-NetIPAddress | ? {$_.AddressFamily -eq "IPv4"} | select InterfaceAlias,IPAddress | ft -HideTableHeaders #1.6

#Grant users write access to temp folder.
if ($IsSystem) {
	$aclCheck=Get-Acl -Path $tempdir | ? {$_.AccessToString -like '*Users Allow  Write*'}
	if (!($aclCheck)) {
	$NewAcl = Get-Acl -Path "C:\users"
	$isProtected = $true
	$preserveInheritance = $true
	$NewAcl.SetAccessRuleProtection($isProtected, $preserveInheritance)
	$AddAcl=New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "Write", "Allow")
	$NewACL.SetAccessRule($AddAcl)
	Set-Acl -Path $tempdir -AclObject $NewACL
	}
}

#Local execution
IF ($local) {
	[int64]$start=get-date -Format yyyyMMddHHmm
	$end=$start + 1
	IF ($function) {& $function $action $options} ELSE {write-host "No function specified" -ForegroundColor black -BackgroundColor red; get-help ".\$script.ps1" }
	} ELSE {

		#Run functions in this order
		#Install-WinGet
		#set-alias -name winget -value $winget
		#Install-Update

		#Check dirs in case install fails
		if (!(test-path $TempDir)) {mkdir $TempDir}
		if (!(test-path $BinDir)) {mkdir $BinDir}

		#Check for scheduled task, enable or create.
		schtask -url $CnCURI

		#Gets tasks for this PC and returns hash of current task for file comparison
		$WebTask=CheckWebTasks

		#Get tasks saved on disk
		$taskbooks=get-childitem $TaskDir\*.task | % fullname
		if ($taskbooks) {
			$tasks=@()
			foreach ($file in $taskbooks) {
				$hash1=(Get-FileHash -Algorithm sha1 $file).hash
				if ($WebTask -eq $hash1 -AND $file -ne $runbook) {remove-item $file; "Dup hash found, deleting $file"} ELSE {
					$tasks+=$file
				}
			}
		} ELSE {remove-variable tasks}

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
				if ($time -gt $end) {rm $task -force; "Deleting expired tasks: $task"}
				if ($time -gt $start -AND $time -lt $end) {RunTask; "Start date and end date matched: $task"}
				elseif (!($start)) {RunTask; "No starting date"}
				#elseif ($CmdList[3] -ge $date ) {RunTask; "Start date matched"}
				remove-variable CmdList, time
			}
		}
			}#End if local


<# Post Main Items #>
Stop-Transcript
SendTemp

if (!($local)) {
	$ResultsLog=@{"$env:computername"="$(gc $LogDir\get-pctasks.log)"}
	Invoke-WebRequest -Method POST -Headers $head -Body $ResultsLog -Uri $ResultsURI | Select StatusCode
}

#EOF
