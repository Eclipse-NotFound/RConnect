# 暂停补发组件的类名修正

原 component01 编译失败，尚未运行 AIR；保留原失败和准确 23 生产目录不变。原因是控制组生成使用全局 `CoopPause→ControlCoopPause`，误将原有 `game.setCoopPaused` 改成不存在的 `game.setControlCoopPaused`。

本目录只修组件。生成器精确替换原 22 的类声明和构造器声明，反向替换后要求与准确 22 `CoopPause.as` 逐字节相同。组件 `PauseFlushChecks.as` 全文保持不变，仍为预期 50 条断言；其它外壳也保持原文。这里没有新的生产候选或成功实测结论。

主会话可用原组件运行器和新的输出目录：

```powershell
python -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-pause-flush-component-v2/components --entry PauseFlushChecks.as --output build/m52/recovery-pause-flush-component-02 --expected 50 --registry-wait 900
```

仅文本生成／核对使用 `prepare_sources.py --materialize`／不带参数。该脚本不启动编译器或 AIR，不写原组件、23 源码或冻结结果。
