$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')
			
if (!(choco)) {
				#Install Chocolatey
				Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
				#Refresh path
				$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") 
				}
				
write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black