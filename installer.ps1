function Test-Admin {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    $vbscript = "$env:TEMP\run_as_admin.vbs"
    $ps1Path = $MyInvocation.MyCommand.Path
    $content = @"
Set objShell = CreateObject("Shell.Application")
objShell.ShellExecute "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`"", "", "runas", 1
"@
    $content | Set-Content -Path $vbscript
    Start-Process "wscript.exe" -ArgumentList $vbscript
    exit
}

$TaskName = "RegistryUpdate"
$DownloadsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Загрузки")
$RegFilePath = Get-ChildItem -Path $DownloadsPath -Filter "Windows_parametr_base.reg" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if ($RegFilePath) {
    $CurrentUser = $env:USERNAME
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    $Action = New-ScheduledTaskAction -Execute "regedit.exe" -Argument "/s `"$RegFilePath`""
    $Trigger = New-ScheduledTaskTrigger -AtLogon -User $CurrentUser
    $Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive -RunLevel Highest
    $Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Description "Автоматическое обновление реестра"
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task
    Start-ScheduledTask -TaskName $TaskName
}

$Programs = @(
    "Google.Chrome",
    "Microsoft.VisualStudioCode",
    "7zip.7zip",
    "Git.Git",
    "Mozilla.Firefox"
)

foreach ($program in $Programs) {
    winget install --id $program --silent --accept-source-agreements --accept-package-agreements
}

Write-Output "Установка завершена!"