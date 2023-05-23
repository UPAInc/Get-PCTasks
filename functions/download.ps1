$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function DOWNLOAD($type,$url,$file) {
	switch ($type) {
		bits {
			Import-Module BitsTransfer
			Start-BitsTransfer -Source $url -Destination $TempDir
		}
		default {Invoke-WebRequest $url -OutFile $TempDir\$file}
	}
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
