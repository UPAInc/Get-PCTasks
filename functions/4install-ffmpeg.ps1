$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

$chkff=get-command ffmpeg -ErrorAction SilentlyContinue
$wg=get-command winget -ErrorAction SilentlyContinue

if (!($chkff)) {
	if ($wg) {
			winget install --id ffmpeg -e --source winget --scope machine --accept-package-agreements -h
		} ELSE {
			choco install -y ffmpeg
			}
}		

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black