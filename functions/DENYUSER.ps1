$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function DENYUSER($action) {
	<# USAGE: denyuser "domain\username" or local accounts "$env:computername\username" 
		Running locally: .\get-pctasks.ps1 -local $true -function denyuser -options "domain\username"
	#>
	
	switch ($action) {
		false {& $BinDir\ntrights.exe -r SeDenyInteractiveLogonRight -u $options}
		default {& $BinDir\ntrights.exe +r SeDenyInteractiveLogonRight -u $options}
	}
	
	LOCKDESKTOP
	}
	
write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black