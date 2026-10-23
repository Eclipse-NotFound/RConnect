# 加载文字占位符最小修正

基底：`build/m52/recovery-room-production-02`，准确产物 `c26b1aa7dccf6e96c4027f551332a2b55d413467b24311426a20c8d341058cc0`。本目录只有源码及组件准备，**没有编译、AIR 或部署结果**。

根实测发现加入侧等待图显示 `*gui_loading`。原生 `World.as:1513` 在 setLoadScreen 中用 `Res.guiText("loading")` 初始化它；仅房间屏障可能尚未调用过该入口，RoomEntryView 因而复制了素材默认值。直接调用 setLoadScreen 会更改输入、剧情等待和显示状态，不适合文字修正。

`src/rconnect/ui/RoomEntryView.as` 只在源文字精确等于 `*gui_loading` 时，从 `world.main.loaderInfo.applicationDomain` 取得原生 `fe.Res`，调用同一个 guiText。每次 show 只解析一次，scene/SATS 两份克隆共用结果；不写源 vwait，不改变其它状态。已初始化文字、进度、错误和有意留空全部原样复制。资源暂不可用、异常、空/null 或仍返回 marker 时保留原文，不凭空指定另一种语言。

- 源码 SHA：`4cb479f39262f631b834c6290f78fcaec3b3cc102bb56f9886a71791a05efe0b`。
- 准确一类差异：`source.diff`；输入绑定：`source-manifest.json`。
- 组件入口：`components/LoadingTextChecks.as`；source-path：`components`。真实 RoomEntryView，只有原生素材和 fe.Res 边界由显式替身提供。正常完整执行预计 20 条；catch 会另记 FAIL，不能以条数判断通过。
- 反例入口：`components-baseline/LoadingTextChecks.as`，只把 RoomEntryView 换回准确原类 `969ffe5824685edb1bdfab3b35f9e77dbcedd4eb14b012495611277d5b7f025c`，其余夹具相同，应暴露 marker 不本地化。
- 组件证明文字处理和副作用边界，不能代替实际主/加等待截图；根负责登记后串行构建和验证。

最初一条混合“读基底指纹+写源码”的准备命令被本地护栏以 binary-swf-use-release-pipeline 拒绝，未执行。随后分成独立只读指纹核查和明确只写新 AS/文本的命令成功；没有维护授权表或改护栏，没有修改基底和安装版。
