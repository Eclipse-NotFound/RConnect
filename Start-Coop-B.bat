@echo off
chcp 65001 >nul
title RConnect B - Start Coop
call "%~dp0tools\launch-b.cmd" both
if errorlevel 1 pause
