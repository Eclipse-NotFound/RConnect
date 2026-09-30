param([Parameter(Mandatory=$true)][string]$TemplateRun)
$ErrorActionPreference='Stop'
$rcRepo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
$rcGame=(Resolve-Path -LiteralPath (Join-Path $rcRepo '../..')).Path
$rcCopies=(Resolve-Path -LiteralPath (Join-Path $rcRepo ('build/cooperation/'+$TemplateRun))).Path
if (-not $rcCopies.StartsWith((Join-Path $rcRepo 'build/cooperation')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Outside test copies' }
. (Join-Path $rcRepo 'tools/RConnect.Process.ps1')
$rcToken=[guid]::NewGuid().ToString('N').Substring(0,10)
$rcFolder=Join-Path (Join-Path $rcRepo 'build/m39') ('launcher-'+$rcToken)
[void](New-Item -ItemType Directory -Path $rcFolder)
$rcProcesses=@();$rcResults=@()
try {
    foreach ($rcRole in @('host','join')) {
        $rcRoot=Join-Path $rcCopies $rcRole
        # Descriptor outside the app root, as used by the player-2 launcher.
        [xml]$rcXml=Get-Content -LiteralPath (Join-Path $rcRoot 'coop.xml') -Raw
        $rcAppId='pfe-modsettings-rconnect-coop-'+$rcRole+'-'+$rcToken
        $rcXml.application.id=$rcAppId
        $rcDescriptor=Join-Path $rcFolder ($rcRole+'.xml')
        $rcXml.Save($rcDescriptor)
        $rcProcess=Start-RConnectWindow -GameRoot $rcRoot -Descriptor $rcDescriptor -AdlPath (Join-Path $rcGame 'adl64.exe')
        $rcProcesses+=,$rcProcess
        $rcState=[RConnectLauncher.NativePower]::Read($rcProcess)
        if (($rcState.ControlMask -band 1) -eq 0 -or ($rcState.StateMask -band 1) -ne 0) { throw 'HighQoS not applied' }
        $rcResults+=@{role=$rcRole;pid=$rcProcess.Id;appid=$rcAppId;control=$rcState.ControlMask;state=$rcState.StateMask}
        if ($rcRole -eq 'host') { Start-Sleep -Seconds 15 }
    }
    $rcDeadline=[DateTime]::UtcNow.AddSeconds(70)
    do {
        $rcReady=$true
        foreach ($rcResult in $rcResults) {
            $rcLog=Join-Path $env:APPDATA ($rcResult.appid+'/Local Store/RConnect.log')
            $rcText=if (Test-Path -LiteralPath $rcLog) { Get-Content -LiteralPath $rcLog -Raw } else { '' }
            if (-not $rcText.Contains('v0.2.11-dev initialized') -or -not $rcText.Contains('tick 200') -or
                ($rcResult.role -eq 'join' -and -not $rcText.Contains('welcome id='))) { $rcReady=$false }
        }
        if (-not $rcReady) { Start-Sleep -Seconds 1 }
    } until ($rcReady -or [DateTime]::UtcNow -gt $rcDeadline)
    if (-not $rcReady) { throw 'Launcher did not reach two working game instances' }
    $rcDuplicateRejected=$false
    try { [void](Start-RConnectWindow -GameRoot (Join-Path $rcCopies 'join') -Descriptor (Join-Path $rcFolder 'join.xml') -AdlPath (Join-Path $rcGame 'adl64.exe')) }
    catch { if ($_.Exception.Message.Contains('already running')) { $rcDuplicateRejected=$true } else { throw } }
    if (-not $rcDuplicateRejected -or $rcProcesses[1].HasExited) { throw 'Duplicate launch safety failed' }
    @{status='passed';profiles=$rcResults;duplicate_rejected=$rcDuplicateRejected;root_directory='external descriptor';
      process_helper_sha256=(Get-FileHash -LiteralPath (Join-Path $rcRepo 'tools/RConnect.Process.ps1') -Algorithm SHA256).Hash.ToLower()} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $rcFolder 'result.json') -Encoding UTF8
    Write-Output ('LAUNCHER PASS '+$rcFolder)
} finally {
    foreach ($rcProcess in $rcProcesses) { if (-not $rcProcess.HasExited) { $rcProcess.Kill();$rcProcess.WaitForExit() };$rcProcess.Dispose() }
    foreach ($rcResult in $rcResults) {
        $rcLog=Join-Path $env:APPDATA ($rcResult.appid+'/Local Store/RConnect.log')
        if (Test-Path -LiteralPath $rcLog) { Copy-Item -LiteralPath $rcLog -Destination (Join-Path $rcFolder ($rcResult.role+'.log')) }
    }
}
