$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function notifyBT($action) {
	import-module BurntToast -force
	$toastParams = @{
    Text = "$options"
    Header = (New-BTHeader -Id 1 -Title "Notification from UPA Support")
	Applogo = "$bindir\logosmall.png"
	SnoozeAndDismiss = $true
	Sound = "SMS"
	}
	
	New-BurntToastNotification @toastParams
			
}

function notifyWPF($action) {
Add-Type -AssemblyName PresentationCore,PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::OK
$MessageIcon = [System.Windows.MessageBoxImage]::Information
$MessageTitle = 'Notification from UPA Support'
$MessageBody = "$action"

#Show the pop-up message
[System.Windows.MessageBox]::Show($MessageBody,$MessageTitle,$ButtonType,$MessageIcon)
}

function notify($action) {
	notifyWPF "$action"
	notifyBT "$action"
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
