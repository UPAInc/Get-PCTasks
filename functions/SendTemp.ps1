$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')
$script:user=whoami
$FSPath="\\$RemoteFS\$RemoteFSShare\$pcname\$env:username"

function sendtemp($type) {
	#write-host "Running $name on $tempdir ..." -ForegroundColor yellow -BackgroundColor black
	
	$list=get-childitem $TempDir -Exclude *.xml | % fullname
	#$list+="$LogDir\get-pctasks.log"
	IF ($list) {
	switch ($type) {
		http {}
		default {
			$TestFS=IF ($RemoteFS) {Test-Connection $RemoteFS -Count 2 -Delay 2 -Quiet} ELSE {$false} #Check to see if remote fs server is avil.
			IF ($TestFS) {
				if (!(test-path $FSPath)) {mkdir $FSPath -force -verbose}
				foreach ($file in $list) {move $file $FSPath -force -verbose -ErrorAction:SilentlyContinue}
				copy "$Log" $FSPath -force -verbose -ErrorAction:SilentlyContinue
				}
			}
		
		}
	}
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
