$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function schtask($URL) {
	#Create a scheduled task to run script.
	#Default is daily in 30 minute increments.
	$querytask=& $env:windir\system32\schtasks.exe /query /tn $script
	$querytask2=& $env:windir\system32\schtasks.exe /query /tn $script-assist
	IF ($querytask) {
		#Make sure the task is enabled.
		& $env:windir\system32\schtasks.exe /change /enable /TN $script
	} ELSE {
	& $env:windir\system32\schtasks.exe /create /TN $script /xml "$TempDir\get-pctasks.xml"
		}
	if (!($querytask2)) {
		& $env:windir\system32\schtasks.exe /create /tn get-pctasks-assist /xml "$TempDir\get-pctasks-assist.xml"
	}
}
write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
