<#
.VERSION 1.2
#>

$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function WinNuke($options,$action) {
	#Reset Windows
	#$methodName = "doWipeMethod" #can be canceled by the user
	#$methodName = "doWipeProtectedMethod" #possibly unbootable
	if ($options -eq 'safe') {$methodName = "doWipeMethod"} ELSE {$methodName = "doWipeProtectedMethod"}
	$namespaceName = "root\cimv2\mdm\dmmap"
	$className = "MDM_RemoteWipe"
	$session = New-CimSession
	$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
	$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
	$params.Add($param)
	$instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
	if ($action -eq 'Confirm') {"WinNuke invoked..."; $session.InvokeMethod($namespaceName, $instance, $methodName, $params)} ELSE {$Alert="WinNuke action was not confirmed!"}
	if ($alert) {return $alert} ELSE {return "WinNuke Confirmed"}
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
