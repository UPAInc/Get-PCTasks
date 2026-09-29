<#
.VERSION 1.3
.AUTHOR Eric Duncan
.COMPANYNAME University Physicians' Association (UPA) Inc.
.COPYRIGHT 2024
.RELEASENOTES
	Inspired by https://github.com/dmenafro/OneDrive_HomeDrive_Mapping/blob/main/OneDrive_HomeDrive_Mapping.ps1
	202407251216-1.0-Initial
	202412031144-1.1-testing getting dept from reg.
	202601281312-1.2-Removed dept mapping and test to set one of two letters for mapped drive.
	202609290943-1.3 Updated for Get-PCTaks Script.
#>
$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function MapOD {
<# Config Vars #>
$Replace=$false #Replace with true to use unmap and use preferred letter
$HomeDriveLetter="U","P","O" #Last entry is preferred letter

<# Script Vars #>
$HomeDrivePath = "\\localhost\"+($env:OneDriveCommercial).Replace(':','$')

function map-od($letter,$path,$replace) {
	if ($replace) {
		if (get-psdrive $HomeDriveLetter -ErrorAction SilentlyContinue) {
		net use $HomeDriveLetter /delete /yes
		}
	}
	
New-PSDrive -name $Letter -PSProvider "FileSystem" -Root $path -Persist -Scope 'Global' -Description "${env:username}'s OneDrive"
}

<# MAIN #>
#Map OneDrive as users home drive
foreach ($letter in $HomeDriveLetter) {
		if ((get-psdrive $Letter -ErrorAction SilentlyContinue).DisplayRoot -eq $HomeDrivePath) {throw "Exists"}
		 if (!(get-psdrive $Letter -ErrorAction SilentlyContinue)) {$drive=$letter}
}

$odsyntax=@{
	letter=$drive
	path=$HomeDrivePath
	replace=$Replace
}

map-od @odsyntax

$shell = New-Object -ComObject Shell.Application
$shell.NameSpace("${drive}:\").Self.Name = "${env:username}'s OneDrive"

} #End main function

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black