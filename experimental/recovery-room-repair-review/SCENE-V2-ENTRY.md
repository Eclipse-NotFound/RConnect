# 大场景：连接前偏好固定

这是隔离夹具修正，不改产品。旧 `1cbea1016e` 及其失败回执保持原样。它在 WELCOME 后才把场景偏好设 true，末尾却要求恢复 true，不能代表真实连接前偏好。

`prepare_scene_v2.py` 复用已编译 driver01 的普通 Timing、Metrics 源码和 timing SWF，逐字不变；只编译新的 scene 子类。新子类读取 CS 原生偏好文件并记日志，原三程计时、地图种子/尺寸/出生位置、控制恢复与断开恢复断言不变。

`scene_v2_launcher.py` 加载 SHA `7eca453b13480140da5f36bb33d2319739a927562ccafdbb61a8b20cdb5ae4d3` 的原共享运行器，只在其公开 `run_registered` 内装饰本次登记实例的 `before_launch`。两角色描述符全部生成后、首个 AIR 启动前，验证唯一 AppID、namespace 30、content、原描述符指纹和偏好文件原本不存在；先验证全部目标，再以独占创建写入各自 `Local Store/ContinuousScene.preferences.json` 的 `{"nativeEnabled":true}`。仍调用原 `before_launch`，finally 恢复实例方法。没有改配置、描述符、原运行器或安装文件。

原登记、600 秒上限、独占私有桌面、6 GiB 双人/3 GiB 单人启动余量、512 MiB 运行门槛和自有进程/副本清理保持。唯一新增持久文件在本次随机 AppID 的私有测试存储；结束时核对未变并保留证据，不删除或覆盖已有偏好。

根执行（本代理只做 AST 与 help 检查，未编译/运行）：

```powershell
python -B -X utf8 experimental/recovery-room-repair-review/prepare_scene_v2.py --output build/m52/recovery-room-scene-driver-02 --build
python -B -X utf8 experimental/recovery-room-repair-review/run_scene_v2.py --drivers build/m52/recovery-room-scene-driver-02 --output build/m52/recovery-roomfix2-scene-dual-02 --mode dual --product roomfix2
python -B -X utf8 experimental/recovery-room-repair-review/run_scene_v2.py --drivers build/m52/recovery-room-scene-driver-02 --output build/m52/recovery-roomfix2-scene-solo-02 --mode solo --product roomfix2
```

`run_scene_v2.py` 直接复用准确 SHA `3660c3bc5c8bec85f2981793a7cb4f0946440cf176d5b421ba2de76d14e878ae` 的 `run_native_v2.main`，只绑定真实新驱动 verifier 和新 launcher 路径。固定 roomfix2 C26B…8CC0 或安装 aura1；不伪称旧 driver verifier 验过新 SWF。原 `result.json` 不改写；另保存 `scene-result.json`，要求原业务通过且预置/实际读取/末尾文件未变证据完整。出错退出非零。

每次另有 `scene-preference-input.json`、`scene-preference-after.json`，绑定原 input.json、launcher 和原 runner SHA；每端有一条 `SCENE PREFERENCE BASELINE` 与原生文件路径。构造器读文件本身不证明早于 WELCOME，早于启动的事实由 launcher 回执证明。单轮样本不授性能资格，必须另与相同驱动和资源组合的 solo 对照。
