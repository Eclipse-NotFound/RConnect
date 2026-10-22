# recovery17：准确14加地形采集单变量

本目录是完整生产源码候选，尚未编译或原生实测。准确基线`build/m52/recovery-14` / `225a7940…be5f7`；88个AS文件中仅TerrainSync和版本号不同，其余86个逐字节一致。没有合入15姿态优化或16墙面修改，不改变活动integrated或安装版。

TerrainSync覆盖来自`experimental/recovery-terrain-capture/src`，与已运行组件的实际输入逐字节一致；只将capture中真实Tile的无变化判断缩至phis/hp。完整旧新类组件`recovery-terrain-capture-component-01`已经154/0、源与22项安装输入未变，组件SHA为`b9b6bbd45ae67b9e033e8a4d6c451fc57683c3eb54f098fdc328781e62fc8bed`。

ABBA原始数据：旧A1 171ms、新B1 113ms、新B2 114ms、旧A2 199ms；每槽5次×30,000格，全部没有异常请求。构建、baseline、暖扫描、断言及序列化均在计时外。这只说明该独立组件调用的成本，不能推出双人帧率或加载时间已经合格。

`integration.json`满足正式prepare的version/static_errors/source指纹接口；另绑定准确14的88文件、祖先integration、已运行组件intent/receipt/result及原始成本。`handoff.json`保存简要结论和正式命令。旧覆盖目录和其源清单保持不动。

纯Python复核（不写、不编译）：

```powershell
python -B -X utf8 experimental/recovery-terrain-capture-buildsrc/prepare_sources.py
```

由根会话统一编译，随后用同driver02密集场景作单变量对照：

```powershell
python -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-17 --source experimental/recovery-terrain-capture-buildsrc --version 0.2.24-recovery17 --build --registry-wait 900
```

没有另建runner或二进制复制步骤。编译、实际加载、原生破坏/ACK/换房、密集帧率均不能借组件154/0宣告通过。
