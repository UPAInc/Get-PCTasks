$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function Install-WinGet {
$progressPreference = 'silentlyContinue'
Write-Information "Downloading WinGet and its dependencies..."
Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile Microsoft.UI.Xaml.2.7.x64.appx
Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
Add-AppxPackage Microsoft.UI.Xaml.2.7.x64.appx
Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe

#Refresh path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 

Remove-Item .\Microsoft.VCLibs.x64.14.00.Desktop.appx
Remove-Item .\Microsoft.UI.Xaml.2.7.x64.appx
Remove-Item .\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
return
} #End function

#$wg=get-command winget
#if (!($wg)) {Install-WinGet}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
