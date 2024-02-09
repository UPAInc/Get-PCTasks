$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

$chkbt=get-command New-BurntToastNotification -ErrorAction SilentlyContinue
$wg=get-command winget -ErrorAction SilentlyContinue

if (!($chkbt)) {
	if ($wg) {
			winget install --id BurntToast -e --source winget --scope machine --accept-package-agreements -h
		} ELSE {
			Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false -Scope AllUsers
			install-module BurntToast -force -Confirm:$false -Scope AllUsers
			}
}		

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black