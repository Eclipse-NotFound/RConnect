# 单人尾段：模组优先级前后界

严格基于冻结 `recovery-paint-enter-bands`：AS 仅改 8 条监听器登记的 priority 和对应数组；新数组为 `[-79,-81,-99,-101,-199,-201,-6999,-7001]`。其余采样器、标记逻辑、同帧/身份/时钟核验、最多 8 条及缺失原因、-1/最低/RENDER 标记、原三个场景断言全部保持不变。未修改外部模组或生产源。

目标区间为 LAD -80、WallBlend -100、ContinuousScene -200 的前后界及 -7000 前后。它们仅围住同一 Stage 的优先级顺序；同优先级可能还有其它监听器，回调也可能调用别的模组或原生方法，不能只凭区间名称直接归因。观察开销与旧边界限制仍保留。

这轮是最后一次缩小单人尾段范围；此前准确 bands 实测结论见 `../recovery-paint-enter-bands/RESULTS.md`：主要成本在 -1→-7001（2561/2522ms），-9001→-10001 仅 4/6ms。后续由主会话回到加入侧 restore 的既有实证，不在这里新增其它探针。

仍为单一 entry.py，只有两个 kind 从 bands 改成 modules。身份：`scene-native-input-enter-modules-driver` / `ensure-work-enter-modules-v1`；新 source pins 和从 v3 生成的完整 diff 均已保存。旧冻结包、MEMORY/journal 未改；未编译或启动 AIR。

根从 RConnect 目录执行：

```text
python -B -X utf8 experimental/recovery-paint-enter-modules/entry.py check
python -B -X utf8 experimental/recovery-paint-enter-modules/entry.py prepare --output build/m52/recovery-paint-enter-modules-driver-01 --build --registry-wait 900
python -B -X utf8 experimental/recovery-paint-enter-modules/entry.py run --candidate build/m52/recovery-early-exit-compile-01 --drivers build/m52/recovery-paint-enter-modules-driver-01 --game-candidate build/m52/recovery-early-paint-host-03 --output build/m52/recovery-paint-enter-modules-solo-01 --scenario scene --solo --sand-mode bridge --registry-wait 900
```

原 bands/analyze.py 精确固定旧优先级及旧二进制，不适用于此新身份，勿冒用其旧准入。
