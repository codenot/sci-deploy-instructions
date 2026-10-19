$ErrorActionPreference = 'Stop'
$configPath = Join-Path $env:USERPROFILE '.codex\config.toml'
$text = [System.IO.File]::ReadAllText($configPath)
$next = [regex]::Replace($text, '(?m)^[ \t]*#?[ \t]*runCodexInWindowsSubsystemForLinux[ \t]*=[^\r\n]*', 'runCodexInWindowsSubsystemForLinux = false')
$next = [regex]::Replace($next, '(?m)^[ \t]*#?[ \t]*integratedTerminalShell[ \t]*=[^\r\n]*', 'integratedTerminalShell = "powershell"')
if ($next -ne $text) {
    Copy-Item -LiteralPath $configPath -Destination ($configPath + '.before-windows-restore-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak')
    [System.IO.File]::WriteAllText($configPath, $next, (New-Object System.Text.UTF8Encoding($false)))
}
Write-Host 'Windows mode restored. Fully quit Codex, then launch it normally.'
