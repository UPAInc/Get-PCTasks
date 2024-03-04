$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')
$edge='C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$chrome=try {(gp Registry::HKCR\ChromeHTML\shell\open\command)."(Default)" -match '"(.*?)"' | Out-Null; $matches[1]} catch {""}
$firefox='C:\Program Files\Mozilla Firefox\firefox.exe'

function openweb {
	param(
	[Parameter(Mandatory = $False)][String]$browser = $edge,
	[Parameter(Mandatory = $true)] [String]$url
	)
	switch ($browser) {
		default {start-process $edge -ArgumentList $url}
		inprivate {start-process $edge -ArgumentList @('-inprivate', $url)}
		chrome {start-process $chrome -ArgumentList $url}
		incognito {start-process $edge -ArgumentList @('-incognito', $url)}
		firefox {start-process $firefox -ArgumentList $url}
		private {start-process $firefox -ArgumentList @('-private', $url)}
		}
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black