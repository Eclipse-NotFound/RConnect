# Manual player storage. The established pfe-modsettings- namespace opts out of
# MSWAutoTest's broad non-pfe auto-new-game rule. Do not rename it casually.
$script:RConnectSecondProfile = 'pfe-modsettings-rconnect-player2'

function Assert-RConnectSecondClosed {
    param([Parameter(Mandatory=$true)][string]$GameRoot,
          [object[]]$Processes = @(Get-CimInstance Win32_Process -Filter "Name='adl64.exe' OR Name='adl.exe'"))
    $rcLauncherDescriptor = [IO.Path]::GetFullPath((Join-Path $GameRoot 'mods/RConnect/tools/second_player_descriptor.xml'))
    foreach ($rcProcess in $Processes) {
        $rcCommand = [string]$rcProcess.CommandLine
        if (-not $rcCommand) { throw 'Cannot check an AIR window. Close existing AIR games before launching player two.' }
        foreach ($rcMatch in [regex]::Matches($rcCommand, '"(?<path>[^\"]+\.xml)"|(?<path>[^\s\"]+\.xml)')) {
            $rcDescriptor = $rcMatch.Groups['path'].Value
            if (-not [IO.Path]::IsPathRooted($rcDescriptor)) { $rcDescriptor = Join-Path $GameRoot $rcDescriptor }
            $rcDescriptor = [IO.Path]::GetFullPath($rcDescriptor)
            # This also recognizes an old pfe2 process whose descriptor on disk
            # was updated while it was running.
            if ($rcDescriptor -eq $rcLauncherDescriptor) {
                throw 'The second-player window is already running. Save and close it first.'
            }
            if (Test-Path -LiteralPath $rcDescriptor -PathType Leaf) {
                try { [xml]$rcXml = Get-Content -LiteralPath $rcDescriptor -Raw -Encoding UTF8 }
                catch { throw ('Cannot check AIR descriptor: ' + $rcDescriptor) }
                if ([string]$rcXml.application.id -in @('pfe2', $script:RConnectSecondProfile)) {
                    throw 'The second-player window is already running. Save and close it first.'
                }
            }
        }
    }
}

function Initialize-RConnectSecondProfile {
    param([string]$StorageRoot = $env:APPDATA)
    $rcSource = Join-Path $StorageRoot 'pfe2/Local Store'
    $rcDestination = Join-Path $StorageRoot ($script:RConnectSecondProfile + '/Local Store')
    $rcReceipt = Join-Path $rcDestination 'RConnect-profile-migration.json'
    if (Test-Path -LiteralPath $rcReceipt) {
        $rcPrevious = Get-Content -LiteralPath $rcReceipt -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($rcPrevious.profile -ne $script:RConnectSecondProfile -or $rcPrevious.schema -ne 1) { throw 'Unrecognized second-player migration receipt' }
        return [pscustomobject]@{ Storage=$rcDestination; Migrated=$false; Files=$rcPrevious.files.Count }
    }
    if (Test-Path -LiteralPath $rcDestination) {
        throw ('Second-player storage already exists without a migration receipt; nothing was overwritten: ' + $rcDestination)
    }
    # Stage all bytes first; a failed migration never appears as a usable profile.
    $rcStage = Join-Path $StorageRoot ($script:RConnectSecondProfile + '-migration-' + [guid]::NewGuid().ToString('N'))
    $rcStagedStore = Join-Path $rcStage 'Local Store'
    [void](New-Item -ItemType Directory -Path $rcStagedStore)
    $rcFiles = @()
    $rcSources = @()
    $rcShared = Join-Path $rcSource '#SharedObjects'
    if (Test-Path -LiteralPath $rcShared) { $rcSources += @(Get-ChildItem -LiteralPath $rcShared -File -Recurse) }
    if (Test-Path -LiteralPath $rcSource) {
        $rcSources += @(Get-ChildItem -LiteralPath $rcSource -File | Where-Object { $_.Name -like '*_config.txt' })
    }
    foreach ($rcFile in $rcSources) {
        $rcRelative = $rcFile.FullName.Substring($rcSource.Length + 1)
        $rcTarget = Join-Path $rcStagedStore $rcRelative
        [void](New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rcTarget))
        $rcBefore = (Get-FileHash -LiteralPath $rcFile.FullName -Algorithm SHA256).Hash
        Copy-Item -LiteralPath $rcFile.FullName -Destination $rcTarget -ErrorAction Stop
        $rcCopied = (Get-FileHash -LiteralPath $rcTarget -Algorithm SHA256).Hash
        if ($rcCopied -ne $rcBefore -or (Get-FileHash -LiteralPath $rcFile.FullName -Algorithm SHA256).Hash -ne $rcBefore) {
            throw ('Source changed during migration; original files retained. Retry after closing the game: ' + $rcFile.Name)
        }
        $rcFiles += @{path=$rcRelative; sha256=$rcCopied.ToLower()}
    }
    # Only test drivers are disabled in the new manual profile; preserve normal
    # preferences, nickname, connection details, and all SOL save bytes.
    $rcConfigPath = Join-Path $rcStagedStore 'Rconnect_config.txt'
    $rcConfig = if (Test-Path -LiteralPath $rcConfigPath) { Get-Content -LiteralPath $rcConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{nickname='Player2'} }
    foreach ($rcKey in @('autoRole','autoGame','autoLoadSave','autoMove','autoTravel','autoTravelLand','autoDamage','autoGhostDmg','autoHeal','autoHostKill','autoDeactivate','autoWalk','autoGhostAnim','autoBoxKill','autoTileBreak','autoObjSpawn','autoDoorToggle','autoBoxLoot','autoLootTest','autoLootJoin','autoBoxMove','autoBoxMoveJoin','autoDoorJoin','autoBoxLootJoin')) {
        $rcConfig | Add-Member -NotePropertyName $rcKey -NotePropertyValue '' -Force
    }
    $rcUtf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($rcConfigPath, ($rcConfig | ConvertTo-Json -Depth 8), $rcUtf8)
    $rcSandy = Join-Path $rcStagedStore 'SandevistanMod_config.txt'
    if (Test-Path -LiteralPath $rcSandy) {
        $rcText = Get-Content -LiteralPath $rcSandy -Raw -Encoding UTF8
        $rcText = [regex]::Replace($rcText, '(?im)^\s*debugtest\s*=.*$', 'debugtest=0')
        [IO.File]::WriteAllText($rcSandy, $rcText, $rcUtf8)
    }
    $rcRecord = @{schema=1; profile=$script:RConnectSecondProfile; source=$rcSource; createdUtc=[DateTime]::UtcNow.ToString('o'); files=$rcFiles; testDriversDisabled=$true}
    [IO.File]::WriteAllText((Join-Path $rcStagedStore 'RConnect-profile-migration.json'), ($rcRecord | ConvertTo-Json -Depth 6), $rcUtf8)
    $rcProfileRoot = Join-Path $StorageRoot $script:RConnectSecondProfile
    # Same-volume atomic directory move. Never merge into or overwrite a profile.
    [IO.Directory]::Move($rcStage, $rcProfileRoot)
    return [pscustomobject]@{ Storage=$rcDestination; Migrated=$true; Files=$rcFiles.Count }
}
