$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

if (!(get-command git)) {
	if (winget) {
			winget install --id Git.Git -e --source winget --scope machine --accept-package-agreements -h
		} ELSE {
			choco install -y git
			}
#Refresh path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
}		

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black