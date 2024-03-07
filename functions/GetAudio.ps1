$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function GetAudio($rectime,$startat,$endat) {
if (!($rectime)) {$rectime="00:10:00"} #Incremental file duration
if (!($tempdir)) {$tempdir="$env:temp" + "\"} #save folder
if (!($start)) {$start=[int64]$startat=get-date -Format yyyyMMddHHmm} #default start time
if (!($end)) {$end=(get-date).AddHours(1) | get-date -Format yyyyMMddHHmm} #default to an hour runtime
if (!($endat)) {$endat=$end}
if (!($startat)) {$startat=$start}

$sb={
param($device,$rectime,$saveas,$startat,$endat)
while ($startat -lt $endat) {
	ffmpeg -f dshow -hide_banner -i audio="$device" -y -t "$rectime" -codec:a libmp3lame -qscale:a 5 "$saveas"
	[int64]$startat=get-date -Format yyyyMMddHHmm
	} #end while loop
}

$mics=(Get-PnpDevice).Where{$_.Class -eq 'AudioEndpoint'} | ? {$_.status -eq 'OK' -AND $_.name -like '*microphone*'} | foreach name

if ($mics.count -gt 1) {
	foreach ($device in $mics) {
		$saveas="$tempdir"+"$(get-date -Format yyyyMMddHHmm)"+"$(get-random)"+"$device"+".mp3"
		start-job -ScriptBlock $sb -ArgumentList @($device,$rectime,$saveas,$startat,$endat)
		}
} ELSE {
	$saveas="$tempdir"+"$(get-date -Format yyyyMMddHHmm)"+"$(get-random)"+"$device"+".mp3"
	start-job -ScriptBlock $sb -ArgumentList @($mics,$rectime,$saveas,$startat,$endat)
	}

#Clean-up job history
get-job | ? {$_.state -eq 'Completed' -OR $_.state -eq 'Failed'} | remove-job -ErrorAction SilentlyContinue
} #end function

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
