@echo off
setlocal
for %%I in ("%~dp0..\..\..") do set "RC_B_ROOT=%%~fI"
set "RC_B_GAME=%RC_B_ROOT%\mods\RConnect\build\ab\b3-playable-190\game"
set "RC_B_HOST=%RC_B_ROOT%\adl64.exe"
if not exist "%RC_B_HOST%" goto missing
if not exist "%RC_B_GAME%\player-1.xml" goto missing
if not exist "%RC_B_GAME%\player-2.xml" goto missing
if not exist "%RC_B_GAME%\mods\RConnect\release\RConnectMod.swf" goto missing
rem Use the verified host without changing executable labels or system policy.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -Command "try { $sha = [System.Security.Cryptography.SHA256]::Create(); try { $actual = [System.BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($env:RC_B_HOST))).Replace('-',''); if ($actual -ne 'D851EB9E68D38ABD335916DD91E08DE3F1660945B49F382691A188ADC7C8C295') { exit 2 } } finally { $sha.Dispose() } } catch { [System.Console]::Error.WriteLine($_.Exception.Message); exit 3 }"
if errorlevel 3 goto unreadable
if errorlevel 1 goto changed
if /i "%~1"=="check" (
  echo RConnect B: launcher paths and AIR host verified.
  echo %RC_B_GAME%
  exit /b 0
)
if "%~1"=="1" goto one
if "%~1"=="2" goto two
if /i "%~1"=="both" goto both
echo Usage: launch-b.cmd 1 ^| 2 ^| both ^| check
exit /b 2
:both
call :player 1
call :player 2
exit /b 0
:one
call :player 1
exit /b 0
:two
call :player 2
exit /b 0
:player
start "RConnect B Player %1" /D "%RC_B_GAME%" "%RC_B_HOST%" -runtime "%RC_B_GAME%\runtimes\air\win64" "%RC_B_GAME%\player-%1.xml" -nodebug
exit /b 0
:missing
echo RConnect B package is missing. Please keep the complete B test package.
if /i "%~1"=="check" exit /b 1
pause
exit /b 1
:changed
echo The AIR host changed. Please update and verify the B launcher before running.
if /i "%~1"=="check" exit /b 2
pause
exit /b 2
:unreadable
echo Could not verify the AIR host. Please check the message above.
if /i "%~1"=="check" exit /b 3
pause
exit /b 3
