#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
run_m2_dualtest.py — M2 双实例联机测试（真机，1.02）。

做法（不碰用户真实存档与任何现有游戏文件内容）：
- 两个测试实例使用**全新 AIR app id**（pfe2=host / pfe3=join），各自独立存储；
- 存档模板：只读复制用户的 PFEgame0.sol 到测试实例自己的 SharedObject 目录；
- 每实例配置写入其自己的 applicationStorageDirectory（Rconnect_config.txt），
  含 autoRole（host/join）与 autoGame=1（程序化开新游戏）；
- 临时描述符 app_rconnect_test_<id>.xml（content=pfe.swf）放在游戏根目录，
  测试结束后由 --cleanup 删除；
- 模组日志各自落在 %APPDATA%\\<id>\\Local Store\\RConnect.log。

用法：
  python tools/run_m2_dualtest.py run       # 依次启动 host 与 join 并输出日志
  python tools/run_m2_dualtest.py cleanup  # 停掉测试实例并删除临时描述符
"""

import argparse
import os
import shutil
import subprocess
import sys
import time

GAME_ROOT = r"D:\Program Files\Steam\steamapps\common\Remains"
ADL = os.path.join(GAME_ROOT, "adl64.exe")
RUNTIME = os.path.join(GAME_ROOT, "runtimes", "air", "win64")
APPDATA = os.path.expandvars(r"%APPDATA%")
MOD = os.path.join(GAME_ROOT, "mods", "RConnect")

HOST_ID = "pfe2"
JOIN_ID = "pfe3"
# 端口可换：同机有其他宿主实例占 23456 时用 M2_PORT 避开
PORT = int(os.environ.get("M2_PORT", "23456"))

SRC_SAVE = os.path.join(APPDATA, "pfe", "Local Store", "#SharedObjects",
                        "pfe.swf", "PFEgame0.sol")


def storage_dir(app_id):
    return os.path.join(APPDATA, app_id, "Local Store")


def so_dir(app_id):
    return os.path.join(storage_dir(app_id), "#SharedObjects", "pfe.swf")


def log(msg):
    print("[m2test] " + msg, flush=True)


def prep_instance(app_id, role, nickname):
    os.makedirs(so_dir(app_id), exist_ok=True)
    dst = os.path.join(so_dir(app_id), "PFEgame0.sol")
    # M2_SAVE / M2_JOIN_SAVE：可用不同的存档模板测试"加入方不准备存档"
    src = SRC_SAVE
    if role == "host" and os.environ.get("M2_SAVE"):
        src = os.path.join(os.path.dirname(SRC_SAVE),
                           "PFEgame%s.sol" % os.environ["M2_SAVE"])
    if role == "join" and os.environ.get("M2_JOIN_SAVE"):
        src = os.path.join(os.path.dirname(SRC_SAVE),
                           "PFEgame%s.sol" % os.environ["M2_JOIN_SAVE"])
    if not os.path.exists(dst) and os.path.exists(src):
        shutil.copy2(src, dst)
        log("%s: save template copied (%s)" % (app_id, os.path.basename(src)))
    # 注意：autoTravel（同地图 gotoXY）曾在实测中把宿主游戏挂死，已移除；
    # 跨地图传送用 autoTravelLand（环境变量 M2_LAND 指定，如 raiders/random_mane）。
    # M10 场景：
    # - host：autoDamage=0（不干扰自然拉仇恨循环）、autoGhostDmg=1（确定性
    #   死亡驱动，伤害量=testGhostDmg，M2_TESTGHOSTDMG 可覆盖，0=纯自然循环）；
    # - join：autoDamage=1（打最近敌人→宿主拉仇恨→敌人反击化身）+ autoMove
    #   （传送到敌人旁），验证 敌人攻击化身→伤害回传→死亡→复活→化身复位。
    land = os.environ.get("M2_LAND", "")
    ghost_dmg = os.environ.get("M2_TESTGHOSTDMG", "2000")
    host_kill = '"autoHostKill":"1",' if os.environ.get("M2_HOSTKILL") else ""
    host_boxkill = '"autoBoxKill":"1",' if os.environ.get("M2_BOXKILL") else ""
    host_tilebreak = '"autoTileBreak":"1",' if os.environ.get("M2_TILEBREAK") else ""
    host_objspawn = '"autoObjSpawn":"1",' if os.environ.get("M2_OBJSPAWN") else ""
    host_doortoggle = '"autoDoorToggle":"1",' if os.environ.get("M2_DOORTOGGLE") else ""
    host_boxloot = '"autoBoxLoot":"1",' if os.environ.get("M2_BOXLOOT") else ""
    # 宿主先走开（ticks 600-1200 平滑移动）——出生点常在门框里，玩家
    # 堵门会触发游戏 attDoor 堵门循环让门状态高速振荡（M22 教训）
    host_walk = '"autoWalk":"1",' if os.environ.get("M2_HOSTWALK") else ""
    host_loadsave = '"autoGame":"","autoLoadSave":0,' \
        if os.environ.get("M2_HOST_LOADSAVE") else ""
    if role == "host":
        extra = (',' + host_loadsave + '"autoTravel":"0","autoDamage":"0",'
                 '"autoGhostDmg":"1",' + host_kill + host_boxkill + host_tilebreak
                 + host_objspawn + host_doortoggle + host_boxloot + host_walk
                 + '"testGhostDmg":%s,"autoTravelLand":"%s"' % (ghost_dmg, land))
    elif os.environ.get("M2_JOIN_LOADSAVE"):
        # M8：join 加载自己的存档（不同进度→中立单位差异），不开新游戏
        extra = ',"autoGame":"","autoLoadSave":0,' \
                '"autoFollow":"1","freezeAI":"1"'
    elif os.environ.get("M2_GHOSTANIM"):
        # M14：强制幽灵动画标签循环，验证动画帧推进
        extra = ',"autoGhostAnim":"1","autoFollow":"1","freezeAI":"1"'
    elif os.environ.get("M2_WALK"):
        # M14：join 平滑右移，验证远端幽灵走路动画
        extra = ',"autoWalk":"1","autoFollow":"1","freezeAI":"1"'
    elif os.environ.get("M2_DEACT"):
        # M12：模拟失焦（确定性验证覆盖层卡死→恢复守护）
        extra = ',"autoDeactivate":"1","autoFollow":"1","freezeAI":"1"'
    elif os.environ.get("M2_JOIN_QUIET"):
        # M8：只跟随+镜像（无 autoMove/autoDamage 干扰，观察中立单位注入/移除）
        extra = ',"autoFollow":"1","freezeAI":"1"'
    else:
        extra = ',"autoFollow":"1","freezeAI":"1","autoDamage":"1",' \
                '"autoMove":"1","autoHeal":"1"'
    # 注意：autoMove 已移到 join 侧，且模组内延迟 60s 后才开始（避开传送过渡）
    cfg = '{"nickname":"%s","hostIp":"127.0.0.1","port":%d,' \
          '"tickMs":50,"autoRole":"%s","autoGame":"1"%s}\n' \
          % (nickname, PORT, role, extra)
    with open(os.path.join(storage_dir(app_id), "Rconnect_config.txt"),
              "w", encoding="utf-8") as f:
        f.write(cfg)
    log("%s: config written (role=%s)" % (app_id, role))

    desc = os.path.join(GAME_ROOT, "app_rconnect_test_%s.xml" % app_id)
    with open(desc, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8" standalone="no" ?>\n'
                '<application xmlns="http://ns.adobe.com/air/application/30.0">\n'
                '  <id>%s</id>\n'
                '  <versionNumber>1.0</versionNumber>\n'
                '  <filename>Remains</filename>\n'
                '  <initialWindow>\n'
                '    <content>pfe.swf</content>\n'
                '    <systemChrome>standard</systemChrome>\n'
                '    <transparent>false</transparent>\n'
                '    <visible>true</visible>\n'
                '    <fullScreen>false</fullScreen>\n'
                '    <renderMode>direct</renderMode>\n'
                '  </initialWindow>\n'
                '</application>\n' % app_id)
    log("%s: temp descriptor %s" % (app_id, desc))
    return desc


def kill_test_instances():
    ps = ("powershell -NoProfile -Command \""
          "Get-CimInstance Win32_Process -Filter \\\"Name='adl64.exe'\\\" | "
          "Where-Object { $_.CommandLine -match 'app_rconnect_test' } | "
          "ForEach-Object { Stop-Process -Id $_.ProcessId -Force }\"")
    subprocess.run(ps, shell=True)
    time.sleep(1)


def launch(desc_path, run_log):
    with open(run_log, "w", encoding="utf-8") as f:
        return subprocess.Popen(
            [ADL, "-runtime", RUNTIME, desc_path],
            cwd=GAME_ROOT, stdout=f, stderr=subprocess.STDOUT)


def mod_log(app_id):
    return os.path.join(storage_dir(app_id), "RConnect.log")


def dump_logs():
    for app_id in (HOST_ID, JOIN_ID):
        p = mod_log(app_id)
        print("===== %s RConnect.log =====" % app_id)
        if os.path.exists(p):
            print(open(p, encoding="utf-8", errors="replace").read())
        else:
            print("(no log yet)")


def cmd_run():
    procs = []
    try:
        kill_test_instances()
        for app_id in (HOST_ID, JOIN_ID):
            p = mod_log(app_id)
            if os.path.exists(p):
                os.remove(p)

        prep_instance(HOST_ID, "host", "HostA")
        prep_instance(JOIN_ID, "join", "JoinB")

        host_desc = os.path.join(GAME_ROOT, "app_rconnect_test_%s.xml" % HOST_ID)
        join_desc = os.path.join(GAME_ROOT, "app_rconnect_test_%s.xml" % JOIN_ID)

        log("launching host (%s) ..." % HOST_ID)
        procs.append(launch(host_desc, os.path.join(MOD, "build", "m2_host.log")))
        time.sleep(45)   # 游戏加载 + autoGame 进游戏

        log("launching join (%s) ..." % JOIN_ID)
        procs.append(launch(join_desc, os.path.join(MOD, "build", "m2_join.log")))
        time.sleep(180)   # 连接+跟随+镜像；M22 门/容器钩子在宿主 80s/150s 触发

        dump_logs()
    finally:
        for p in procs:
            try:
                p.terminate()
            except Exception:
                pass


def cmd_cleanup():
    kill_test_instances()
    for app_id in (HOST_ID, JOIN_ID):
        d = os.path.join(GAME_ROOT, "app_rconnect_test_%s.xml" % app_id)
        if os.path.exists(d):
            os.remove(d)
            log("removed %s" % d)
    log("cleanup done")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["run", "cleanup"])
    args = ap.parse_args()
    if args.cmd == "run":
        cmd_run()
    else:
        cmd_cleanup()


if __name__ == "__main__":
    main()
