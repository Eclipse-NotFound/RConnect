param([ValidateSet('Pair','Main','Second')][string]$Mode='Pair')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'RConnect.Process.ps1')
. (Join-Path $PSScriptRoot 'RConnect.Profile.ps1')
$rcRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$rcLock = New-Object Threading.Mutex($false, 'Local\RConnectManualLauncher')
$rcLocked = $false
try {
    $rcLocked = $rcLock.WaitOne(0)
    if (-not $rcLocked) { throw '另一个合作启动器正在启动，请稍后再试。' }
    if ($Mode -ne 'Main') {
        Assert-RConnectSecondClosed -GameRoot $rcRoot
        $rcProfile = Initialize-RConnectSecondProfile
        if ($rcProfile.Migrated) { Write-Host '已继承第二角色的存档和设置，旧档仍然保留。' }
    }
    $rcMod = Get-Item -LiteralPath (Join-Path $rcRoot 'mods/RConnect/release/RConnectMod.swf')
    $rcHash = (Get-FileHash -LiteralPath $rcMod.FullName -Algorithm SHA256).Hash.Substring(0,12).ToLower()
    Write-Host ('本次使用游戏目录：' + $rcRoot)
    Write-Host ('RConnect 文件更新于 ' + $rcMod.LastWriteTime.ToString('yyyy-MM-dd HH:mm') + '，校验码 ' + $rcHash + '。游戏内 F10 可查看版本。')
    if ($Mode -ne 'Second') {
        $rcMain = Start-RConnectWindow -GameRoot $rcRoot -Descriptor (Join-Path $rcRoot 'application.xml')
        Write-Host ('主窗口已启动，进程 ' + $rcMain.Id + '。')
    }
    if ($Mode -ne 'Main') {
        $rcSecond = Start-RConnectWindow -GameRoot $rcRoot -Descriptor (Join-Path $PSScriptRoot 'second_player_descriptor.xml')
        Write-Host ('第二窗口已启动，进程 ' + $rcSecond.Id + '。')
    }
    Write-Host '在读档列表选择第二角色；若停在主菜单，请点“载入游戏”。载入双方角色后，按 F10 开房或加入。'
    Write-Host '本次启动保持游戏在后台的运行速度，可能增加耗电；退出游戏后自动结束。'
} catch {
    Write-Host ('未能完成启动：' + $_.Exception.Message)
    Write-Host '请保存并关闭已运行的对应游戏窗口，再使用本入口。'
    exit 1
} finally {
    if ($rcLocked) { $rcLock.ReleaseMutex() }
    $rcLock.Dispose()
}
