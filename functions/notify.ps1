$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

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

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
