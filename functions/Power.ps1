$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function power($type) {
	switch ($type) {
		off {Stop-Computer -ComputerName localhost -force}
		reboot {Restart-Computer -ComputerName localhost -force}
	}
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
