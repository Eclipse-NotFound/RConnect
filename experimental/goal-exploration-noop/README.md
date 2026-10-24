# 接收相同探索历史时保留已成功应用的记录

基底是准确 production-05 / 已安装 78C052（roomfix5）的 81 类。生产只改 ExplorationSync.receive 中的记录分配：先照旧完成校验、解码、握手和 union；仅当原记录 key 相同且 union 后每一行严格相等时保留原记录。收到新 bit 或更高亮度就仍新建记录并清 apiApplied。received 计数、返回值、applyRV 调用、发包频率和内容、渲染路径完全保留，旧 data 不就地修改。另一处仅是版本 0.2.24-explorationnoop1，其余 79 类逐字不变。

只依赖现有“同一个 API 已成功应用该历史”的标记，不新增缓存层或接口。API 更换、先前返回 false 或抛错后重试仍经过原 applyRV。真实 BF4A RV 对共享历史做最大亮度/位或并集，未变数据的再次 merge 没有可见副作用；房间重访由 RV 自身 sharedRooms 恢复。此判断绑定当前版本，未承诺任意第三方在同一 API identity 下私自清空存储的实现。

组件使用两份完整真实 ExplorationSync：候选原字节、78C 控制组仅改类名。两个独立 fixture 驱动公开 packet/receive/resetLink/setEnabled 与真实 EventDispatcher 的 RENDER；不公开生产私有字段。小型 RConnectMod/场景依赖及记录式可选 API 是测试替身，不加载真实游戏或 RV。API 只用于观察 merge 次数及输入；原生 fallback 使用实际 BitmapData，比全部 25 像素，并确认 visi/t_visi 不变。

21 个边界逐项比对旧新网络和显示状态：未确认握手、首次确认、重复 full、降亮、空 delta、新 bit、更亮、关闭接收及后续 delta、API 替换、false 重试、抛错与原生 fallback/重试、API inactive、分房与重访、重连握手、相同对象 key 变更、同 key 新对象、新 Game 清历史。另直接检查真正空合并只在候选省掉、变化仍合并、先前传入 API 的旧数组没有被后续接收篡改。不存在依据每帧事件次数推断 GPU 绘制次数的测试。

仅源准备；组件与实机结果均未产生，不给性能资格。根运行，其他会话不启动编译/AIR：

```text
python -B -X utf8 experimental/goal-exploration-noop/prepare.py --check
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/goal-exploration-noop/components --entry ExplorationNoopComponentDoc.as --output build/m52/goal-exploration-noop-component-01
python -B -X utf8 experimental/goal-exploration-noop/build.py build/m52/goal-exploration-noop-product-01
```

构建直接复用原 production-v5 有界编译器（共享登记、1 GiB 编译启动、512 MiB 运行保护、自有 Java 回收、安装不变）；新 build.verify 明确要求成功 compile.json。source-manifest 固定基底、两类 overlay、组件依赖、工具与差分；冻结后不再编辑。
