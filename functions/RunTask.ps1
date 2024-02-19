$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function RunTask($calltask) {
	"Running $function $action $options from $start to $end"
	#For commands that must run as the user and not system
	$who=whoami
	if ($calltask) {$function=$calltask}
	
	function RTUserCheck() {
		if ($who -match "system") {
				#start helper task
				& c:\windows\system32\schtasks.exe /run /i /tn "get-pctasks-assist"
				} ELSE {
					switch ($function) {
						notify {& $function $options}
						RunAsUser {& RUN -type $action -run $options}
						SCREENGRAB {& $function -alt $action -rectime $options}
						SCREENSHOT {& $function -startat $start -endat $end -freq $options}
						SendTemp {& $function -type $action}
						get-pwdfyi {& $function}
						} #End Switch
					} #End ELSE
	} #End RTUserCheck
		
	switch ($function) {
		ECHOTEST {& $function $CmdList}
		get-pwdfyi {RTUserCheck}
		LOCKDESKTOP {& $function}
		DOWNLOAD {& $function -type $action -url $options}
		RUN {& $function -type $action -run $options}
		RunAsUser {RTUserCheck}
		DISABLEAD {& $function -mode $action -reboot $options}
		DENYUSER {& $function -options $options}
		schtask {& $function -url $options}
		NETWORK {& $function $action}
		SCREENGRAB {RTUserCheck}
		SCREENSHOT {RTUserCheck}
		notify {RTUserCheck}
		power {& $function -type $action}
		sendtemp {RTUserCheck}
		WindowsUpdate {& $function}
		WinNuke {& $function}
	} #End switch
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
