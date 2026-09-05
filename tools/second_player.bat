@echo off
setlocal
rem ============================================================
rem  RConnect second player launcher (join window, app id pfe2)
rem  - mirrors saves (READ-ONLY copy) from the main profile so
rem    the load menu shows your existing saves
rem  - the second window is a TEST instance: its own progress
rem    is overwritten by the fresh mirror on next launch
rem  - main game window must be hosting on port 23456 first
rem ============================================================
cd /d "%~dp0..\..\.."
echo [1] game root: %CD%

rem -- kill stale second window (matches ONLY this descriptor, never the main game)
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='adl64.exe'\" | Where-Object { $_.CommandLine -match 'app_rconnect_test_pfe2' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1

rem -- temp descriptor (content = root pfe.swf, same as main window)
if not exist "app_rconnect_test_pfe2.xml" copy /y "mods\RConnect\tools\second_player_descriptor.xml" "app_rconnect_test_pfe2.xml" >nul
if not exist "app_rconnect_test_pfe2.xml" (echo [2] descriptor MISSING & goto :fail)
echo [2] descriptor ok

rem -- mirror saves from main profile (read-only source)
set "SRC=%APPDATA%\pfe\Local Store\#SharedObjects\pfe.swf"
set "DST=%APPDATA%\pfe2\Local Store\#SharedObjects\pfe.swf"
if not exist "%DST%" mkdir "%DST%" 2>nul
set N=0
if exist "%SRC%\PFEgame0.sol" (
  copy /y "%SRC%\PFEgame*.sol" "%DST%\" >nul
  copy /y "%SRC%\config.sol" "%DST%\" >nul 2>&1
  for %%F in ("%SRC%\PFEgame*.sol") do set /a N+=1
)
if %N%==0 (
  echo [3] WARNING: no saves found in main profile, load menu will be empty
) else (
  echo [3] mirrored %N% save slots from main profile
)

rem -- join config
if not exist "%APPDATA%\pfe2\Local Store" mkdir "%APPDATA%\pfe2\Local Store"
> "%APPDATA%\pfe2\Local Store\Rconnect_config.txt" echo {"nickname":"Player2","hostIp":"127.0.0.1","port":23456,"tickMs":50,"autoRole":"","autoGame":"","autoFollow":"1","freezeAI":"1","worldInject":"1","ghostCombat":"1"}
echo [4] join config written (host 127.0.0.1:23456)

start "Remains-Player2" "adl64.exe" -runtime "runtimes\air\win64" "app_rconnect_test_pfe2.xml"
echo [5] second window started - load your save from the menu, then F10 to join
goto :eof

:fail
echo second player launch FAILED
exit /b 1
