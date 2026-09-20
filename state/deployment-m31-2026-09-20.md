# 2026-09-20 M31 共享探索正式部署

按用户“替换正式版本”授权，部署固定已验产物；不重编译并行开发中的M32源码。

| 模组 | 版本 | 字节 | SHA256 |
|---|---|---:|---|
| RConnect | 0.2.3-dev / M31 | 50175 | 0e00e4f8f1ba74842b6227b7311ccfd47c4ff3e212afc4132e051e39c3277157 |
| RealisticVision | v0.30.0-candidate | 22310 | ce3abb8d1321df4f2a6e1053ecbb44aabff66a6e27f81b517d3a341b3a8dfb5b |

两文件均已写入各模组release。RV保留最新ModSettings注册与配置保存修复。源码基线RC e127ab7、RV f77fffe；dev/candidate为保留的构建标记，不代表尚未安装。当前工作树M32/0.2.4属于另一任务。

## 验证

- 复用最终RC+RV联测104 PASS、RV独立37 PASS及包内容检查；无RV联测103 PASS发生于最后保护性小改前。详细边界见M31实现报告。
- 部署前核对application.xml指向根pfe.swf（1.02），七个loader含RC/RV/ModSettings。根SHA 9a81430d775209e37e8e7fd54414057995e0680671445f38797623865b5a699a。
- 正式路径最终独立双实例46b70da446 PASS：双方0.2.3初始化、tick200、welcome/单位同步，双方RV0.30初始化与tick181。冻结M31脚本最长150秒，条件满足即结束；PID66396/66760与临时副本已由脚本清理。
- 首次5372c2cfae的50秒窗口仅宿主有tick200，原脚本末尾漏检加入侧而误PASS；人工收紧后立即恢复两份备份。修正为双方版本和心跳必检。
- 延长轮ec2ea306f3双方tick1000、RV心跳正常，但并行M32任务把共用脚本版本断言改成0.2.4而报FAIL。最终用冻结M31脚本验证，避免共享测试源码竞争。
- 冒烟只加载RC+RV，不算七模组完整联合作战/长期性能验收。训练房Area构造仍有既有#1063跳过，不宣称全日志零异常。
- 游戏三份SWF、描述符、配置模板指纹未变；本任务只写两份目标模组SWF。同期MSW正式SWF由其他任务更新，差异已记录JSON，未回滚或覆盖它。用户进程与存档未操作。两个模组均无独立changelog，以README/MEMORY/journal记录版本。

## 回滚

本轮唯一备份目录名m31-release-20260920-151712-770633。若撤销共享探索，从游戏根目录执行，再正常重启双方；不要恢复旧游戏SWF或ModSettings整包：

```powershell
Copy-Item -LiteralPath 'mods/RConnect/build/backup/m31-release-20260920-151712-770633/RConnectMod.before.swf' -Destination 'mods/RConnect/release/RConnectMod.swf' -Force
Copy-Item -LiteralPath 'mods/RealisticVision/build/backup/m31-release-20260920-151712-770633/RealisticVisionMod.before.swf' -Destination 'mods/RealisticVision/release/RealisticVisionMod.swf' -Force
```

RC恢复M30（97bf59ed…1995），RV恢复v0.29+ModSettings（47403d06…407aeb），不是旧5c26d604版本。完整指纹/输入/日志哈希见[部署JSON](deployment-m31-2026-09-20.json)。

双方保存并重启后，在F10“接收队友探索”或模组设置页各自开关；关闭保留已收到区域，RV遵循自身模式和记忆亮度。
