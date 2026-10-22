# Tail sampler v2：仅拆分替代类

组件01被旧ASC以“多个外部可见定义”拒绝，未启动AIR；原目录及失败保留。本版仅将 FakePaintTailApi 移至同名AS文件并改为public，helper、真实adapter、入口Doc逐字不变，断言仍31条。来源见 split-origin.json。未编译/运行。原采样范围、资格限制和用法见 ../recovery-early-paint-tail-sampler/README.md。

根的组件命令（本次未执行）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-early-paint-tail-sampler-v2/component --entry PaintTailSamplerComponentDoc.as --output build/m52/recovery-early-paint-tail-component-02 --expected 31 --registry-wait 900
```
