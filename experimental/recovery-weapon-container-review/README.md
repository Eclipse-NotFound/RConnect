# 武器结果容器：等价通过，局部收益不足以继续整合

根会话实际执行 `build/m52/recovery-weapon-container-component-01`，完整旧新 RemoteMotion 与实际 WeaponDisplay/TeleportVisuals 的 70 项组件通过，AIR exit 0。源与22项安装输入均不变，自有组件进程已退出。组件 SHA `5a6870991f024ea708ad98f43fc33b68bbf339c1c2c151bd4605ca38c3645cd7`；准确候选覆盖仍仅 `experimental/recovery-weapon-container/src/rconnect/game/RemoteMotion.as`，未合入任何完整生产候选。

唯一改动复用 `WeaponDisplay.interpolate` 的新结果数组，减少第二个数组和逐项 push；兼容项复制、嵌套对象引用、插值与全部时钟未动。70项覆盖现代显示、兼容记录、重复引用、稀疏/命名输入、NaN/有限角差、公开 push/sample/settle 与同戳修订；不声称穷举外部修改 Array.prototype 或一切游戏模组。

原生 AIR 小循环，每块12,000次、每次4武器，无游戏加载：

| 输入 | 旧 A1/A2 ms | 新 B1/B2 ms | 旧→新均值 ms |
|---|---|---|---|
| 现代 display | 306 / 321 | 309 / 296 | 313.5 → 302.5 |
| 无 display 兼容 | 212 / 221 | 216 / 201 | 216.5 → 208.5 |
| 混合 | 274 / 265 | 259 / 306 | 269.5 → 282.5 |

全部计时块输出和输入所有权检查通过；计时外才序列化与核对。现代/兼容均值稍低，混合反而更高，单轮区间重叠，未形成稳定收益。每次少一个数组由源码可以确认，具体分配/GC成本没有单独测量，更不能换算游戏帧率或解释此前100–249ms长空档。

决定：保留等价实验，不创建完整 recovery24、不启动仅为这处变化的双实例性能轮，不宣称高速运动已修复。安装保持574D。没有修改原70条断言、计时结果、原失败或部署状态。
