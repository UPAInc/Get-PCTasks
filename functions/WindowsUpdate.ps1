$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function WindowsUpdate() {
	$module = "PSWindowsUpdate"
	if (!(Get-Module -ListAvailable | ? {$_.name -match $module})) {
		#Check
		Unregister-PSRepository -Name PSGallery
		sleep 2
		Register-PSRepository -Default -InstallationPolicy trusted
		sleep 2
		Install-Module -Name PackageManagement
		Install-Module -Name PowerShellGet
		Install-Module -Name PSWindowsUpdate
		Install-PackageProvider -Name NuGet
		Install-Module $module -force
	}
	import-module $module -force
	Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -Install -IgnoreUserInput -AutoReboot -verbose *>&1 | Out-File $LogDir\PSWindowsUpdate.log
}


write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
