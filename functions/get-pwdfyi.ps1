$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function get-pwdfyi(){
$IsSystem = [System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem #Check if running account is system
$dc=("$env:LOGONSERVER" + '.' +"$env:USERDNSDOMAIN").Replace('\\','')
$netcheck = Test-Connection $dc -Quiet -Count 1 #Check to see if a domain controller is avail.

#Check for notify mod
$script:chknotify=Get-Module | ? {$_.name -eq 'notify'} | select name
if (!($chknotify)) {import-module "C:\programdata\$org\get-pctasks\functions\notify.ps1"}

#Set the number of days before expiration for the notice to start.
$NotifyDays=-7

$today=get-date
#Connect to AD, lookup current user running script.
$Search = New-Object DirectoryServices.DirectorySearcher("(&(objectCategory=user)(samaccountname=$env:username))")
$search.PropertiesToLoad.add('msDS-UserPasswordExpiryTimeComputed')
$Results = $Search.FindAll()

#Convert date to human readable....
$expire=[datetime]::FromFileTime("$($Results.properties["msDS-UserPasswordExpiryTimeComputed"])")
$noticeDate=($expire | get-date).adddays($NotifyDays) 

$MessageBody = @"
Your network password will expire on $expire.

To prevent logon issues with Cisco AnyConnect or Microsoft Office, please change your password now.

Update your password by pressing 'Control-Alt-Delete', select 'Change Password'.

Test your new password by locking and unlocking your Desktop.
"@

#Minimize all open Windows
#(New-Object -ComObject Shell.Application).MinimizeAll()

<# Main Code Start #>
#Write to prompt for log.
"Current user: $env:username"
"Expires on: $expire"
"Notify by: $noticedate"

if (!($IsSystem)) {
		if ($netcheck) {
			if ($today -le $expire -AND $today -ge $noticedate) {notify $MessageBody} ELSE {"No notice..."}
		} ELSE {"Can't contact the $env:USERDNSDOMAIN domain"}
}
return
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
