# roomfix5 真实遮罩回归入口

只复用原 `MirrorMaskRestoreTestDoc` 的 8 轮，AS 字节、设置、断言、时序均不改。`tests` 只冻结该文档类和 `TestRoomReadiness`，`harness` 是原两类。产品固定为 `build/m52/recovery-room-production-05`：必须实际编译成功、完整源码等于 roomfix5 源清单，产物 SHA、编译回执、全部 22 项安装输入匹配，才允许冻结/编译驱动。

独立 `current_tint_verifier.py` 保留该产品在 ABE2 宿主下的真实编译环境（产品 `78C052…F4699`、prepared `ACDC405…6C58`、compile `68FCCA…48D4`）。新运行环境仅接纳 CS 已 verified 的 ABE2→A796 宿主变更；回执、两处方法语义审计、候选及安装后各 20 条组件结果均固定核对，其他 21 项运行输入不变。这不是将旧编译或性能结果改判成新组合通过。旧 verifier、旧回执和 Java 启动前停止的 drivers-01 均保留；新默认驱动目录为 drivers-02。

`prepare.py` 复用 `experimental/recovery-tests/prepare.py` 的外部声明、编译命令与校验，仅缩小冻结源码闭包。编译仍走同一共享登记；3 个编译进程逐个检查 1 GiB 启动、512 MiB 运行余量并登记、回收。共享登记源码没有在本次准备时读取或固定；根在确认其修改完成后实际冻结，才核语法并记录当时字节，之后不容变化。

根执行顺序（以下不是已执行结果）：

```text
python -B -X utf8 experimental/recovery-room-mask-native/prepare.py --check
python -B -X utf8 experimental/recovery-room-mask-native/prepare.py --build --registry-wait 900
python -B -X utf8 experimental/recovery-room-mask-native/run.py --drivers build/m52/recovery-room-mask-native-drivers-02 --check
python -B -X utf8 experimental/recovery-room-mask-native/run.py --drivers build/m52/recovery-room-mask-native-drivers-02 --output build/m52/recovery-room-mask-native-01 --registry-wait 900
```

`run.py` 复用原 recovery `run.py` 和 `tools/run_coop_regression.py`，不重新实现游戏启动、独占、内存、日志或清理。唯一原运行器内存适配是本驱动实际只写 `COOP EFFECTS DONE` 的完成标记；增加该 entry 后仍核双方 0–7 轮的真实 PASS、逐轮关键归属/像素断言、全部错误日志、准确版本、TCP、全部运行输入、注册未取消与安装不变。运行仍为全组合、180 秒、独立 AIR ID、私有桌面、6 GiB 启动和 512 MiB 运行保护。

原后置 PNG 检查为双方 case 0–6 共 14 张 `leave` 图，逐张复用 `verify_mask_png.inspect` 的原白块标准；case 0–4 另有双方 10 张 `sweep` 图，核存在与 SHA，并核对应真实 RV 清扫/无孤立遮罩日志。case 7 即时核后来接管的遮罩引用与缓存后结束，原驱动不生成截图，不能人为要求第 8 张图或省略其关键断言。每次都用新结果目录；失败不改判，不得替代实际加载耗时或密集场景资格。

本次仅准备源码、薄入口与静态语法核验，没有编译或启动 AIR，没有安装任何产物。
