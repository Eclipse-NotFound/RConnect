# 普通墙 SV：复用房间原生回归

复用已编译 `build/m52/recovery-entry-observer-driver-01/entry-room`（BF6C9567…53BA）。旧真实双人记录 `recovery-first-raster-entry-room-02` / `77afbadd8d` 为 25/0 + 53/0，通过不转授新候选。旧驱动保留 RoomCooperation 的原断言，只修过 READY/ACK 的观察时点；本入口不重新编译或改动 AS。

复用 `recovery-first-raster-native/run_native.py` 原 main，仅更换公开的产品/宿主准入、驱动校验和实际安装查询回调。准确 C6A3 产品与 host05（00C7…AA48）资格来自已冻结 `recovery-ordinary-wall-sv-native/binding.json`；当前 22 文件须为 EB365 安装，旧驱动历史 574D/RV7852 仅保留为来源，不冒充实际安装。不做 inspect 或源码替换。

覆盖：加入侧在独立房间用原生 Bullet.run 破墙；紧邻交接的两次 hitTile（10+13）最终 hp=77，结算一次；加入侧／主侧权威交接；双方离开后重访，破墙、损伤、敌人死亡、容器与掉落状态保留。夹具会设置普通墙和原生单位，所以不能冒充自然场景全流程或性能测试。

缺口：不核结构前景逐 uint、ordinary SV 版本/旧 ACK/重发顺序，不覆盖 mat7/gwall；该测试中的旧 damage 包与 TerrainSync 收据不等于新 SV 墨迹协议。既有153组件不重做。原房间/物理/HP、错误、DONE、600秒、登记及运行器内存门槛保持。

从 RConnect 目录执行；本次准备只运行 `--check`，根会话独占真实测试：

```text
python -B -X utf8 experimental/recovery-ordinary-wall-sv-rooms/run_native.py --check
python -B -X utf8 experimental/recovery-ordinary-wall-sv-rooms/run_native.py --run --output build/m52/recovery-ordinary-wall-sv-rooms-01 --registry-wait 900
```

原 result.json 不改；附加 rooms-result.json 记录准确绑定与后验失败。没有编译、部署或性能通过资格。
