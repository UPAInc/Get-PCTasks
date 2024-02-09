$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function schtask() {
	#Create a scheduled task to run script.
	#Default is daily in 30 minute increments.
	$querytask=& $env:windir\system32\schtasks.exe /query /tn "get-pctasks"
	$querytask2=& $env:windir\system32\schtasks.exe /query /tn "get-pctasks-assist"
	IF ($querytask) {
		#Make sure the task is enabled.
		& $env:windir\system32\schtasks.exe /change /enable /TN $script
	} ELSE {
	& $env:windir\system32\schtasks.exe /create /tn get-pctasks /xml "..\temp\get-pctasks.xml"
		}
	if (!($querytask2)) {
		& $env:windir\system32\schtasks.exe /create /tn get-pctasks-assist /xml "..\temp\get-pctasks-assist.xml"
	}
return
}
schtask
write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
