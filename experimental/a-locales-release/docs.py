from pathlib import Path
import json
RC=Path(__file__).resolve().parents[2];ROOT=RC/'build/github-a-release'
VERSION='0.2.24-animfix3-l10n'
for name in ['README.md','README.zh-CN.md','INSTALL.txt']:
    p=ROOT/name;s=p.read_text('utf8').replace('0.2.22-dev',VERSION)
    p.write_text(s,encoding='utf8')
p=ROOT/'README.md';s=p.read_text('utf8')
start=s.index('> **A architecture');end=s.index('\n\n',start)
s=s[:start]+'> **Current A architecture, with nine-language UI.** This prerelease includes the deployed animfix3 repairs and the localization update. It does not contain B architecture. Dense scenes can still stall; this release does not claim to resolve every animation or performance issue.'+s[end:]
start=s.index('## Before you start')
s=s[:start]+'''## Languages and this update

The panel, settings, shortcuts and connection/room notices follow the game's language setting: **English, Русский, Українська, 简体中文, 繁體中文, Polski, Deutsch, Español and 日本語**. You can switch language without restarting the mod. Nicknames and chat messages are never translated. Long hints remain inside the scrolling panel.

This build also includes A's native enemy weapon reflection/melee poses, enemy speech, telekinetic impact damage numbers and rapid door-toggle fixes. Special projectile motion interpolates confirmed samples; occasional whole-frame stalls remain. [Validation and known limits](docs/release-0.2.24.md).

'''+s[start:]
s=s.replace('The controls above are based on the [v0.2.8 source](https://github.com/Eclipse-NotFound/RConnect/tree/v0.2.8). Current repository source may contain fixes not yet packaged; see [src/](src/) and [state/](state/).', 'The release tag contains the exact A source in [src/](src/), the editable [language catalog](locales/messages.json), and a [reproducible build guide](docs/BUILD-A.md). Local B experiments are excluded from this release.')
# Replace stale links/claims while preserving the current remote installation guide.
s=s.replace('This is the unchanged build deployed locally on 2026-10-09, now available on GitHub.','')
p.write_text(s,encoding='utf8')
p=ROOT/'README.zh-CN.md';s=p.read_text('utf8');lines=s.splitlines();lines=[line for line in lines if not line.startswith('> **')];s='\n'.join(lines)+'\n'
position=s.find('\n## ')
s=s[:position]+'''\n> **当前 A 架构九语言预发布版。** 包含已部署 animfix3 修复与本轮翻译更新，不含 B 实验架构。密集场景仍可能停顿，不宣称解决全部动画和性能问题。

## 语言与本次更新

浮窗、设置、快捷键及连接／房间提示跟随游戏语言，支持 **简体中文、繁體中文、English、Русский、Українська、Polski、Deutsch、Español、日本語**。切换无需重启模组，昵称和聊天原文保持不变，长说明仍在浮窗内部滚动。

本包也纳入 A 版敌人武器翻转与近战姿态、敌人话语、念力撞击伤害数字、快速开关门错误碎屑等修复。特殊弹道在已确认的位置之间平滑显示，但整体帧停顿仍可能使普通子弹卡顿。详见[验证与已知限制](docs/release-0.2.24.md)。
'''+s[position:]
p.write_text(s,encoding='utf8')
(ROOT/'INSTALL.txt').write_text(f'''RConnect A {VERSION} — Windows / Remains 1.02

九语言预发布版 / Nine-language prerelease (A architecture)

1. 双方保存退出并备份旧 mods/RConnect。
2. 首次安装先完成 ModLoader 的游戏补丁及扫描器安装：
   https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md
3. 合并本包 mods 文件夹到游戏根目录，不要套成 mods/mods。
4. 运行 mods/ModLoader/RemainsModScanner.exe，重新启动双方游戏。
5. F10 显隐浮窗，展开后创建／加入；默认端口 23456。
   同机地址 127.0.0.1，不同电脑使用宿主局域网地址。
6. Ctrl+Enter 打开聊天，Enter 发送，Esc 收起；快捷键可在兼容的设置页修改。

本机双开：mods/RConnect/Start-Coop.bat。双方分别载入、保存角色。
本包不含个人 config.txt、存档、游戏本体或其他模组，更新不会覆盖它们。
游戏语言菜单可切换九种模组界面语言；不会翻译昵称或聊天原文。
密集场景、普通子弹与房间加载仍有待优化；不承诺全部卡顿已消失。
部分安保／房间能力依赖兼容的游戏宿主接口。缺少接口时可能不可用；
本包不会替换游戏 pfe.swf。完整限制见 docs/release-0.2.24.md。
回退：双方保存退出，恢复备份模组、重新扫描并重启。

English:
Install ModLoader first, then merge this ZIP's mods folder into the game folder.
Run the ModLoader scanner and restart BOTH games with the same RConnect version.
F10 opens the panel. Host/Join use port 23456 by default. 127.0.0.1 is local only;
on another computer, enter the host's LAN IPv4 address. Ctrl+Enter opens chat.
Keep personal settings and saves. For same-PC co-op, use mods/RConnect/Start-Coop.bat.
All nine native game languages are supported in the mod UI. This prerelease does
not guarantee dense-scene performance, Internet play, reconnection, 3+ players,
other game versions or every host/mod combination. No game SWF is included.
Restore your backup, scan and restart to roll back. See the included README.
''',encoding='utf8')
(ROOT/'docs/BUILD-A.md').write_text('''# Build the released A version

The canonical release source is `src/`, not a build cache or B experiment. The language catalog is `locales/messages.json`; `tools/generate_locales.py` generates its embedded AS3 form and checks all nine languages, placeholders and line breaks.

Requirements: Python 3.9+, Java 11+, Apache Flex with an AIR SDK installed in the same SDK directory. SDKs, game files and native assets are not included.

```powershell
python tools/generate_locales.py --check
python tools/build_a.py --sdk C:/Tools/FlexAIR --java C:/Tools/Java/bin/java.exe
```

Output: `build/a-release/RConnectMod.swf`, compile log, source/declaration hashes and SWF SHA256 in `manifest.json`. Use a new `--output` directory for each build. This never installs the output. `tools/stubs/` contains compile-only native declarations; they are externally linked and must never become runtime game replacements.

To edit translations, update all nine values in the JSON, run the generator without `--check`, then rebuild. Native aliases `uk/ja/zh-TW/zh-Hant` map to the game's `ua/jp/tw` IDs. Unknown language codes use English. Player-authored text is passed through untouched. Fixed labels shrink only when needed; explanations scroll inside the compact panel.

Historical build/patch scripts predate this source and are not the release build entry. Do not run them against installed game files. The package script accepts an already validated SWF and checks it against its manifest.
''',encoding='utf8')
(ROOT/'.gitattributes').write_text('# Exact released A source bytes; do not rewrite CRLF at checkout.\nsrc/** -text\ntools/stubs/** -text\nlocales/** -text\n',encoding='utf8')
print('Release docs updated')
