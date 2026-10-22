# 只编译选定原生驱动

此入口导入原 `experimental/recovery-tests/prepare.py`，只将该模块的 `COMPONENTS` 设为 `{}` 后调用原 `main()`。原工具不改动；源码冻结、完整生产声明、所选原生驱动、同字节 574D 对照、manifest、登记及所有原生运行断言保持原样。调用前后核对原工具 SHA-256。

从 `mods/RConnect` 执行（使用现有 Python）：

```powershell
python -B -X utf8 experimental/recovery-native-only-drivers/native_only.py --source build/m52/recovery-21/src --output build/m52/recovery21-targeted-drivers-02 --entries PeerGripTestDoc NativeFlightContinuityTestDoc --build --registry-wait 900
```

运行继续用未改动的 `experimental/recovery-tests/run.py native --drivers build/m52/recovery21-targeted-drivers-02 --entry <原生入口> --output <新的build/m52子目录>`，需要 574D 同字节对照时加原 `--control`。不要传 `--components-only`，本入口不提供任何组件资格。

01 的 `compiled=false` 与编译错误保留：其两个原生驱动和 aura 已编译，最后 impact 组件因旧裁剪闭包缺 `ProjectileExplosionVisuals` 失败。完整生产声明已经包含该类；原生流程不依赖这个裁剪组件。新入口仅免去此次无关组件，不把失败01改绿，也不扩它的闭包。

原 manifest 的 recipe 指纹仍指向原 prepare，故原运行器可直接校验。此适配器另由本目录 handoff 记录；不改 manifest 格式或运行器。交付时比对失败01登记的127份 `.as/.py` 原始输入，全部未变。仅静态检查完成；本交付没有启动编译器或 AIR，没有原生通过结论。
