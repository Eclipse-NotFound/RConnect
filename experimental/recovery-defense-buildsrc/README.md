# recovery20 完整源码交接

准确基底：`build/m52/recovery-19`，实际候选SHA `b9cd3f4800f2e875439b19f9d18969fd195ed039c992df3b0625cf0cf2dfeea5`。本目录仅组装AS及文本，没有编译、AIR运行、安装或其它模组修改。

90份AS中，88份与准确19逐字节相同。仅改变：

- `rconnect/game/GameBridge.as`：原NATIVE_UNIT_FIELDS表追加已审阅并经81项实际组件验证的18个公共变量。除该表外逐字节相同；没有用旧整类覆盖19。
- `RConnectMod.as`：只把版本字符串改为`0.2.24-recovery20`。

因此完整保留19的墙面编码等全部已有改动，不混入15姿态或17地形采集实验。公共名单可追加未知字段的边界按最终安全方案保留；一次判类型的三行草稿不在本目录。

集成清单：`integration.json`，SHA `2ec4794b43e056201dd532d8776c619480b382aed5facaebacd9d70de512bd20`。新GameBridge SHA `260cebd0f89e348979d05d00338f7e444a1abf2c0bbe4d03350475b05e01142d`。源清单、准确19的prepared/integration和全部90源、已审阅表项、组件receipt/intent/result及12份组件输入均有指纹绑定。

局部实际结果见 [component01-review.md](component01-review.md)：81/0；原生20000次ABBA为旧517/新275/新273/旧549ms。只支持局部采集成本下降，不外推游戏帧率、端到端延迟或发布资格。

根会话后续沿正式入口构建，工作目录`mods/RConnect`：

```powershell
python -B -X utf8 tools/validation/prepare_recovery.py build/m52/recovery-20 --source experimental/recovery-defense-buildsrc --version 0.2.24-recovery20 --build --registry-wait 900
```

本子代理没有执行该命令。不要在冻结后重跑assemble.py或修改本目录源码；组装器拒绝覆盖已有src/integration。

首个组装尝试在写源前发现稀疏提案LF、19冻结源码CRLF导致全字节检查失败，记录于`assembly-attempt-01.json`。已修正为只提取表项、使用19原换行插入，随后验证88类和两个文件其余字节全部不变；没有覆盖原失败或以规范化后的比较代替最终字节核对。
