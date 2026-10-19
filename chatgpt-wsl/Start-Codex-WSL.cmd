@echo off
powershell.exe -NoLogo -NoProfile -File "%~dp0Start-Codex-WSL.ps1"
if errorlevel 1 pause
