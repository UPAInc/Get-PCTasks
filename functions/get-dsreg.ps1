$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function get-dsreg() {
# Run dsregcmd /status and capture output as text
# Parse lines of “Key : Value” into a PSCustomObject
$raw = & "$env:SystemRoot\System32\dsregcmd.exe" /status
$obj = [PSCustomObject]@{}
$raw | ForEach-Object {
    if ($_ -match '^(.*?)\s*:\s*(.*)$') {
        $key = $matches[1].Trim() -replace '\s+',''
        $value = $matches[2].Trim()
        $obj | Add-Member -MemberType NoteProperty -Name $key -Value $value
    }
}
return $obj
}

write-host "$name loaded... Use global variable DomainStatus." -ForegroundColor yellow -BackgroundColor black
$global:domainstatus = Get-Dsreg | select AzureAdJoined,DomainJoined
($global:domainstatus | Format-List | Out-String).trim()

if ($global:domainstatus.AzureAdJoined -eq 'YES' -AND $global:domainstatus.DomainJoined -eq 'NO') {
	"Checking admins..."
	$nc = net localgroup Administrators
	if (!($nc -like '*CAAnthony*')) {net localgroup administrators /add "AzureAD\CAAnthony@utmck.edu"}
	if (!($nc -like '*u20173919*')) {net localgroup administrators /add "AzureAD\u20173919@utmck.edu"}
}
