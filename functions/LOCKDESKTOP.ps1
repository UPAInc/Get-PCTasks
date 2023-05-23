$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function LOCKDESKTOP() {
	& $ENV:windir\System32\Rundll32.exe user32.dll,LockWorkStation
	}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
