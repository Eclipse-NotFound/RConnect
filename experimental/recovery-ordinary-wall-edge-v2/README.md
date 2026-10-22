# v2：编译修正与同像素反例，生产候选保持冻结

基于 `recovery-ordinary-wall-edge` 冻结清单 `17c19ab9…95dc4ca3`，原132断言保留。只改外部组件：显式 `import fe.weapon.Bullet` 并用短类名；Grafon 存根的枚举变量加 `:Object`；追加4条完整生产类检查。准确22和边缘候选的生产类均逐字不改。

旧 component01 未启动 AIR。Bullet 的未解析类/包是编译错误。Grafon 无类型枚举在已成功的85项 compile.log 中同样出现，但编译exit0并产SWF，属于既有警告；v2仍将它消除。旧失败不覆盖。

新增133–136：

- 两端原生基底相同，加入端先在可见底图上生成新色并留下待确认报告。主端随后把**同一像素**原生值擦为0，经实际候选 observe 收集，然后接受稍后到达的加入端报告。
- 133验证 ACK 和逻辑 checkpoint 确实接受新色；134要求双方最终 uint 一致。**当前候选预期134失败**：主端被 alpha=0 门挡住，加入端仍保留新色。不会将“发现漏洞”反转为产品通过。
- 135用完整准确22控制类在实墙格执行同一顺序，验证原有“后到颜色被接受”的行为。
- 136验证结构破坏在同一个 BitmapData 内清除后，不调用 redraw 就接收旧颜色也不得复活像素。这是后续任何支持缓存必须保留的边界。

组件是完整生产 WallImpactVisuals + 真实 BitmapData，Bullet/Grafon 等仍为外部载体。没有执行游戏原生资产，不能据组件声称某个原生动画已擦空。当前真实原生8发样本并未在那22点观察到 alpha 下降；源码可达性另见 feasibility.md。

根执行：

```powershell
python -B -X utf8 experimental/recovery-ordinary-wall-edge-v2/prepare.py --verify
python -B -X utf8 experimental/recovery-ordinary-wall-edge-v2/run_component.py --output build/m52/recovery-ordinary-wall-edge-component-02
```

沿原共享登记、超时、输入/安装复核。预期总136项，其中134为尚未修复的功能负例；实际回执须保持失败，不包装成整体合格。此目录仅准备，未编译/AIR。
