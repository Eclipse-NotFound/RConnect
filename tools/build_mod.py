#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_mod.py — 用 AIR SDK（flexsdk amxmlc）编译 RConnect 模组 SWF。

产物：mods/Rconnect/release/RConnectMod.swf
编译目标：swf-version 38 / AIR 27+（flexsdk air-config 默认值），
游戏运行时是 AIR 30（支持 swf-version ≤ 39），兼容。
模组使用 AIR 专属 API（ServerSocket / flash.filesystem.File），
因此必须走 amxmlc（air-config），不能用纯 FP 的 mxmlc 配置。
"""

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(HERE)   # mods/Rconnect/

DEFAULT_AMXMLC = r"C:\Users\micha\Documents\_sandevistan_dev\flexsdk\bin\amxmlc.bat"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--amxmlc", default=DEFAULT_AMXMLC)
    ap.add_argument("--debug", action="store_true",
                    help="编译 debug 版本（含调试信息）")
    args = ap.parse_args()

    src_dir = os.path.join(MOD_ROOT, "src")
    out_dir = os.path.join(MOD_ROOT, "release")
    os.makedirs(out_dir, exist_ok=True)
    out_swf = os.path.join(out_dir, "RConnectMod.swf")

    cmd = [
        args.amxmlc,
        "-source-path=" + src_dir,
        "-output=" + out_swf,
        "-debug=" + ("true" if args.debug else "false"),
        "-optimize=" + ("false" if args.debug else "true"),
        "-warnings=true",
        # 主类是 RConnectDoc（空 Sprite，避免 #2023）；RConnectMod 是普通类，
        # 加载契约通过 getDefinition("RConnectMod") 查找它。
        os.path.join(src_dir, "RConnectDoc.as"),
    ]
    print("build_mod: " + " ".join(cmd), flush=True)
    # amxmlc.bat 需要 AIR_HOME 指向含 frameworks/libs/air/airglobal.swc 的 SDK 根
    env = dict(os.environ)
    env["AIR_HOME"] = os.path.normpath(os.path.join(
        os.path.dirname(args.amxmlc), ".."))
    r = subprocess.run(cmd, env=env)
    if r.returncode != 0:
        print("build_mod: 编译失败", file=sys.stderr)
        sys.exit(r.returncode)
    size = os.path.getsize(out_swf) if os.path.exists(out_swf) else 0
    print("build_mod: OK -> %s (%d bytes)" % (out_swf, size))


if __name__ == "__main__":
    main()
