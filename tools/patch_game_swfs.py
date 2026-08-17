#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
patch_game_swfs.py — 给补丁后的游戏 SWF 加装 RConnect 模组加载器。

背景
====
游戏目录中的三份游戏 SWF（1.02 pfe.swf / 1.03 DLC/pfe.swf / 1.04 DLC/pfeUI.swf）
已被 Sandevistan 补丁过：MainFE 里有一个单模组加载器，只加载

    app:/mods/Sandevistan/release/SandevistanMod.swf

并调用 getDefinition("SandevistanMod").init(main)。

本脚本在该加载器旁边再加装一个独立的 RConnect 加载器：

    app:/mods/Rconnect/release/RConnectMod.swf
    getDefinition("RConnectMod").init(main)

两个加载器互不影响：任一模组加载失败只会 trace 错误，不会阻断游戏。

原理
====
1. 用 ffdec-cli 从目标 SWF 导出脚本源码；
2. 用锚点文本把 RConnect 加载代码插入 MainFE.as；
3. 用 ffdec-cli -importScript 把修改后的 MainFE 重新编译回 SWF；
4. 再次导出校验：RConnectMod 与 SandevistanMod 两个标记必须同时存在。

注意：游戏 SWF 归 Sandevistan 部署同步管理，其 sync 可能覆盖本补丁。
被覆盖后重跑本脚本即可恢复（脚本幂等：已打补丁的文件会跳过）。
每次修改前都会自动备份原文件到 mods/Rconnect/build/backup/。

授权记录
========
用户于 2026-08-15 明确授权本模组 agent 修改游戏目录中的三份补丁后 SWF
（见 mods/Rconnect/state/current-status.md）。补丁只做“追加加载器”，
不改变 Sandevistan 加载路径与调用方式，不改动游戏逻辑。
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(HERE)                    # mods/Rconnect/
GAME_ROOT = os.path.normpath(os.path.join(MOD_ROOT, "..", ".."))  # 游戏根目录

DEFAULT_FFDEC = r"C:\Users\micha\Documents\_sandevistan_dev\ffdec\ffdec-cli.exe"

DEFAULT_TARGETS = [
    "pfe.swf",          # 1.02
    "DLC/pfe.swf",      # 1.03（当前启动链）
    "DLC/pfeUI.swf",    # 1.04
]

# ---- MainFE.as 源码补丁 -------------------------------------------------

FIELD_ANCHOR = "      internal var sandyLoader:Loader;"
FIELD_ADD = "      internal var rconnectLoader:Loader;"

CALL_ANCHOR = "            this.loadSandevistanMod();"
CALL_ADD = "            this.loadRConnectMod();"

# 追加在类结尾 "   }\n}" 之前
METHODS = """      
      internal function loadRConnectMod() : *
      {
         var _loc1_:LoaderContext;
         trace("RConnectMod: load start");
         try
         {
            this.rconnectLoader = new Loader();
            _loc1_ = new LoaderContext(false);
            this.rconnectLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,this.onRConnectModLoaded);
            this.rconnectLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,this.onRConnectModError);
            this.rconnectLoader.load(new URLRequest("app:/mods/Rconnect/release/RConnectMod.swf"),_loc1_);
            trace("RConnectMod: load issued");
         }
         catch(err:*)
         {
            trace("RConnectMod: load threw " + err);
         }
      }
      
      internal function onRConnectModError(param1:IOErrorEvent) : *
      {
         trace("RConnectMod: IOError " + param1.text);
      }
      
      internal function onRConnectModLoaded(param1:Event) : *
      {
         var _loc2_:*;
         trace("RConnectMod: complete fired");
         try
         {
            _loc2_ = LoaderInfo(param1.currentTarget).applicationDomain.getDefinition("RConnectMod");
            trace("RConnectMod: class=" + _loc2_);
            _loc2_.init(this);
            trace("RConnectMod: init returned");
         }
         catch(err:*)
         {
            trace("RConnectMod load/init error: " + err);
         }
      }
"""

MARKER = "loadRConnectMod"


def log(msg):
    print("[patch_game_swfs] " + msg, flush=True)


def run(cmd, **kw):
    kw.setdefault("check", True)
    return subprocess.run(cmd, **kw)


def ffdec_export_scripts(ffdec, swf_path, out_dir):
    run([ffdec, "-export", "script", out_dir, swf_path],
        capture_output=True, timeout=1200)


def ffdec_import_scripts(ffdec, swf_path, out_path, scripts_dir):
    run([ffdec, "-importScript", swf_path, out_path, scripts_dir],
        capture_output=True, timeout=1200)


def patch_mainfe_source(src_text):
    """返回 (修改后文本, 修改数量)。锚点缺失时抛异常。"""
    out = src_text
    applied = []

    if FIELD_ANCHOR not in out:
        raise RuntimeError("MainFE.as 缺少字段锚点（可能 MainFE 结构已变化，需人工适配）")
    out = out.replace(FIELD_ANCHOR, FIELD_ANCHOR + "\r\n" + FIELD_ADD, 1)
    applied.append("field")

    if CALL_ANCHOR not in out:
        raise RuntimeError("MainFE.as 缺少调用锚点（可能 MainFE 结构已变化，需人工适配）")
    out = out.replace(CALL_ANCHOR, CALL_ANCHOR + "\r\n" + CALL_ADD, 1)
    applied.append("call")

    # 类结尾：最后的 "\n   }\n}"（可能带行尾空白）
    methods_crlf = METHODS.replace("\n", "\r\n")
    tail = out.rstrip()
    if not tail.endswith("\r\n   }\r\n}"):
        raise RuntimeError("MainFE.as 结尾结构不匹配，需人工适配")
    body_end = tail.rfind("\r\n   }")
    out = tail[:body_end] + methods_crlf + "\r\n" + tail[body_end:].lstrip("\r\n")
    applied.append("methods")

    return out, applied


def is_already_patched(mainfe_text):
    return MARKER in mainfe_text


def patch_one(ffdec, game_root, rel_path, backup_dir, work_dir):
    """补丁单个游戏 SWF。返回状态字符串。"""
    swf_path = os.path.join(game_root, rel_path)
    if not os.path.isfile(swf_path):
        return "skip(missing)"
    name = os.path.basename(rel_path)
    log("处理 %s ..." % rel_path)

    # 1. 导出脚本
    export_dir = os.path.join(work_dir, name + "_export")
    ffdec_export_scripts(ffdec, swf_path, export_dir)
    mainfe_path = os.path.join(export_dir, "scripts", "MainFE.as")
    if not os.path.isfile(mainfe_path):
        raise RuntimeError("%s 中找不到 MainFE.as，无法补丁" % rel_path)
    with open(mainfe_path, "r", encoding="utf-8", newline="") as f:
        src = f.read()

    if is_already_patched(src):
        log("  %s 已含 RConnect 加载器，跳过" % rel_path)
        return "skip(already-patched)"

    # 2. 修改源码
    new_src, applied = patch_mainfe_source(src)
    log("  源码修改点: %s" % ", ".join(applied))

    # 3. 重新导入（只带 MainFE.as，避免误导入其他脚本）
    scripts_dir = os.path.join(work_dir, name + "_import")
    os.makedirs(scripts_dir, exist_ok=True)
    with open(os.path.join(scripts_dir, "MainFE.as"), "w",
              encoding="utf-8", newline="") as f:
        f.write(new_src)

    patched_path = os.path.join(work_dir, name + ".patched.swf")
    if os.path.exists(patched_path):
        os.remove(patched_path)
    ffdec_import_scripts(ffdec, swf_path, patched_path, scripts_dir)

    # 4. 校验：重新导出补丁结果，检查两个标记
    verify_dir = os.path.join(work_dir, name + "_verify")
    ffdec_export_scripts(ffdec, patched_path, verify_dir)
    with open(os.path.join(verify_dir, "scripts", "MainFE.as"),
              "r", encoding="utf-8", newline="") as f:
        verify_src = f.read()
    if "loadRConnectMod" not in verify_src:
        raise RuntimeError("%s 校验失败：RConnect 加载器未写入" % rel_path)
    if "SandevistanMod" not in verify_src:
        raise RuntimeError("%s 校验失败：Sandevistan 加载器丢失，已中止！" % rel_path)

    # 5. 备份 + 落盘
    os.makedirs(backup_dir, exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    # 用相对路径拼备份名（DLC/pfe.swf -> DLC_pfe.swf），避免同名 SWF 混淆
    backup_tag = rel_path.replace("/", "_").replace("\\", "_")
    backup_path = os.path.join(backup_dir, "%s.%s.bak.swf" % (backup_tag, stamp))
    shutil.copy2(swf_path, backup_path)
    log("  原文件已备份: %s" % backup_path)

    shutil.copy2(patched_path, swf_path)
    log("  补丁已写入: %s" % swf_path)
    return "patched"


def main():
    ap = argparse.ArgumentParser(description="给游戏 SWF 加装 RConnect 加载器")
    ap.add_argument("--game-root", default=GAME_ROOT)
    ap.add_argument("--ffdec", default=DEFAULT_FFDEC)
    ap.add_argument("--targets", nargs="*", default=DEFAULT_TARGETS,
                    help="相对游戏根目录的 SWF 列表（默认全部三个版本）")
    ap.add_argument("--backup-dir", default=os.path.join(MOD_ROOT, "build", "backup"))
    ap.add_argument("--work-dir", default=None,
                    help="临时工作目录（默认系统临时目录，可指定到 build/tmp 便于排查）")
    args = ap.parse_args()

    if not os.path.isfile(args.ffdec):
        print("找不到 ffdec-cli.exe: %s" % args.ffdec, file=sys.stderr)
        print("可用 --ffdec 指定路径。", file=sys.stderr)
        sys.exit(2)

    game_root = os.path.normpath(args.game_root)
    work_dir = args.work_dir or tempfile.mkdtemp(prefix="rconnect_patch_")
    os.makedirs(work_dir, exist_ok=True)

    results = []
    failed = []
    for rel in args.targets:
        try:
            results.append((rel, patch_one(args.ffdec, game_root, rel,
                                           args.backup_dir, work_dir)))
        except Exception as e:
            failed.append((rel, str(e)))
            log("!! %s 失败: %s" % (rel, e))

    print()
    for rel, status in results:
        print("  %-16s %s" % (rel, status))
    for rel, err in failed:
        print("  %-16s FAILED: %s" % (rel, err))
    if failed:
        sys.exit(1)
    print("完成。")


if __name__ == "__main__":
    main()
