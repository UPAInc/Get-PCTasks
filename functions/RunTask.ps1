$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function RunTask($calltask) {
	if (!($options)) {$options=""}
	if (!($action)) {$action=""}
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
     					get-pwdfyi {& $function}
						notify {& $function $options}
      					LOCKDESKTOP {& $function}
	    				openweb {
	  						if ($action) {$browser=$action} ELSE {$browser=$edge}
	 						& $function -url $options -browser $browser
							}
						RunAsUser {& RUN -type $action -run $options}
						SCREENGRAB {& $function -alt $action -rectime $options}
						SCREENSHOT {& $function -startat $start -endat $end -freq $options}
						SendTemp {& $function -type $action}
						} #End Switch
					"RT is executing $function $action $options"
					} #End ELSE
	} #End RTUserCheck
		
	switch ($function) {
		COMBO {& $options}
		ECHOTEST {& $function $CmdList}
		LOCKDESKTOP {RTUserCheck}
		DOWNLOAD {& $function -type $action -url $options}
  		get-pwdfyi {RTUserCheck}
    		openweb {RTUserCheck}
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
		WinReset {& $function -action $action -options $options}
	} #End switch
"RT is executing $function $action $options"
return
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
