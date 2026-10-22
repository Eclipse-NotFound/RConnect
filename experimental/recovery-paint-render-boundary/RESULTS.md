# Stage RENDER 边界实测

2026-10-22，`build/m52/recovery-paint-render-solo-01` / `cf820db4d7`。准确驱动 `55a35707298a1d86011841a8f63738a215ccaae31efb1ada614779b060efc80e`，原宿主host03、early2、Sand003、隔离RV7852不变。当前安装RV83D8及其余21项均未改变；只运行自有后台单实例，原35项操作检查通过，副本已清理。

| 流程 | 原生就绪 / 操作响应累计 | 首次ensure | tail总长 | 首次Stage RENDER前 | RENDER标记跨度 | 末标记到下一ENTER |
|---|---:|---:|---:|---:|---:|---:|
| 首进 | 7251 / 7805ms | 875ms | 1896ms | 1878ms | 1ms | 17ms |
| 重访 | 3550 / 4032ms | 830ms | 1891ms | 1873ms | 2ms | 16ms |

表内分段采用getTimer；首进墙钟对应1879+1+16ms，存在1ms读钟差异，顺序没有冲突。返城1779 / 1934ms，没有触发目标首次ensure，不推断其绘图耗时。

两个窗口各收到4条连续的high-low-high-low标记，无溢出、fault或回拨，均在原startStage内；下一Stage ENTER结束原采样。独立核查了18个编译输出、7个原复制文件、三个场景断言及另外三个观察类；原12个采样/身份/finish方法和sampler API顺序不变。新增监听器仍有开销，不能声称零扰动；其卸载字段没有进入原SUMMARY，未取得独立运行卸载证明。

约99%的尾段在首次Stage RENDER标记之前。这排除了本轮同一Stage上这两对high→low RENDER回调占用近两秒，尚不能定位具体函数：其前仍可能包含剩余ENTER回调、其它显示对象广播、时间轴、布局及原生准备。两对事件不等于两帧，Stage优先级不代表整个显示树顺序。Flash样本仍0；这轮没有外部进程CPU计时，不能把18893的CPU数值贴到本轮。

未作工作量匹配性能对照，不将耗时变化作为优化收益；加载目标仍未达标，安装保持574D。下一步仅增加同一Stage最低优先级ENTER的单个时间标记，继续分割剩余区间，不先改生产位图算法。

可核对脚本`analyze.py`与派生回执`build/m52/recovery-paint-render-solo-01/render-alignment.json`；原结果和失败历史不改。
