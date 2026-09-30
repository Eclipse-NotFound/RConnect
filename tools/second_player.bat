@echo off
chcp 65001 >nul
rem Persistent second profile; never overwrite saves or close existing games.
rem For both windows to keep running smoothly in the background, use Start-Coop.bat.
powershell.exe -NoLogo -NoProfile -File "%~dp0start_coop.ps1" -Mode Second
if errorlevel 1 pause
