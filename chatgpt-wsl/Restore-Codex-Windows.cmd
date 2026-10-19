@echo off
powershell.exe -NoLogo -NoProfile -File "%~dp0Restore-Codex-Windows.ps1"
if errorlevel 1 pause
