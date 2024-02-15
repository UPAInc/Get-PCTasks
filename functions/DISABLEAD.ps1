$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function DISABLEAD($mode,$reboot) {
	$path="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
	$name="CachedLogonsCount"
	
	function updatereg() {
		IF (test-path $path) {
		"Set and check reg value"
		set-itemproperty -path $path -name $name -value $value
		Get-ItemProperty -Path $path | foreach $name
		} ELSE {
		"Make key"
		New-Item -Path "$path" -force
		New-ItemProperty -Path "$path" -PropertyType 'String' -Name $name -Value $value
		Get-ItemProperty -Path $path | foreach $name
		}
		LOCKDESKTOP
	}
	
	switch($mode) {
		enable {$value="0" ; updatereg}
		disable {$value="10" ; updatereg}
	}
	
	if ($reboot) {Restart-Computer -ComputerName localhost -force}
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black