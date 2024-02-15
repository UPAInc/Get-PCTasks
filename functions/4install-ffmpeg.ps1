$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

$chkff=get-command ffmpeg
$wg=get-command ffmpeg
if (!($chkff)) {
	if ($wg) {
			winget install ffmpeg -e --source winget --scope machine --accept-package-agreements -h
		} ELSE {
			choco install -y ffmpeg
			}
}		

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black