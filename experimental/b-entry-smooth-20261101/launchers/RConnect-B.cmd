@echo off
chcp 65001 >nul
title RConnect B - 双人测试
echo.
echo  RConnect B 双人测试 - B3-0.1-entry1
echo  -------------------------------------------------
echo  1. 启动玩家 1
echo  2. 启动玩家 2
echo  B. 同时启动两名玩家
echo  Q. 退出
echo.
echo  两边分别载入角色，再创建或加入房间。
echo  默认地址 127.0.0.1，端口 23457。
echo  沿用原 B 版存档；任一玩家都可以创建房间。
echo.
choice /c 12BQ /n /m "请选择 [1 / 2 / B / Q]："
if errorlevel 4 exit /b 0
if errorlevel 3 (call "%~dp0mods\RConnect\tools\launch-b.cmd" both & exit /b)
if errorlevel 2 (call "%~dp0mods\RConnect\tools\launch-b.cmd" 2 & exit /b)
call "%~dp0mods\RConnect\tools\launch-b.cmd" 1
