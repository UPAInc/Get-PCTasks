$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

if (!(git)) {
	if (winget) {
			winget install --id Git.Git -e --source winget --scope machine --accept-package-agreements -h
		} ELSE {
			choco install -y git
			}
}		

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black