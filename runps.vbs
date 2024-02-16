Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -File C:\ProgramData\upa\get-pctasks\get-pctasks.ps1", 0
Set WshShell = Nothing
