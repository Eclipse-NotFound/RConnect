param([ValidateSet('Pair','Main','Second')][string]$Mode='Pair')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'RConnect.Process.ps1')
$rcRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
try {
    if ($Mode -ne 'Second') {
        $rcMain = Start-RConnectWindow -GameRoot $rcRoot -Descriptor (Join-Path $rcRoot 'application.xml')
        Write-Host ('主窗口已启动，进程 ' + $rcMain.Id + '。')
    }
    if ($Mode -ne 'Main') {
        $rcSecond = Start-RConnectWindow -GameRoot $rcRoot -Descriptor (Join-Path $PSScriptRoot 'second_player_descriptor.xml')
        Write-Host ('第二窗口已启动，进程 ' + $rcSecond.Id + '。')
    }
    Write-Host '分别载入角色后，按 F10 开房或加入。第二窗口沿用自己的存档，不复制覆盖主角色。'
    Write-Host '本次启动保持游戏在后台的运行速度，可能增加耗电；退出游戏后自动结束。'
} catch {
    Write-Host ('未能完成启动：' + $_.Exception.Message)
    Write-Host '请保存并关闭已运行的对应游戏窗口，再使用本入口。'
    exit 1
}
