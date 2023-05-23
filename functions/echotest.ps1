$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function ECHOTEST($stuff) {
	write-host "You sent the command $($line.name) $stuff"
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
