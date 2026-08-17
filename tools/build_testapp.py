#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_testapp.py — 编译独立测试容器并准备 host/join 两个实例目录。

结构：
  build/testapp/
  ├─ application.xml      （公共描述文件，两实例复制使用）
  ├─ TestMain.swf         （编译产物）
  ├─ host/  app.xml + TestMain.swf + mods/Rconnect/release/config.txt(autoRole=host)
  └─ join/  app.xml + TestMain.swf + mods/Rconnect/release/config.txt(autoRole=join)

运行（游戏根目录下）：
  adl64.exe -runtime runtimes\\air\\win64 mods\\Rconnect\\build\\testapp\\host\\app.xml
  adl64.exe -runtime runtimes\\air\\win64 mods\\Rconnect\\build\\testapp\\join\\app.xml
"""

import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MOD_ROOT = os.path.dirname(HERE)
TESTAPP = os.path.join(MOD_ROOT, "build", "testapp")

DEFAULT_AMXMLC = r"C:\Users\micha\Documents\_sandevistan_dev\flexsdk\bin\amxmlc.bat"


def main():
    os.makedirs(TESTAPP, exist_ok=True)

    # 1. 编译 TestMain.swf
    src = os.path.join(TESTAPP, "src", "TestMain.as")
    out = os.path.join(TESTAPP, "TestMain.swf")
    env = dict(os.environ)
    env["AIR_HOME"] = os.path.normpath(os.path.join(
        os.path.dirname(DEFAULT_AMXMLC), ".."))
    cmd = [DEFAULT_AMXMLC, "-source-path=" + os.path.dirname(src),
           "-output=" + out, src]
    print("build_testapp: " + " ".join(cmd), flush=True)
    r = subprocess.run(cmd, env=env)
    if r.returncode != 0:
        sys.exit(r.returncode)

    # 2. 生成 host/join 两个实例目录（app id 必须不同，否则 AIR 单实例转发）
    appxml = os.path.join(TESTAPP, "application.xml")
    for role, nick in [("host", "HostA"), ("join", "JoinB")]:
        d = os.path.join(TESTAPP, role)
        os.makedirs(d, exist_ok=True)
        dst = os.path.join(d, "app.xml")
        shutil.copy2(appxml, dst)
        with open(dst, "r", encoding="utf-8") as f:
            xml = f.read()
        xml = xml.replace("<id>rconnect.testapp</id>",
                          "<id>rconnect.testapp.%s</id>" % role)
        with open(dst, "w", encoding="utf-8") as f:
            f.write(xml)
        shutil.copy2(out, os.path.join(d, "TestMain.swf"))
        cfgdir = os.path.join(d, "mods", "Rconnect", "release")
        os.makedirs(cfgdir, exist_ok=True)
        # 复刻游戏布局：模组 SWF 放进 app:/mods/Rconnect/release/（应用沙箱内）
        shutil.copy2(os.path.join(MOD_ROOT, "release", "RConnectMod.swf"),
                     os.path.join(cfgdir, "RConnectMod.swf"))
        with open(os.path.join(cfgdir, "config.txt"), "w", encoding="utf-8") as f:
            f.write('{"nickname":"%s","hostIp":"127.0.0.1",'
                    '"port":23456,"tickMs":50,"autoRole":"%s"}\n' % (nick, role))
        print("build_testapp: prepared %s" % d, flush=True)

    print("build_testapp: OK")


if __name__ == "__main__":
    main()
