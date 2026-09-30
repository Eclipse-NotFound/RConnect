param([Parameter(Mandatory=$true)][int]$OwnedProcessId,
      [Parameter(Mandatory=$true)][string]$Descriptor)
$ErrorActionPreference = 'Stop'
# The runner passes only the PID it just created. Verify the unique descriptor
# as well, so a stale or incorrect PID can never select a user's game.
$rcDescriptor = (Resolve-Path -LiteralPath $Descriptor).Path
[xml]$rcXml = Get-Content -LiteralPath $rcDescriptor -Raw
$rcAppId = [string]$rcXml.application.id
if ($rcAppId -notmatch '^pfe-(modsettings-)?rconnect-coop-(host|join)-[a-f0-9]{10}$') { throw 'Not an isolated RConnect test profile' }
$rcInfo = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $OwnedProcessId)
if (-not $rcInfo -or $rcInfo.Name -ne 'adl64.exe' -or
    -not $rcInfo.CommandLine.Contains('"' + $rcDescriptor + '"')) { throw 'PID does not belong to this test descriptor' }
. (Join-Path $PSScriptRoot 'RConnect.Process.ps1')
$rcProcess = Get-Process -Id $OwnedProcessId
$rcState = [RConnectLauncher.NativePower]::KeepResponsive($rcProcess)
@{pid=$OwnedProcessId; control=$rcState.ControlMask; state=$rcState.StateMask} | ConvertTo-Json -Compress
