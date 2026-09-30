@echo off
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -File "%~dp0tools\start_coop.ps1" -Mode Pair
if errorlevel 1 pause
