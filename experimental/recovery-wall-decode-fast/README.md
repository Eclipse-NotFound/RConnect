# 准确 recovery20 墙块解码：两个窄改动，尚未运行

基线为 `build/m52/recovery-20`，正式产物指纹 `0674019c4aeea22900aef3e2390a31aed4fafc7850e0f3a74bc5ebb2facce9f5`。`inputs.json` 绑定正式回执、逐文件源指纹、原组件和本次配方。本目录只有源码准备和离线检查；未编译、未 AIR、未部署，不具有整体性能资格。

`e53cb3730a` 的七段数据重新求和：加入侧 **823** 次批次、1,640 条消息、240 个 full、648 个 fast，含多个 full 的批次为 **0**；主侧 222 次批次、787 条消息。双方合计 1,045 次批次，不能写成加入侧 813 次。相关最长单 `unitsync` 回调为 88 ms / 6 块 / 47,844 字符，以及 94 ms / 5 块 / 41,600 字符。该诊断和此前 CPU 采样支持检查解码热段，但没有逐载荷缓存命中证据，不能认定每次都冷解码。

只修改以下两处，各自可撤回，未混入普通房最终写色修正：

- `WallCellCodec.unpack`：每字符只取一次 UTF-16 编码，先判 ASCII 上界再查 128 项固定表；两个已验证字节合成一次 `writeShort`。padding、低位规范、输入限额、原生 inflate、展开长度、像素索引排序及 uint 值的检查顺序保留。`pack` 和 Base64 后的所有代码逐字不变。
- `WallImpactVisuals.decodeWords`：仅 W1 成功结果省去已经由 `WallCellCodec.unpack` 完成的逐词数值验证。仍保留空值/长度检查、缓存写入和独立返回数组；legacy 分支继续原样做 Number 强制转换与可变对象排除。没有提前做版本跳过，整包验证仍在像素更新/ACK 前完成。

未改协议、颜色、RoomCodec、频率、FIFO 缓存容量、版本、预测保护、ACK、整包原子性或任何发送游标。未增加另一种网络格式。

## 组件与测量

复用 `recovery-wall-encode` 的完整实际类及现有串行组件运行器。四个类副本只有类名、窄改动和原组件访问口不同：原版、仅字符/写入优化、仅 W1 验证去重、组合版。`prepare.py verify()` 逐一核对精确变换；无镜像算法代替生产 AS。

原 49 项功能/回放/传输检查保留；新增 17 项合法/非法输入、独立数组、整包和 ACK 边界检查，以及 1 项代表包规模检查，预期 **67 项**。包括非 ASCII/控制字符四个位置、坏 padding 和非规范低位、所有小载荷截断、非法 zlib、压缩与展开上限、重复/逆序索引、原 legacy 强制转换、旧版本坏块不能放行新块、匹配序号的坏 ACK 不得解除保护。历史 82 载荷/1,276 次顺序只作真实旧数据语义回放，不冒充本轮载荷分布。

完整解码 ABBA 有三个独立比较（原版→仅字符优化、原版→仅验证去重、原版→组合），每对两轮 ABBA，共 24 块；每块含七组输入：6 空块、6 稀疏块、1 满块、5 个 1,200 像素块、6 个 1,000 像素块、历史 82 个 W1、历史 82 个 legacy。大包使用确定性合成颜色，Python zlib 规模约 46k，AS 准备时再断言单包 40k–48k；并非截取本轮原始墙像素。

计时包含实际 `WallImpactVisuals.decode` 的包边界/坐标/去重、Base64、inflate、像素解析、验证及缓存写入；缓存 reset、结果 checksum、JSON 和文件 I/O 在计时外。每次先冷置缓存，空块相同载荷在包内仍自然命中；这测量冷解码成本而不是估计实机命中率。小样本的 0 ms 原样记录，不造精度。逐帧执行测量块；不改现有 60 秒运行器限制。没有 FPS 或卡顿解决结论。

根会话从 `mods/RConnect` 运行（新的输出目录，不覆盖失败记录）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 experimental/recovery-wall-decode-fast/run_component.py --source experimental/recovery-wall-decode-fast/components --entry WallDecodeChecks.as --expected 67 --output build/m52/recovery-wall-decode-fast-component-01
```

离线 `check_static.py` 核对全部 65,536 个 UTF-16 值的映射、262,144 个前三位组合的两字节写入、13,025 个确定性合法/畸形 Base64 字节模型，以及源码剥离、输入指纹和批次总量。其通过只代表静态/离线检查，不代替 AS3 编译或 AIR 结果。

## 后续普通房两处颜色修正

独立保留 `prepare_color_components.py` 薄复用入口。根合成完整候选后传入其 **完整 src**，该工具复制已有完整 85 项颜色组件；从所传新树取实际 `WallImpactVisuals/WallCellCodec/RoomCodec/WallSurfaceBridge/NativeWallColor`，只补两个最终 setter，不会用 18 的旧整类覆盖新解码段。85 项测试文本和独立颜色旧类逐字保留。此工具尚未执行，也没有把 setter 混入本次 67 项基线。

```powershell
# --source 指向根最终准确候选的完整 src；--output 必须是本实验内尚不存在的目录。
python -B experimental/recovery-wall-decode-fast/prepare_color_components.py --source <complete-src> --output experimental/recovery-wall-decode-fast/color-components
# 再由原 run_recovery_component.py 对该目录、WallSurfaceChecks.as、--expected 85 串行运行。
```
