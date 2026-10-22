# Tail sampler v3：两处函数末尾返回

组件02被旧ASC控制流分析拒绝，尚未启动AIR。v1/v2及失败输出保留。仅在helper的attach、owns中将try/catch返回改成保存Boolean、末尾统一返回；真实adapter、替代类、31条组件断言及Doc逐字保留。return-origin.json给出精确前后片段与来源指纹；check.py还扫描全部具名非void方法的末尾返回。

根执行（此处未编译/运行）：

```powershell
& 'C:/Users/hello/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -B -X utf8 tools/validation/run_recovery_component.py --source experimental/recovery-early-paint-tail-sampler-v3/component --entry PaintTailSamplerComponentDoc.as --output build/m52/recovery-early-paint-tail-component-03 --expected 31 --registry-wait 900
```

其余采样范围与资格限制仍见v1；debug=false、optimize=true保持原驱动模式。
