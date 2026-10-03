$ErrorActionPreference = 'Stop'
$rcRepo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $rcRepo 'tools/RConnect.Profile.ps1')
$rcTest = Join-Path $rcRepo ('build/launcher/profile-' + [guid]::NewGuid().ToString('N').Substring(0,10))
$rcSource = Join-Path $rcTest 'pfe2/Local Store'
$rcSaves = Join-Path $rcSource '#SharedObjects/pfe.swf'
[void](New-Item -ItemType Directory -Path $rcSaves)
foreach ($rcSlot in 0..10) { [IO.File]::WriteAllBytes((Join-Path $rcSaves ('PFEgame' + $rcSlot + '.sol')), [byte[]](0,191,$rcSlot,42)) }
[IO.File]::WriteAllText((Join-Path $rcSource 'Rconnect_config.txt'), '{"nickname":"second","port":24567,"followTeammate":"1","autoFollow":"1","autoGame":"1","autoRole":"join","autoLoadSave":"0"}')
$rcNickname = -join ([char[]](0x7B2C,0x4E8C,0x89D2,0x8272))
$rcRaw = [IO.File]::ReadAllText((Join-Path $rcSource 'Rconnect_config.txt')).Replace('second',$rcNickname)
[IO.File]::WriteAllText((Join-Path $rcSource 'Rconnect_config.txt'),$rcRaw,(New-Object Text.UTF8Encoding($false)))
[IO.File]::WriteAllText((Join-Path $rcSource 'SandevistanMod_config.txt'), "duration=123`r`ndebugtest=1`r`n")
[IO.File]::WriteAllText((Join-Path $rcSource 'RConnect.log'), 'old append-only log')
$rcBefore = @{}; Get-ChildItem -LiteralPath $rcSource -Recurse -File | ForEach-Object { $rcBefore[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName).Hash }
$rcResult = Initialize-RConnectSecondProfile -StorageRoot $rcTest
foreach ($rcSlot in 0..10) {
    $rcOld = Join-Path $rcSaves ('PFEgame' + $rcSlot + '.sol')
    $rcNew = Join-Path $rcResult.Storage ('#SharedObjects/pfe.swf/PFEgame' + $rcSlot + '.sol')
    if ((Get-FileHash -LiteralPath $rcNew).Hash -ne $rcBefore[$rcOld]) { throw ('Save copy changed slot ' + $rcSlot) }
}
$rcCfg = Get-Content -LiteralPath (Join-Path $rcResult.Storage 'Rconnect_config.txt') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($rcCfg.autoGame -ne '' -or $rcCfg.autoLoadSave -ne '' -or $rcCfg.autoRole -ne '' -or $rcCfg.nickname -ne $rcNickname -or $rcCfg.port -ne 24567 -or $rcCfg.followTeammate -ne '1' -or $rcCfg.autoFollow -ne '1') { throw 'Manual config migration failed' }
if ((Get-Content -LiteralPath (Join-Path $rcResult.Storage 'SandevistanMod_config.txt') -Raw) -notmatch 'debugtest=0') { throw 'Legacy debug driver not disabled' }
if (Test-Path -LiteralPath (Join-Path $rcResult.Storage 'RConnect.log')) { throw 'Historical log copied into new profile' }
$rcSlotOne = Join-Path $rcResult.Storage '#SharedObjects/pfe.swf/PFEgame1.sol'
[IO.File]::WriteAllText($rcSlotOne, 'new session progress')
$rcAgain = Initialize-RConnectSecondProfile -StorageRoot $rcTest
if ($rcAgain.Migrated -or (Get-Content -LiteralPath $rcSlotOne -Raw) -ne 'new session progress') { throw 'Repeated launch overwrote progress' }
foreach ($rcPath in $rcBefore.Keys) { if ((Get-FileHash -LiteralPath $rcPath).Hash -ne $rcBefore[$rcPath]) { throw 'Original profile changed' } }
$rcConflict = Join-Path $rcTest 'conflict'
[void](New-Item -ItemType Directory -Path (Join-Path $rcConflict ($script:RConnectSecondProfile+'/Local Store')))
$rcBlocked=$false
try { Initialize-RConnectSecondProfile -StorageRoot $rcConflict | Out-Null } catch { $rcBlocked=$_.Exception.Message.Contains('nothing was overwritten') }
if (-not $rcBlocked) { throw 'Unknown existing profile was not protected' }
$rcGame = (Resolve-Path -LiteralPath (Join-Path $rcRepo '../..')).Path
$rcDescriptor = Join-Path $rcGame 'mods/RConnect/tools/second_player_descriptor.xml'
$rcBlocked=$false
try { Assert-RConnectSecondClosed -GameRoot $rcGame -Processes @([pscustomobject]@{CommandLine=('"adl64.exe" "'+$rcDescriptor+'"')}) } catch { $rcBlocked=$true }
if (-not $rcBlocked) { throw 'Already-running second window was not protected' }
Assert-RConnectSecondClosed -GameRoot $rcGame -Processes @([pscustomobject]@{CommandLine='"adl64.exe" -runtime runtimes\air\win64 application.xml -nodebug'})
$rcEmpty = Initialize-RConnectSecondProfile -StorageRoot (Join-Path $rcTest 'empty')
if ($rcEmpty.Files -ne 0 -or (Get-ChildItem -LiteralPath $rcEmpty.Storage -Filter '*.sol' -Recurse).Count -ne 0) { throw 'Empty profile fabricated a save' }
@{status='passed'; saveSlots=11; originalsUnchanged=$true; repeatedLaunchPreservesProgress=$true; existingWindowBlocked=$true; conflictingStorageBlocked=$true; emptyProfileSupported=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $rcTest 'result.json') -Encoding UTF8
Write-Output ('PROFILE PASS ' + $rcTest)
