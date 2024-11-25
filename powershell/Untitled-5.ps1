$Sta = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Public\Documents\Task01.ps1"'
$Stt = New-ScheduledTaskTrigger -Daily -At 3am
Register-ScheduledTask Task01 -Action $Sta -Trigger $Stt