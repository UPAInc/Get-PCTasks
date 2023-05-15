#Screen recording

$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function SCREENGRAB($alt,$rectime,$startat,$endat) {
	$ffmpeg1="$BinDir\ffmpeg.exe"
	$ffmpeg2="$(Get-ChildItem -Recurse "C:\Program Files\WinGet\Packages" | ? {$_.name -eq "ffmpeg.exe"} | % fullname)"
	$ffmpeg3="$env:ProgramData\chocolatey\lib\ffmpeg\tools\ffmpeg\bin\ffmpeg.exe"
	
	if (!($rectime)) {$rectime="00:15:00"} #default time to capture screen
	if (!($endat)) {$endat=$end}
	if (!($startat)) {$startat=$start}
	
	$chkff=get-command ffmpeg
	if (!($chkff)) {
		$ffmpeg=if (test-path $ffmpeg1) {return $ffmpeg1} ELSEIF (test-path $ffmpeg2) {return $ffmpeg2} ELSEIF (test-path $ffmpeg3) {return $ffmpeg3} ELSE {"ffmpeg missing"; break}
		}
		
	if (!(Get-Process | ? {$_.ProcessName -like 'ffmpeg'})) {
		"Checking for running ffmpeg"
		while ($startat -lt $endat) {
			$rand=get-random -Minimum 1000 -Maximum 9999
			$vid="$TempDir\$env:computername-$rand-$filenameDate.mkv" #video filename
			$param1="-filter_complex ddagrab=0,hwdownload,format=bgra -c:v libx264 -crf 40 -preset medium -tune stillimage -t $rectime $vid"
			$param2="-f gdigrab -framerate 25 -i desktop -t $rectime -c:v libx264 -preset medium -crf 40 -tune stillimage $vid"
			switch ($alt) {
				true {start-process $ffmpeg -ArgumentList $param1 -NoNewWindow -Wait}
				default {start-process $ffmpeg -ArgumentList $param2 -NoNewWindow -Wait}
				}
			[int64]$startat=get-date -Format yyyyMMddHHmm
		}
	}
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black