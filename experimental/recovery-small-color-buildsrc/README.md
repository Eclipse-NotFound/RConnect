# recovery22 完整源码快照

准确 recovery21（`9ac7ede7…8b7e7ba`）只合入已测 `WallImpactVisuals.as` 的两处最终写色修正：`put` 与 `replay` 写入 BitmapData 时调用 `NativeWallColor.setter`。逻辑颜色、线上颜色、ACK、预测保护、频率和缓存容量不变。21 的两项解码优化完整保留，未拿 18 的旧整类覆盖。

完整 **90 个 AS 文件，88 个逐字节不变**；另两个是墙面类和仅版本号变化的 `RConnectMod.as`（`0.2.24-recovery22`）。`two-setters.patch` 是全部业务差异。沿用既有源码冻结助手，`integration.json` 可由正式配方直接读取。

已由根会话实际完成的组件：`build/m52/recovery21-small-wall-component-01`，**85/0**；Checks SHA256 `c456e3fae4f692ab5de2252886698032025656fec6e47b301ed559059a649dd0`。本快照绑定其完整生产类、实际断言、回执、产物与输入，源码和安装核验均未变。覆盖普通房收到与重建回放时六种真实颜色、原类半透明颜色丢失反例、重复版本及邻近背景保护，也保留原大图/预测/ACK 全部检查。组件不是整局或性能资格。

以下命令均在 `mods/RConnect` 下执行；此交付只运行过源码准备和 `--verify`，没有编译、启动 AIR 或部署。

```powershell
python -B -X utf8 experimental/recovery-small-color-buildsrc/prepare_sources.py --verify
python -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-22 --source experimental/recovery-small-color-buildsrc --version 0.2.24-recovery22 --build
```

## 已有大图原生复测入口

准确 ACC 宿主仍是 `build/m52/recovery-wall-surfaces-host-01/pfe.swf`，SHA256 `acc336b5f28012a5f0d2ef57d0a3bf46be46f72f1e4c3a69a2f063cae0535dfd`。其最初 `prepared.json` 的回读失败保持不动；现有薄适配器要求 `recovery-wall-surfaces-host-recheck-01/receipt.json` 的独立回读核验，并核对实际 SWF、导入与回读输入、前后 22 项安装输入。不能只看 `compiled` 或 `kind`。

22 编译后最小复测命令可复用同字节 driver04（`EffectsDriver.swf` SHA256 `faae7ed401cc347a3db9b98cebaa28b13a36f6d57c356d4a5fb1da188222bccb`）：

```powershell
python -B -X utf8 experimental/recovery-wall-surfaces-native/native_tool.py run --candidate build/m52/recovery-22 --drivers build/m52/recovery-wall-surfaces-driver-04 --game-candidate build/m52/recovery-wall-surfaces-host-01 --output build/m52/recovery22-wall-surfaces-native-01
```

必须显式指定宿主；省略时工具默认 FD92。输出目录必须全新。四轮是双向轻机枪、速射等离子真实 `Bullet.tilehit`，显式要求 `sceneLarge` 且命中远坐标，读取真实 `nativeBuffers`，没有把小块 scratch 或粒子火星当成墙痕。原来大于 5 个变化像素、逐 uint 精确比较、时限、22 项输入审计均保持。

原 driver04 附带的 PNG 检查会误拒原生 PNG 与 `getVector` 的颜色表示差异；原结果必须保留。已有独立复核只修正 PNG 表示核对，**源→对侧每个 uint 仍严格相等，不容许任意 1 级色差**：

```powershell
python -B -X utf8 experimental/recovery-wall-surfaces-native-proof-review/verify_evidence.py --evidence build/m52/recovery22-wall-surfaces-native-01 --output experimental/recovery-wall-surfaces-native-proof-review/recovery22-reanalysis-01.json
```

这两条都是已有工具入口，尚未执行；第一条返回失败时仍应保存其证据，再独立复核，不能把原框架通过等同于墙面像素通过。

## 普通房原生入口的现存缺口

真实持久墙痕旧驱动是 `tests/WallImpactTestDoc.as`，并非 `WallBallisticTestDoc` / `WallEnergyTestDoc` / `WallMagicTestDoc` 的火星粒子覆盖。旧驱动有原生枪击、严格 `wrong==0`、重复包不变暗和原生离房重返检查（约 296、322、344 行）。但没有找到已冻结、可直接由当前 ACC 宿主适配器执行的这一入口：

- `tools/validation/run_final_regressions.py` 登记了它，但约 122 行只接受 m46–m50 的 `final` / `red-` 快照；没有 `--game-candidate`，不能把上述 22/ACC 参数直接套入。
- `experimental/recovery-tests/prepare.py` 的现行入口没有它；大图 `native_tool.py` 则严格只接受 `LargeWallSurfaceTestDoc`，不可换名字冒用。
- `tools/build_effects_driver.py --entry WallImpactTestDoc` 能编译该旧类，底层 `run_coop_regression.py` 也有宿主覆盖参数；但这并不补足 ACC 独立回读和当前驱动的完整审计。旧类直接读 `frontBmp`，没有排除 `sceneLarge` 的 scratch；约 123 行武器准备也未走现在大图夹具已修正的原生背包装备路径。它们是复用前应核实的夹具风险，不能认作本轮产品失败。

因此本次只定位入口并记录缺口，没有提供一条绕过现有门禁的“普通房已可复测”命令，也没有新造框架。普通房最终写色当前有 85 项真实生产类组件证据，尚无准确 22+ACC 的普通房原生复测证据。后续若沿用旧驱动，只需在既有外部框架内补普通房准入、原生装备准备及准确宿主绑定；保留原严格像素断言。
