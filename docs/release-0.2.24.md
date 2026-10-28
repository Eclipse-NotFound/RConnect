# A 0.2.24-animfix3-l10n

This is an A prerelease, not B architecture. The runtime package contains only RConnect, its existing local co-op launcher, documentation and hashes. Personal settings, saves, game SWFs, native assets and other mods are excluded.

## Changes

- Complete UI coverage for the game's nine languages: English, Russian, Ukrainian, Simplified Chinese, Traditional Chinese, Polish, German, Spanish and Japanese. Native aliases are recognized; unsupported language codes fall back to English.
- One editable translation catalog for the panel, settings, shortcut registration and connection/room notices. Switches follow the local game language. Nicknames, addresses, chat, protocol IDs and saves are unchanged.
- Fixed controls fit long labels; long explanations retain the panel's existing scrolling behavior. Text fitting reuses its previous result while a label is unchanged.
- Includes the deployed animfix3 fixes: native enemy weapon reflection and melee poses, speech bubbles, telekinetic collision damage-number delivery, and prevention of false wood fragments during rapid door toggles. Special projectiles interpolate between confirmed samples without extending their lifetime.

## Verification and limits

The language catalog contains **117 messages × 9 languages = 1,053 translations**. Coverage, placeholders and line breaks were checked before compilation. The exact release SWF was then loaded in isolated, muted host/join instances on Windows / Remains 1.02 with only RConnect enabled. Each side passed **1,181 checks**, including language changes, aliases, composed switches, literal player placeholders, unmodified chat/input and fixed-control fit. The four panel tabs, help and scrolling settings were inspected. No native declaration classes or test drivers are embedded in the 85-class product.

Eighty gameplay source files are byte-identical to the deployed animfix3 baseline. Its matching targeted weapon, door, speech/impact feedback and projectile checks are reused, not presented as a new full gameplay regression. The previous visual checks did not establish an overall frame-rate improvement: ordinary bullets can still stutter when whole frames stall. Dense combat, room-load delays and some historical room/interaction edge cases remain open. The exact user's E-key throw path and every installed mod combination are not newly qualified by this release.

Some security-terminal and room-generation features require compatible hooks in the game's patched host. The package does not replace `pfe.swf`; an unsupported security hook is reported in the panel. The complete current local host combination is not supplied by this ZIP. Internet play, stable reconnection, more than two players and other game versions are not guaranteed. Translations were checked for coverage and rendering, but have not had independent native-speaker review in every language.

Use the same release on both sides, preserve your settings, and fully restart after updating. Restore the previous mod directory, scan and restart to roll back. `SHA256.json` verifies package contents; `mods/RConnect/BUILD.json` records the compiled source and artifact hashes. Source is at the corresponding Git tag; build instructions are in `docs/BUILD-A.md`.

## 中文说明

本版补齐游戏内九种语言，含浮窗、设置、快捷键和连接／房间提示。117 条文本、1,053 项译文覆盖与占位符检查通过；正式产物在独立静音双实例中各通过 1,181 项检查。昵称、聊天、地址和存档不参与翻译。固定按钮适配长译文，长说明在原浮窗内部滚动。各语言尚未全部经过独立母语审校。

80 个玩法类与已部署 animfix3 源码逐字节一致，沿用其相应定向验证。敌人武器翻转／近战姿态、话语、念力撞击数字、快速开关门错误碎屑等修正已纳入。密集场景和整帧停顿仍可能造成弹道卡顿；不宣称本次解决所有加载、交互或性能问题，也未重新覆盖用户特定 E 键抛掷路径与全部第三方模组组合。

本包不包含 B、游戏本体或其他模组。部分安保／房间功能需要配套的游戏宿主接口；缺失接口时可能不可用，安保设置会显示提示。当前本机完整宿主组合不随 ZIP 分发。双方安装同版、保留配置并重启；回退时恢复旧模组、扫描、重启。
