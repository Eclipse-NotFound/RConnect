# host-02 导入失败的最小修正

失败证据：`build/m52/recovery-first-raster-host-02/import.log.stderr.log` 在 Grafon 第 2794 行报告 `Unknown preprocessor instruction: §§findproperty`。没有 AIR；原失败记录保留。

这不是 E4X。准确 E159 导出中，`sceneDrawSteps` 的匿名函数使用外层捕获变量 `i`、`j`；两处递增被 FFDec 输出为 scope lookup 的伪指令。原片段读取该变量、`Number(...) + 1` 后写回；递增结果没有其他用途。只把这两段分别恢复为 `j++;`、`i++;`，保留捕获变量、数值转换、循环边界、遍历顺序及绘制调用。

只读对照：`mods/ContinuousScene/build/generated/sats-viewport-20261021-combined/source/fe/graph/Grafon.as`，SHA `6e93bad61f647249652a38249ed52007dbf14d3b9bd38a153e939ce8b446d051`。该目录 `build.json` 为 compiled=true，SWF `7d423bd7b7dd7d2b997e692bd1e22ef520879cd42387c14653c116c15385bcd4`，`pfe.audit.json` 标明仅重编 Grafon。修正后的完整 tile 循环去空白后与该来源相同。只借其确认这两个递增，不复制该文件其他方法。

生成器对两段各强制唯一命中；静态检查要求除这两段外整个 sceneDrawSteps 不变，并拒绝导入源码中的所有 `§§` 伪指令。readback 可能再次产生反编译伪指令，因此仅在输入导入前检查其可编译性，不将反编译文本本身当编译源码。

Grafon SHA：final-02 `f335ba3257c253e480f4b4bd1992ff0d4c701cc2d2089229f3cd660b7ea5b15e` → final-03 `976526e741392904bb2575c7e6c73055cdb589ae177e033ad9fdebcc6faa850d`。

RC 五个覆盖和三个组件全部 AS 文件保持不变；component-inputs 只更新原生来源指纹。现有组件不执行 sceneDrawSteps，仍需新 host-03 的实际导入/回读及之后原生验证。本次未启动 JVM/AIR，不改安装版或 CS 文件。
