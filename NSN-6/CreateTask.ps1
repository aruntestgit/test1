$RootPath = "C:\DoNotDelete"
$SplunkInputFile = "C:\Program Files\SplunkUniversalForwarder\etc\system\local\inputs.conf"
$TaskName = "NFS.LogsCleanupTask_Monthly"
$RunUserName = "BTTESTADS\BTScheculedTaskUser"
$RunUserPassword = "\-N>mHWGtXYTb4rb"
$Action = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File 'C:\DoNotDelete\Cleanup_Logs.ps1' -verb RUNAS"
$Frequency = "Monthly"
$DayOfMonth = "1"
$MonthOfYear = "*"
$StartTime = "00:10:00"
$RunLevel = "HIGHEST"

$AddContent = @"
[monitor://C:\DoNotDelete\CleanupSplunkLogs.log]
index = bt-test
sourcetype = BT-Maintenance
disabled = 0
"@


if (!(Test-Path $RootPath)) {
    mkdir $RootPath
}

Add-Content -Path $SplunkInputFile -Value $AddContent

schtasks /create /TN $TaskName /RU $RunUserName /RP $RunUserPassword /tr $Action /sc $Frequency /d $DayOfMonth /m $MonthOfYear /st $StartTime /RL $RunLevel /F
