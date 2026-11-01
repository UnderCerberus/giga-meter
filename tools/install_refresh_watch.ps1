# 自動更新の見張りを、毎日12時とログオン時に動くよう登録する
# 解除: Unregister-ScheduledTask -TaskName GigaMeterRefreshWatch -Confirm:$false
$python = (Get-Command python).Source
$pythonw = Join-Path (Split-Path $python) 'pythonw.exe'
$script = Join-Path $PSScriptRoot 'refresh_watch.py'

$action = New-ScheduledTaskAction -Execute $pythonw -Argument "`"$script`""
$triggers = @(
    (New-ScheduledTaskTrigger -Daily -At 12:00),
    (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME)
)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName 'GigaMeterRefreshWatch' -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description 'ギガメーターの自動更新が止まっていたら通知する' -Force | Out-Null
Get-ScheduledTask -TaskName 'GigaMeterRefreshWatch' | Select-Object TaskName, State
