@echo off
setlocal
cd /d "%~dp0..\..\.."
echo [1] CD=%~dp0..\..\..
if not exist "app_rconnect_test_pfe2.xml" (
  copy /y "mods\Rconnect\tools\second_player_descriptor.xml" "app_rconnect_test_pfe2.xml" >nul
)
if exist "app_rconnect_test_pfe2.xml" (echo [2] descriptor ok) else (echo [2] descriptor MISSING)
if not exist "%APPDATA%\pfe2\Local Store" mkdir "%APPDATA%\pfe2\Local Store" 2>nul
> "%APPDATA%\pfe2\Local Store\Rconnect_config.txt" echo {"nickname":"Player2","hostIp":"127.0.0.1","port":23456,"tickMs":50,"autoRole":"","autoGame":"","autoFollow":"1","freezeAI":"1","worldInject":"1","ghostCombat":"1"}
echo [3] config written
start "Remains-Player2" "adl64.exe" -runtime "runtimes\air\win64" "app_rconnect_test_pfe2.xml"
echo [4] start issued
