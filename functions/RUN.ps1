$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function RUN($type,$run,$options) {
	<#
	Examples:
	RUN -type cmd -run dir -options c:\users
	RUN -type pshell -run dir -options c:\users
	RUN -type process c:\myapp.exe -options silent
	#>
	
	#Hashtable for start-process
	$syntax=@{
		NoNewWindow=$true
		wait=$true
		}
	
	#Add arguments to hashtable depending on command
	if ($type -eq 'cmd') {
		$cmdarg=@("/c", "$run", "$options")
		$syntax.add('ArgumentList',"$cmdarg")
		$syntax.add('FilePath','C:\Windows\System32\cmd.exe')
		} ELSE {
			$cmdarg=@("$run", "$options")
			$syntax.add('ArgumentList',"$cmdarg")
			$syntax.add('FilePath',"$run")
			}
	
	#Execute based on type
	switch ($type) {
		pshell {$both="$run $options"; Invoke-Expression -Command $both}
		process {start-process @syntax}
		cmd {start-process @syntax}
	}
	
} #End Rund

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
