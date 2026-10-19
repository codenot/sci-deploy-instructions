param([switch]$ConfigureOnly)
$ErrorActionPreference = 'Stop'
$compatDirectory = Join-Path $PSScriptRoot 'codex-wsl-compat'
$configPath = Join-Path $env:USERPROFILE '.codex\config.toml'
$shimPath = Join-Path $compatDirectory 'wsl.exe'
if (-not (Test-Path -LiteralPath $shimPath)) { throw "Compatibility executable is missing: $shimPath" }
if (-not $ConfigureOnly) {
    $runningCodex = @(Get-Process -Name ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\OpenAI.Codex_*\app\ChatGPT.exe' })
    if ($runningCodex.Count -gt 0) { throw 'Please fully quit Codex first, including its system tray icon, then run this launcher again.' }
}
function Set-DesktopOption([string]$Text, [string]$Name, [string]$Value) {
    $section = [regex]::Match($Text, '(?ms)^\[desktop\][ \t]*\r?\n(?<body>.*?)(?=^\[|\z)')
    if (-not $section.Success) { return $Text.TrimEnd() + "`r`n`r`n[desktop]`r`n$Name = $Value`r`n" }
    $body = $section.Groups['body'].Value
    $option = [regex]::new('(?m)^[ \t]*#?[ \t]*' + [regex]::Escape($Name) + '[ \t]*=[^\r\n]*')
    $nextBody = if ($option.IsMatch($body)) { $option.Replace($body, "$Name = $Value") } else { "$Name = $Value`r`n" + $body }
    return $Text.Substring(0, $section.Index) + "[desktop]`r`n" + $nextBody + $Text.Substring($section.Index + $section.Length)
}
$before = [System.IO.File]::ReadAllText($configPath)
$after = Set-DesktopOption $before 'runCodexInWindowsSubsystemForLinux' 'true'
$after = Set-DesktopOption $after 'integratedTerminalShell' '"wsl"'
if ($before -ne $after) {
    $backupPath = $configPath + '.pre-wsl-compat-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak'
    Copy-Item -LiteralPath $configPath -Destination $backupPath
    [System.IO.File]::WriteAllText($configPath, $after, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Configuration backup: $backupPath"
}
if ($ConfigureOnly) { Write-Host 'WSL agent and terminal settings saved.'; exit 0 }
$appPackage = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
$appPath = if ($appPackage) { Join-Path $appPackage.InstallLocation 'app\ChatGPT.exe' } else { 'C:\Program Files\WindowsApps\OpenAI.Codex_26.1013.3656.0_x64__2p2nqsd0c76g0\app\ChatGPT.exe' }
if (-not (Test-Path -LiteralPath $appPath)) { throw 'The installed Codex executable could not be located.' }
# Changes below affect this launcher and its child process only; no system PATH is changed.
$env:PATH = $compatDirectory + ';' + $env:PATH
$env:CODEX_HOME = Split-Path -Parent $configPath
foreach ($entry in @('CODEX_CLI_PATH', 'CODEX_WINDOWS_REGISTERED_CORE', 'CODEX_WINDOWS_SANDBOX_PACKAGE_FAMILY', 'CODEX_APP_TOOLS_PIPE_PATH', 'NODE_REPL_HOST_SERVICES_PIPE_PATH')) {
    [Environment]::SetEnvironmentVariable($entry, $null, 'Process')
}
Start-Process -FilePath $appPath -WorkingDirectory (Split-Path -Parent $appPath) -WindowStyle Hidden | Out-Null
Write-Host 'Codex started in WSL mode with the compatibility launcher.'
