#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_release.py — 打包 RConnect 安装包（面向普通玩家的 zip）。

产物：mods/Rconnect/build/RConnect-v<VERSION>.zip
内容（解压到游戏文件夹根目录即可）：
  INSTALL.txt            安装+联机傻瓜说明
  pfe.swf                已补丁游戏文件（1.02）
  DLC/pfe.swf            已补丁（1.03）
  DLC/pfeUI.swf          已补丁（1.04）
  mods/Rconnect/         模组本体（release SWF + config + README）

说明：三份游戏 SWF 取自当前游戏目录（已含各模组加载器）；干净文件夹里
没有其他模组时，对应加载器只会 trace 错误、不影响游戏（补丁模板带
IOError 处理，见 patch_game_swfs.py）。
"""

import os
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(HERE)                       # mods/Rconnect/
GAME_ROOT = os.path.normpath(os.path.join(MOD_ROOT, "..", ".."))  # 游戏根目录

VERSION = "0.1.0"


def main():
    out = os.path.join(MOD_ROOT, "build", "RConnect-v%s.zip" % VERSION)
    items = [
        (os.path.join(MOD_ROOT, "INSTALL.txt"), "INSTALL.txt"),
        (os.path.join(GAME_ROOT, "pfe.swf"), "pfe.swf"),
        (os.path.join(GAME_ROOT, "DLC", "pfe.swf"), "DLC/pfe.swf"),
        (os.path.join(GAME_ROOT, "DLC", "pfeUI.swf"), "DLC/pfeUI.swf"),
        (os.path.join(MOD_ROOT, "README.md"), "mods/Rconnect/README.md"),
        (os.path.join(MOD_ROOT, "release", "RConnectMod.swf"),
         "mods/Rconnect/release/RConnectMod.swf"),
        (os.path.join(MOD_ROOT, "release", "config.txt"),
         "mods/Rconnect/release/config.txt"),
    ]
    missing = [s for s, _ in items if not os.path.exists(s)]
    if missing:
        print("make_release: missing files:")
        for m in missing:
            print("  " + m)
        raise SystemExit(1)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for src, arc in items:
            z.write(src, arc)
    print("make_release: OK -> %s (%d bytes)" % (out, os.path.getsize(out)))


if __name__ == "__main__":
    main()
