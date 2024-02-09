$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function RunTask() {
	"Running $function $action $options from $start to $end"
	#For commands that must run as the user and not system
	$who=whoami
	function RTUserCheck() {
		if ($who -match "system") {
				#start helper task
				& $env:windir\system32\schtasks.exe /run /i /tn "$Script-assist"
				} ELSE {
					switch ($function) {
						notify {& $function -options $options}
						SCREENGRAB {& $function -alt $action -rectime $options}
						SendTemp {& $function -type $action}
					} #End Switch
					} #End ELSE
	} #End RTUserCheck
		
	switch ($function) {
		ECHOTEST {& $function $CmdList}
		LOCKDESKTOP {& $function}
		DOWNLOAD {& $function -type $action -url $options}
		RUN {& $function -type $action -run $options}
		DISABLEAD {& $function -mode $action -reboot $options}
		DENYUSER {& $function -options $options}
		schtask {& $function -url $options}
		NETWORK {& $function $action}
		SCREENGRAB {RTUserCheck}
		SCREENSHOT {& $function -startat $start -endat $end -freq $options}
		notify {RTUserCheck}
		power {& $function -type $action}
		sendtemp {RTUserCheck}
		WindowsUpdate {& $function}
		WinNuke {& $function}
	} #End switch
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
