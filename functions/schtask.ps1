$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')
$Script:IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem #Check if running account is system

IF ($IsSystem) {
$TaskXML1=".\temp\get-pctasks.xml"
$TaskXML2=".\temp\get-pctasks-assist.xml"

[xml]$currentST=c:\windows\system32\schtasks.exe /query /tn "get-pctasks" /xml
[xml]$currentST2=c:\windows\system32\schtasks.exe /query /tn "get-pctasks-assist" /xml
[xml]$FileST=gc $TaskXML1 -raw
[int64]$STDate=$currentST.task.RegistrationInfo.date | get-date -format yyyyMMdd
[int64]$FileDate=$FileST.task.RegistrationInfo.date | get-date -format yyyyMMdd

function stmake() {
	& c:\windows\system32\schtasks.exe /create /tn get-pctasks /xml $TaskXML1
	& c:\windows\system32\schtasks.exe /create /tn get-pctasks-assist /xml $TaskXML2
}

function stdelete() {
	& c:\windows\system32\schtasks.exe /delete /tn get-pctasks /F
	& c:\windows\system32\schtasks.exe /delete /tn get-pctasks-assist /F
}

"Current Task Date: $STDate"
"Current XML File Date: $FileDate"

if ($STDate -eq $FileDate)
	{
		IF ($currentST.task) {& c:\windows\system32\schtasks.exe /change /enable /TN "get-pctasks"}
		IF (!($currentST.task)) {& c:\windows\system32\schtasks.exe /create /tn get-pctasks-assist /xml $TaskXML2}
	} ELSE 
	{
		stdelete
		stmake
	}
} #End if system ELSE {"Skipping. Not System user..."}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
