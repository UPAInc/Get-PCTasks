<#
.VERSION 1.2
#>

$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

#Reset Windows
function WinReset($options,$action) {
    "WinReset $options $action"
    if ($action -eq 'Confirm') {
        "WinReset confirmed!"
    $WRSB= {
        param($options,$action)
        sleep 10
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
	$session.InvokeMethod($namespaceName, $instance, $methodName, $params)
    	return
    	} #WRSB
    Start-Job -ScriptBlock $WRSB -ArgumentList $options,$action
    Get-Job
    }  ELSE {"WinReset action was not confirmed!"}
return 
}

write-host -Object "$name loaded..." -ForegroundColor yellow -BackgroundColor black
