$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function NETWORK($action) {
	#Disable all network adapters.
	switch ($action) {
		disable {Get-NetAdapter | Disable-NetAdapter -Confirm:$false}
		enable {Get-NetAdapter | Enable-NetAdapter -Confirm:$false}
	}
}
write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
