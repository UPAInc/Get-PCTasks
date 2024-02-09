$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function Install-WinGet {
#from https://github.com/Romanitho/Winget-AutoUpdate/blob/main/Winget-AutoUpdate-Install.ps1
#Thank you, Romain!

#Check if Visual C++ 2019 or 2022 installed
$Visual2019 = "Microsoft Visual C++ 2015-2019 Redistributable*"
$Visual2022 = "Microsoft Visual C++ 2015-2022 Redistributable*"
$path = Get-Item HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.GetValue("DisplayName") -like $Visual2019 -or $_.GetValue("DisplayName") -like $Visual2022 }
#$winget="C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.19.10173.0_arm64__8wekyb3d8bbwe\winget.exe"
$Winget = gci "C:\Program Files\WindowsApps" -Recurse -File | ? {$_.name -like "AppInstallerCLI.exe" -or $_.name -like "winget.exe"} | select -ExpandProperty fullname

if (!($path)) {
	if ((Get-CimInStance Win32_OperatingSystem).OSArchitecture -like "*64*") {$OSArch = "x64"} else {$OSArch = "x86"}

	Write-host "-> Downloading VC_redist.$OSArch.exe..."
	$SourceURL = "https://aka.ms/vs/17/release/VC_redist.$OSArch.exe"
	$Installer = $WingetUpdatePath + "\VC_redist.$OSArch.exe"
	$ProgressPreference = 'SilentlyContinue'
	Invoke-WebRequest $SourceURL -UseBasicParsing -OutFile (New-Item -Path $Installer -Force)
	Write-host "-> Installing VC_redist.$OSArch.exe..."
	Start-Process -FilePath $Installer -Args "/quiet /norestart" -Wait
	Remove-Item $Installer -ErrorAction Ignore
	Write-host "-> MS Visual C++ 2015-2022 installed successfully" -ForegroundColor Green
    Write-Host "`nChecking if Winget is installed" -ForegroundColor Yellow
} #End if path

    #Check Package Install
    $TestWinGet = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq "Microsoft.DesktopAppInstaller" }

    #Current: v1.4.10173 = 1.19.10173.0 = 2023.118.406.0
	#old code: [Version]$TestWinGet.Version -ge "2023.118.406.0"
    If ($winget) {Write-Host "WinGet is Installed" -ForegroundColor Green} Else {
        #Download WinGet MSIXBundle
        Write-Host "-> Not installed. Downloading WinGet..."
        $WinGetURL = "https://github.com/microsoft/winget-cli/releases/download/v1.4.10173/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($WinGetURL, "$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle")

        #Install WinGet MSIXBundle
        try {
            Write-Host "-> Installing Winget MSIXBundle for App Installer..."
			#User level
            #Add-AppxProvisionedPackage -Online -PackagePath "$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -SkipLicense | Out-Null
			#System level
			DISM.EXE /Online /add-ProvisionedAppxPackage /PackagePath:"$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"  /SkipLicense
            Write-Host "Installed Winget MSIXBundle for App Installer" -ForegroundColor Green
        }
        catch {Write-Host "Failed to intall Winget MSIXBundle for App Installer..." -ForegroundColor Red}

        #Remove WinGet MSIXBundle
        Remove-Item -Path "$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Force -ErrorAction Continue
    }
	

} #End function
$wg=get-command winget
if (!($wg)) {Install-WinGet}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
