# 高速夹具：原生空白动画帧的可核对例外

仅测试夹具覆盖；不修改生产、原 continuity-extra 或冻结 drivers11。基线驱动 SHA `E530E573…26C5BF`与冻结 drivers11 源一致，旧 analyzer `33F031F5…05FDE00`。准确指纹见 `inputs.json`，四处驱动/分析器方法差异见 `fixture.patch`。未启动 JVM/AIR，尚未编译或实机验证新夹具。

## 修正范围

旧 `getBounds`交集把原生零面积末帧也记为 offscreen。新 point仍保留原始 `viewport/screen/f/x/y`，只新增 `emptyBounds/outsideViewport`。原始 `offscreen`计数也保留，不删除 f4、空帧、同游戏帧的第二次RENDER或任何旧轨迹。

原生夹具和独立Python分析器都只改变同一个越屏判据：

- **有面积且viewport=false一律失败**，即使源端也在屏外。
- 任意远端零面积帧，必须在本轮源端实际 Bullet 的 RENDER记录中找到相同 `f/x/y`，且 `screen.x/y/w/h`全部逐值相同、同为零面积的证据。源记录必须有原生x/y和布尔ended；wire、推算终点及单独的帧号都不算证明。
- 不使用路径3px容差、终点0.25px容差或元数据1ULP容差放行空帧。缺bounds、非有限数、负尺寸、假empty标志、远端独有空帧都失败。零面积指width或height为0；不将“特别小”算零面积。
- 每条远端clip都检查，证明记录输出源/远端行号、游戏帧号和完整匹配值。重复RENDER可以引用同一真实源帧，但仍保留在原寿命/时间统计中，不因此获得额外持续时间。

运动85ms、相对gap、路径3px、末段覆盖65%、尾距、接触至少两游戏帧、像素、动画、500ms移除及所有其它原判据原值原逻辑保留。独立分析器沿用键`all_remote_samples_in_viewport`以免破坏读取方，含义现在明确为“有面积在窗口内，或有完全匹配的原生空帧”；新增`viewport_evidence`解释每个例外。

## 文件与接入

- `NativeFlightContinuityTestDoc.as`：完整单文件稀疏覆盖，仍调用原生游戏公开操作；仅point采样及最终viewport判定改变。
- `NativeFlightBounds.as`：**必须一并放进新驱动source-path**。纯判定辅助类，无生产依赖、无渲染或网络操作。匹配扫描只在采样结束evaluate时运行。
- `analyze.py` + `bounds_evidence.py`：新独立离线分析器，须一并归档；输入指纹包含辅助模块。
- `prepare.py`：校验基线SHA后，只在本目录重建稀疏覆盖/diff/manifest。无编译、AIR或安装操作。
- `test_empty_frame.py`：纯离线反例，复用原8个回归的断言，并仅给旧合成点补正面积bounds输入；新测试覆盖空帧证明、远端独有空帧、实际越屏、错帧/坐标/bounds、缺真实原生记录、额外clip、畸形输入，以及空帧不豁免像素/寿命。
- `audit_offline.py`：运行离线检查，并只读两轮历史16组轨迹逐字段对照。仅写本目录`offline-receipt.json`，原始历史失败不改。

`native_tool.py`提供独立的新目录冻结／构建／运行入口。声明SWC以指定候选的全部生产类生成（因此包含07新增的Explosion闭包），GameCombatStubs来自同一候选；Harness沿用原配方。只构建`NativeFlightContinuityTestDoc`，不编译旧generic components。两个AS、两个Python分析文件、原离线回执、基线差异及适配器／公共构建／运行工具指纹一并冻结。不要把新AS复制进生产源码。

从RConnect目录调用（以下是准备好的命令，尚未执行；输出必须选未使用的新目录）：

```powershell
python -B -X utf8 experimental/recovery-flight-empty-frame/native_tool.py prepare --source build/m52/recovery-08/src --output build/m52/recovery-flight-drivers-14 --build
python -B -X utf8 experimental/recovery-flight-empty-frame/native_tool.py run --drivers build/m52/recovery-flight-drivers-14 --output build/m52/recovery-flight-native-08
python -B -X utf8 experimental/recovery-flight-empty-frame/native_tool.py run --drivers build/m52/recovery-flight-drivers-14 --output build/m52/recovery-flight-control-04 --control
```

去掉`--build`仅冻结；同一输出只允许再用原命令`prepare --build`完成首次编译。有过编译（含失败）的目录必须换新名。候选源必须已经编译；脚本不构建生产。两次运行使用相同新驱动与Harness字节；control仍绑定574D。原runner的22安装输入、6GiB启动余量、512MiB运行余量、独占与隔离桌面、注册表、8组360秒场景、全部模组日志、独立轨迹分析与原性能资格标记均保留；适配器增加自身及公共源工具的前后指纹检查，不把功能通过标成性能达标。旧失败结果不覆盖。

`test_native_tool.py`是无编译器、无AIR的适配器反例：替身只替代编译／实际runner入口，不替代路径、绑定和冻结文件校验。检查单入口、四个新输入、禁止旧组件、资格削弱拒绝、工具变化拒绝及control失败仍失败。此项不能替代真实编译与原生运行。

离线运行：`python -B -X utf8 experimental/recovery-flight-empty-frame/audit_offline.py`（从RConnect目录）；独立analyzer的CLI参数与原来一致，输出必须是新文件。

## 现有证据复核

`offline-receipt.json`保存实际28/0离线检查与源指纹。历史 native06 / `18f969414e`只改变case1这一项分类，两条f4空bounds都找到源row68的精确匹配；574D / `7d1c0cb805`只改变case0这一项，两条匹配源row36。其它各case检查及原始运动、gap、路径、尾段等所有统计逐字段与旧analyzer一致。

这只是确认误报成因和新分类边界；两轮原`COOP FAIL`仍被新analyzer保留，原结果仍失败，不重新授予历史通过资格。AS辅助类只做过静态阅读，**Python离线通过不能替代新驱动的编译/AIR结果**，也不代表高速运动问题已修复。
