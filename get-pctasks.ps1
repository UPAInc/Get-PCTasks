<#PSScriptInfo
.VERSION 1.5.2
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
		
	TODO:
		Add upload function for screen grab/shots.
		Backup browser history file.
		Format parmas properly.
		
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
param ($CnCURI,$ResultsURI,$local,$function,$action,$options)


<# VARIABLES #>
if (!($CnCURI)) {$CnCURI="https://eoj5o3nkdop6ami.m.pipedream.net"} #Override commandline switch
$GitURI="https://github.com/UPAInc/Get-PCTasks"
if (!($ResultsURI)) {$ResultsURI="https://eoutai8j6ad3igb.m.pipedream.net"}

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
$Winget = gci "C:\Program Files\WindowsApps" -Recurse -File | ? {$_.name -like "AppInstallerCLI.exe" -or $_.name -like "winget.exe"} | select -ExpandProperty fullname

<# Script Logging #>
if (!(test-path $LogDir)) {mkdir $LogDir}
try {Stop-Transcript | Out-Null} catch {} #fix log when script is prematurely stopped
Start-Transcript $log -force

<# FUNCTIONS #>

function Install-WinGet {
#from https://github.com/Romanitho/Winget-AutoUpdate/blob/main/Winget-AutoUpdate-Install.ps1
#Check if Visual C++ 2019 or 2022 installed
$Visual2019 = "Microsoft Visual C++ 2015-2019 Redistributable*"
$Visual2022 = "Microsoft Visual C++ 2015-2022 Redistributable*"
$path = Get-Item HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.GetValue("DisplayName") -like $Visual2019 -or $_.GetValue("DisplayName") -like $Visual2022 }

if (!($path)) {
	if ((Get-CimInStance Win32_OperatingSystem).OSArchitecture -like "*64*") {$OSArch = "x64"} else {$OSArch = "x86"}

	Write-host "-> Downloading VC_redist.$OSArch.exe..."
	$SourceURL = "https://aka.ms/vs/17/release/VC_redist.$OSArch.exe"
	$Installer = $WingetUpdatePath + "\VC_redist.$OSArch.exe"
	$ProgressPreference = 'SilentlyContinue'
	Invoke-WebRequest $SourceURL -UseBasicParsing -OutFile (New-Item -Path $Installer -Force)
	Write-host "-> Installing VC_redist.$OSArch.exe..."
	Start-Process -FilePath $Installer -Args "/quiet /norestart" -Wait
	Remove-Item $Installer -ErrorAction Ignore
	Write-host "-> MS Visual C++ 2015-2022 installed successfully" -ForegroundColor Green
    Write-Host "`nChecking if Winget is installed" -ForegroundColor Yellow
} #End if path

    #Check Package Install
    $TestWinGet = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "Microsoft.DesktopAppInstaller" }

    #Current: v1.4.10173 = 1.19.10173.0 = 2023.118.406.0
	#old code: [Version]$TestWinGet.Version -ge "2023.118.406.0"
    If (test-path $winget) {Write-Host "WinGet is Installed" -ForegroundColor Green} Else {
        #Download WinGet MSIXBundle
        Write-Host "-> Not installed. Downloading WinGet..."
        $WinGetURL = "https://github.com/microsoft/winget-cli/releases/download/v1.4.10173/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($WinGetURL, "$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle")

        #Install WinGet MSIXBundle
        try {
            Write-Host "-> Installing Winget MSIXBundle for App Installer..."
			#User level
            #Add-AppxProvisionedPackage -Online -PackagePath "$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -SkipLicense | Out-Null
			#System level
			DISM.EXE /Online /add-ProvisionedAppxPackage /PackagePath:"$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"  /SkipLicense
            Write-Host "Installed Winget MSIXBundle for App Installer" -ForegroundColor Green
        }
        catch {Write-Host "Failed to intall Winget MSIXBundle for App Installer..." -ForegroundColor Red}

        #Remove WinGet MSIXBundle
        Remove-Item -Path "$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Force -ErrorAction Continue
    }
	

} #End function

function SCREENGRAB($alt,$rectime,$startat,$endat) {
	if (!($rectime)) {$rectime="00:15:00"} #default time to capture screen
	if (!($endat)) {$endat=$end}
	if (!($startat)) {$startat=$start}
	$ffmpeg="$(Get-ChildItem -Recurse "C:\Program Files\WinGet\Packages" | ? {$_.name -eq "ffmpeg.exe"} | % fullname)" #set ffmpeg exe
	if (!($ffmpeg)) {$ffmpeg = "$BinDir\ffmpeg.exe"} #set backup ffmpeg exe if needed
		
	if (!(Get-Process | ? {$_.ProcessName -like 'ffmpeg'})) {
		"Checking for running ffmpeg"
		while ($startat -lt $endat) {
			$rand=get-random -Minimum 1000 -Maximum 9999
			$vid="$TempDir\$env:computername-$rand-$filenameDate.mkv" #video filename
			$param1="-filter_complex ddagrab=0,hwdownload,format=bgra -c:v libx264 -crf 40 -preset medium -tune stillimage -t $rectime $vid"
			$param2="-f gdigrab -framerate 25 -i desktop -t $rectime -c:v libx264 -preset medium -crf 40 -tune stillimage $vid"
			switch ($alt) {
				true {start-process $ffmpeg -ArgumentList $param1 -NoNewWindow -Wait}
				default {start-process $ffmpeg -ArgumentList $param2 -NoNewWindow -Wait}
				}
			[int64]$startat=get-date -Format yyyyMMddHHmm
		}
	}
}

function SCREENSHOT($startat,$endat,$freq) {
	#From https://stackoverflow.com/questions/2969321/how-can-i-do-a-screen-capture-in-windows-powershell
	if (!($endat)) {$endat=$end}
	if (!($startat)) {$startat=$start}
	if (!($freq)) {$freq=15}
	"Running from $startat to $endat"
	while ($startat -lt $endat) {
	$rand=get-random -Minimum 1000 -Maximum 9999
	$snap="$TempDir\$env:computername-$rand-$filenameDate.png"
	Add-Type -AssemblyName System.Windows.Forms,System.Drawing
	$screens = [Windows.Forms.Screen]::AllScreens
	$top    = ($screens.Bounds.Top    | Measure-Object -Minimum).Minimum
	$left   = ($screens.Bounds.Left   | Measure-Object -Minimum).Minimum
	$width  = ($screens.Bounds.Right  | Measure-Object -Maximum).Maximum
	$height = ($screens.Bounds.Bottom | Measure-Object -Maximum).Maximum
	$bounds   = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
	$bmp      = New-Object System.Drawing.Bitmap ([int]$bounds.width), ([int]$bounds.height)
	$graphics = [Drawing.Graphics]::FromImage($bmp)
	$graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
	$bmp.Save("$snap")
	$graphics.Dispose()
	$bmp.Dispose()
	"Screenshot taken: $snap"
	sleep -Seconds $freq
	[int64]$startat=get-date -Format yyyyMMddHHmm
	}
}

function DENYUSER() {
	<# USAGE: denyuser "domain\username" or local accounts "$env:computername\username" 
		Running locally: .\get-pctasks.ps1 -local $true -function denyuser -options "domain\username"
	#>
	
	& $BinDir\ntrights.exe +r SeDenyInteractiveLogonRight -u $options
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
	
	#Make sure Nuget is working
	if ( -not ( Get-PackageProvider -ListAvailable | Where-Object Name -eq "Nuget" ) ) {Install-PackageProvider "Nuget" -Force -Scope AllUsers -Confirm:$false}
	
	#if (!(winget show git.git --accept-package-agreements --disable-interactivity)) {winget install git.git --scope machine --accept-package-agreements --disable-interactivity} #install git via winget
	winget install git.git --scope machine --accept-package-agreements --disable-interactivity
	#if (!(winget show ffmpeg --accept-package-agreements --disable-interactivity)) {winget install ffmpeg --scope machine --accept-package-agreements --disable-interactivity} #install ffmpeg via winget
	winget install ffmpeg --scope machine --accept-package-agreements --disable-interactivity
	if (!(test-path $BinDir\ffmpeg.exe)) {
		$ffmpeg="$(Get-ChildItem -Recurse "C:\Program Files\WinGet\Packages" | ? {$_.name -eq "ffmpeg.exe"} | % fullname)"
		copy $ffmpeg $BinDir -force
	}
	
	if (!(test-path $scriptDir)) {git clone $GitURI $scriptDir} ELSE {Set-Location $scriptDir; git pull} #update script
	
	#Grant users write access to temp folder.
	$aclCheck=Get-Acl -Path "C:\ProgramData\upa\Get-PCTasks\temp" | ? {$_.AccessToString -like '*Users Allow  Write*'}
	if (!($aclCheck)) {
	$NewAcl = Get-Acl -Path "C:\users"
	$isProtected = $true
	$preserveInheritance = $true
	$NewAcl.SetAccessRuleProtection($isProtected, $preserveInheritance)
	$AddAcl=New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "Write", "Allow")
	$NewACL.SetAccessRule($AddAcl)
	Set-Acl -Path $TempDir -AclObject $
	}
	
	#Install mod for notifications. 1.6
	$bt=Get-Module -ListAvailable | ? {$_.name -match "BurntToast"}
	if (!($bt)) {install-module BurntToast -Scope AllUsers -Confirm:$false -force}
	
}

function notify($action) {
	import-module BurntToast -force
	$toastParams = @{
    Text = "$options"
    Header = (New-BTHeader -Id 1 -Title "Notification from UPA Support")
	Applogo = "$BinDir\logosmall.png"
	SnoozeAndDismiss = $true
	Sound = "SMS"
	}
	
	New-BurntToastNotification @toastParams
			
}

function schtask($URL) {
	#Create a scheduled task to run script.
	#Default is daily in 30 minute increments.
	$querytask=& $env:windir\system32\schtasks.exe /query /tn $script
	$querytask2=& $env:windir\system32\schtasks.exe /query /tn $script-assist
	IF ($querytask) {
		#Make sure the task is enabled.
		& $env:windir\system32\schtasks.exe /change /enable /TN $script
	} ELSE {
	& $env:windir\system32\schtasks.exe /create /xml "$TempDir\get-pctasks.xml"
		}
	if (!($querytask2)) {
		& $env:windir\system32\schtasks /create /xml "$TempDir\get-pctasks-assist.xml"
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
	#For commands that must run as the user and not system
	$who=whoami
	function RTUserCheck() {
		if ($who -match "system") {
				#start helper task
				& $env:windir\system32\schtasks.exe /run /i /tn "$Script-assist"
				} ELSE {
					switch ($function) {
						notify {& $function -options $options}
						SCREENGRAB {& $function $action $options}
					}
					} #End ELSE
	}
		
	switch ($function) {
		ECHOTEST {& $function $CmdList}
		LOCKDESKTOP {& $function}
		DOWNLOAD {& $function $action $options}
		RUN {& $function $action $options}
		DISABLEAD {& $function $action}
		DENYUSER {& $function -options $options}
		schtask {& $function -url $options}
		NETWORK {& $function $action}
		SCREENGRAB {RTUserCheck}
		SCREENSHOT {& $function -startat $start -endat $end}
		notify {RTUserCheck}
	}
}

<# MAIN #>
Get-NetIPAddress | ? {$_.AddressFamily -eq "IPv4"} | select InterfaceAlias,IPAddress | ft -HideTableHeaders #1.6


IF ($local) {
	[int64]$start=get-date -Format yyyyMMddHHmm
	$end=$start + 1
	"Running $function $action $options from $start to $end"
	& $function $action $options
	} ELSE {
#Run functions in this order
Install-WinGet
set-alias -name winget -value $winget
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

$ResultsLog=@{"$env:computername"="$(gc $LogDir\get-pctasks.log)"}
Invoke-WebRequest -Method POST -Headers $head -Body $ResultsLog -Uri $ResultsURI