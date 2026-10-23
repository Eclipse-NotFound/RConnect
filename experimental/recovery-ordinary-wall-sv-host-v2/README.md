# 普通墙面宿主 v2：仅修 FFDec 声明语法

根实际构建host02时，FFDec import退出1，原始stderr为 `SEVERE: CURLY_CLOSE expected but COMMA found on line 874`，对应新增桥的 `var left:Number=…,top:Number=…`。证据保留在 `build/m52/recovery-ordinary-wall-sv-host-02`；build.json SHA为 `4284E528D2A51B39197FA399667FAD9990A26F91ED87E2E393B397643EC7C1E5`，import stderr SHA为 `F53DB21BD25D07DB4161BE8A088DCA225CFA35C2915088E62F5DD31F65799C28`。没有覆盖host01/02或旧native目录。

本目录复制原生成器原字节，仅把新增桥的6组逗号多变量声明拆成15条顺序单变量声明：left/top、eraser/color/alpha、width/height/dx/dy、rangeValid/rangeError、source/destination、failed/failure。变量名、类型、初始化表达式及先后顺序不变。`declaration-split.json`记录所有6处前后文本、旧新源指纹与原失败指纹；完整生成Grafon已核为恰好这6次替换，Location与旧版逐字节相同。额外词法检查确认新增桥顶层多变量声明由6变0；这不是编译通过声明。

独立入口为 `experimental/recovery-ordinary-wall-sv/build_host_v2.py`，旧build_host.py未改。host03已prepare/verify通过并冻结；脚本SHA `34097A08E28A0C3F164BBE5638E4894F5F8B3B503563A06E6F65904C319EEC45`，host03 prepared SHA `2D44C8191A5E67427E21E053102EB3A0E36D785D30F4C8D17776264BCEDF9975`。本子任务未启动Java/AIR，由根执行 `build_host_v2.py --build --registry-wait 900`。沿用原ACC依赖链、UTF-8/en-US、全部资源/读回检查与内存/登记保护；旧版README列出的原生资产、异常控制流、像素和性能缺口不变。
