$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

$TaskXML1="..\temp\get-pctasks.xml"
$TaskXML2="..\temp\get-pctasks-assist.xml"

[xml]$currentST=schtasks.exe /query /tn "get-pctasks" /xml
[xml]$FileST=gc $TaskXML1 -raw
[int64]$STDate=$currentST.task.RegistrationInfo.date | get-date -format yyyyMMdd
[int64]$FileDate=$FileST.task.RegistrationInfo.date | get-date -format yyyyMMdd

function stmake() {
	& $env:windir\system32\schtasks.exe /create /tn get-pctasks /xml $TaskXML1
	& $env:windir\system32\schtasks.exe /create /tn get-pctasks-assist /xml $TaskXML2
}

function stdelete() {
	& $env:windir\system32\schtasks.exe /delete /tn get-pctasks /F
	& $env:windir\system32\schtasks.exe /delete /tn get-pctasks-assist /F
}

"Current Task Date: $STDate"
"Current XML File Date: $FileDate"

if ($STDate -eq $FileDate)
	{
		IF ($currentST.task) {& $env:windir\system32\schtasks.exe /change /enable /TN "get-pctasks"}
	} ELSE 
	{
		stdelete
		stmake
	}
	
write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
