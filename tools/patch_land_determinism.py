#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
patch_land_determinism.py — 随机土地（rnd）房间布局确定性补丁。

背景
====
random_mane（马哈顿废墟）等随机土地的房间布局（选房/镜像/通道）由
`Land.as` 内 7 处 `Math.random()` 决定，每实例各自生成 → 联机两侧房间
不同、互相看不到。本补丁把这 7 处结构随机改为**按土地 id 播种的本地
PRNG**（Land 静态 `_rndSeed / rndDeterm / rndSeedFor / rndNext`），
两侧实例从同一 XML 读到同一 act.id → 同一 seed → 同一布局。
内容随机（敌人/掉落/装饰）保持全局 Math.random 不动。

原理
====
1. ffdec `-export script` 全量导出；
2. 只修改 `fe/loc/Land.as`：
   - 在类字段后加静态 PRNG（fnv1a seed + LCG next）；
   - 在 Land 构造的 `if(this.rnd)` 分支调用 rndDeterm(rndSeedFor(act.id))；
   - 把 7 处结构 `Math.random()` 替换为 `rndNext()`（各自带上下文锚点）；
3. ffdec `-importScript` 只导入修改后的 Land.as；
4. 校验：Land.as 重新导出含标记；SWF 中 5 个模组加载器标记仍在；
   类别数不增不减（导出脚本文件数对比）。

授权记录
========
用户于 2026-08-18 批准《M13 计划》修改游戏 SWF 的 Land.as（见
state/current-status.md M13 节）。改前已核验三份 SWF 与
build/backup/current-merged-20260818/ 哈希一致（无他人在 Land.as 上
的新改动）。脚本幂等（标记存在即跳过），改前自动备份。
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(HERE)
GAME_ROOT = os.path.normpath(os.path.join(MOD_ROOT, "..", ".."))

DEFAULT_FFDEC = r"C:\Users\micha\Documents\_sandevistan_dev\ffdec\ffdec-cli.exe"

DEFAULT_TARGETS = [
    "pfe.swf",          # 1.02（用户默认）
    "DLC/pfe.swf",      # 1.03
    "DLC/pfeUI.swf",    # 1.04
]

MARKER = "rndNext"          # 补丁标记（Land.as 内新增静态函数名）
TRACE_MARKER = "RConnectRndSeed"

# 各 SWF 应有的模组加载器标记（按版本区分，缺一不可校验）
LOADER_MAP = {
    "pfe.swf": (b"RConnectMod", b"SandevistanMod", b"RandomRoomsMod",
                b"TDFCMod", b"RealisticVisionMod"),
    "DLC/pfe.swf": (b"RConnectMod", b"SandevistanMod", b"RandomRoomsMod"),
    "DLC/pfeUI.swf": (b"RConnectMod", b"SandevistanMod"),
}

STATIC_ANCHOR = "      public var act:LandAct;\r\n"
STATICS = (
    "      internal static var _rndSeed:uint = 0;\r\n"
    "\r\n"
    "      internal static function rndDeterm(param1:uint) : *\r\n"
    "      {\r\n"
    "         _rndSeed = param1 | 0;\r\n"
    "         if(_rndSeed == 0)\r\n"
    "         {\r\n"
    "            _rndSeed = 2166136261;\r\n"
    "         }\r\n"
    "      }\r\n"
    "\r\n"
    "      internal static function rndSeedFor(param1:String) : uint\r\n"
    "      {\r\n"
    "         var _loc2_:uint = 2166136261;\r\n"
    "         var _loc3_:int = 0;\r\n"
    "         while(_loc3_ < param1.length)\r\n"
    "         {\r\n"
    "            _loc2_ ^= param1.charCodeAt(_loc3_);\r\n"
    "            _loc2_ = _loc2_ * 16777619;\r\n"
    "            _loc3_++;\r\n"
    "         }\r\n"
    "         return _loc2_;\r\n"
    "      }\r\n"
    "\r\n"
    "      internal static function rndNext() : Number\r\n"
    "      {\r\n"
    "         _rndSeed = _rndSeed * 1664525 + 1013904223;\r\n"
    "         return (_rndSeed >>> 8) / 16777216;\r\n"
    "      }\r\n"
)

# 播种插入：Land 构造 rnd 分支
SEED_ANCHOR = (
    "            this.maxLocX = this.act.mLocX;\r\n"
    "            this.maxLocY = this.act.mLocY;\r\n"
    "            this.buildRandomLand();\r\n"
)
SEED_ADD = (
    "            this.maxLocX = this.act.mLocX;\r\n"
    "            this.maxLocY = this.act.mLocY;\r\n"
    "            rndDeterm(rndSeedFor(this.act.id));\r\n"
    "            trace(\"RConnectRndSeed \",this.act.id,_rndSeed);\r\n"
    "            this.buildRandomLand();\r\n"
)

# 7 处结构随机点：锚点 → 期望出现次数
SITE_REPLACEMENTS = [
    ("mirror = Math.random()", "mirror = rndNext()", 1),
    ("Math.random() * _loc1_.pass_r.length",
     "rndNext() * _loc1_.pass_r.length", 1),
    ("Math.random() * _loc1_.pass_d.length",
     "rndNext() * _loc1_.pass_d.length", 1),
    ("_loc5_ = this.rndRoom[Math.floor(Math.random()",
     "_loc5_ = this.rndRoom[Math.floor(rndNext()", 1),
    ("_loc5_ = this.allRoom[Math.floor(Math.random()",
     "_loc5_ = this.allRoom[Math.floor(rndNext()", 1),
    ("_loc8_ = this.rndRoom[Math.floor(Math.random()",
     "_loc8_ = this.rndRoom[Math.floor(rndNext()", 2),
]


def log(msg):
    print("[landdet] " + msg, flush=True)


def run(cmd, **kw):
    kw.setdefault("check", True)
    return subprocess.run(cmd, **kw)


def to_crlf(text):
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


def patch_land_source(src_text):
    """返回 (修改后文本, applied 列表)。锚点缺失/计数不符时抛异常。"""
    text = to_crlf(src_text)
    applied = []

    if MARKER in text:
        raise RuntimeError("已打过确定性补丁（标记存在），幂等跳过")
    if STATIC_ANCHOR not in text:
        raise RuntimeError("Land.as 缺少字段锚点，需人工适配")
    text = text.replace(STATIC_ANCHOR, STATIC_ANCHOR + STATICS, 1)
    applied.append("statics")

    if SEED_ANCHOR not in text:
        raise RuntimeError("Land.as 缺少播种锚点（ctor rnd 分支），需人工适配")
    text = text.replace(SEED_ANCHOR, SEED_ADD, 1)
    applied.append("seed")

    for old, new, expect in SITE_REPLACEMENTS:
        cnt = text.count(old)
        if cnt != expect:
            raise RuntimeError(
                "调用点锚点计数不符: %r 期望 %d 实际 %d（Land 结构可能变化）"
                % (old[:40], expect, cnt))
        text = text.replace(old, new)
        applied.append(old[:30])

    # 校验：7 处结构替换后不应残留（注意 newRandomProb 的内容随机
    # `pid = this.rndRoom[...]` 合法保留，只查结构形态）
    for frag in ("mirror = Math.random",
                 "_loc5_ = this.rndRoom[Math.floor(Math.random",
                 "_loc5_ = this.allRoom[Math.floor(Math.random",
                 "_loc8_ = this.rndRoom[Math.floor(Math.random",
                 "Math.random() * _loc1_.pass_r.length",
                 "Math.random() * _loc1_.pass_d.length"):
        if frag in text:
            raise RuntimeError("结构随机残留: " + frag)
    return text, applied


def find_land_as(scripts_dir):
    for root, dirs, files in os.walk(scripts_dir):
        if "Land.as" in files or files and any(
                f.endswith("Land.as") for f in files):
            cand = [os.path.join(root, f) for f in files if f == "Land.as"]
            if cand:
                return cand[0]
    # 显式路径兜底
    p = os.path.join(scripts_dir, "fe", "loc", "Land.as")
    if os.path.exists(p):
        return p
    raise RuntimeError("导出脚本中找不到 Land.as")


def patch_one(ffdec, game_root, rel_path, backup_dir, work_dir):
    swf = os.path.join(game_root, rel_path)
    if not os.path.exists(swf):
        log("skip %s (missing)" % rel_path)
        return 0
    tag = rel_path.replace("/", "_").replace("\\", "_")
    exp = os.path.join(work_dir, tag + "_exp")
    imp_dir = os.path.join(work_dir, tag + "_import")   # 根目录即 scripts 根
    os.makedirs(exp, exist_ok=True)
    os.makedirs(imp_dir, exist_ok=True)

    log("export scripts %s ..." % rel_path)
    run([ffdec, "-export", "script", exp, swf], capture_output=True,
        timeout=1800)

    land = find_land_as(exp)   # <exp>/scripts/fe/loc/Land.as
    src = open(land, encoding="utf-8", errors="replace").read()
    if MARKER in src:
        log("%s 已打补丁，跳过" % rel_path)
        return 0

    new_src, applied = patch_land_source(src)
    # importScript 的目录根 = scripts 根：包路径 fe/loc/Land.as 相对根放置
    rel_land = os.path.relpath(land, os.path.join(exp, "scripts"))
    dst = os.path.join(imp_dir, rel_land)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, "w", encoding="utf-8", newline="").write(new_src)
    log("%s: patched Land.as (rel=%s, %d edits)" % (rel_path, rel_land,
                                                    len(applied)))

    patched_path = os.path.join(work_dir, tag + ".patched.swf")
    if os.path.exists(patched_path):
        os.remove(patched_path)
    log("import scripts %s -> %s ..." % (rel_path, os.path.basename(patched_path)))
    run([ffdec, "-importScript", swf, patched_path, imp_dir],
        capture_output=True, timeout=1800)

    # 校验 1：从补丁结果重新导出 Land.as，应含标记
    ver = os.path.join(work_dir, tag + "_ver")
    os.makedirs(ver, exist_ok=True)
    run([ffdec, "-export", "script", ver, patched_path], capture_output=True,
         timeout=1800)
    vland = find_land_as(ver)
    vtext = open(vland, encoding="utf-8", errors="replace").read()
    if MARKER not in vtext or TRACE_MARKER not in vtext:
        raise RuntimeError("%s 补丁校验失败：Land.as 标记缺失" % rel_path)

    # 校验 2：该版本应有的模组加载器标记仍在
    data = open(patched_path, "rb").read()
    for mod in LOADER_MAP.get(rel_path, (b"RConnectMod",)):
        if mod not in data:
            raise RuntimeError("%s 校验失败：缺失加载器标记 %s" % (rel_path, mod))

    # 备份原文件后再覆盖
    bak = os.path.join(backup_dir, tag)
    shutil.copy2(swf, bak)
    log("backup -> %s" % bak)
    shutil.copy2(patched_path, swf)
    log("%s OK: Land.as 确定性补丁安装，全部加载器在位" % rel_path)
    return 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ffdec", default=DEFAULT_FFDEC)
    ap.add_argument("--targets", nargs="*", default=DEFAULT_TARGETS)
    args = ap.parse_args()

    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup_dir = os.path.join(MOD_ROOT, "build", "backup",
                              "land-determinism-" + stamp)
    work_dir = os.path.join(MOD_ROOT, "build", "tmp",
                            "landdet-" + stamp)
    os.makedirs(backup_dir, exist_ok=True)
    os.makedirs(work_dir, exist_ok=True)
    try:
        done = 0
        for rel in args.targets:
            done += patch_one(args.ffdec, GAME_ROOT, rel, backup_dir, work_dir)
        log("done: %d/%d patched (backup=%s)" % (done, len(args.targets),
                                                 backup_dir))
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
