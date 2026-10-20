# 隔离组合测试不能只复制 SWF 和配置

2026-10-20，RConnect 房间加载实测。Windows AIR / Remains 1.02；本次 CS 安装版本0.8.2，SHA cd65cec6c763ef18b345bcc1208baaa4911e02bdb1f557fe316ebbabff9bd856。

## 观察和纠正

复制器按加载清单只复制各模组SWF、config.txt、config.json，遗漏ContinuousScene/release/scene.xml。加载器仍记录init成功，但该模组在稍后的register读取地图资源时发生#3003，只写入自己的ContinuousScene.log。RConnect主日志和专项断言不能发现这项初始化失败。

从7轮唯一AppID恢复13份原始CS日志，全部包含register #3003：证据索引 `build/m52/room-runtime-assets-audit-01.json`，各轮 `recovered-module-logs`。原功能断言不改写，但撤销其“完整CS组合合格”解释。启用合并开关的f5ddf301b2还因初始化不完整而在moveObject发生#1009；不能据此归因CS安装缺陷。

复制器补齐实际发布资源、把scene.xml纳入双方输入指纹与安装前后核对；保存所有本轮私有日志，检查异常及CS明确的registered标记。完整资源复测97b5c24da8中CS正常初始化并生成合并场景，继而暴露独立的RConnect快照16MB限制。该轮仍失败，不能把资源修正等同游戏功能或性能通过。

## 可复用做法与边界

- 发布字节相同只固定了代码，不代表其必需数据资源、配置、初始化时序也相同。根据实际文件读取入口建立运行依赖清单，并逐份核对测试副本。
- 加载器调用init返回，只证明入口返回；延迟初始化需模块自己的完成证据。收集各模组日志，避免只查协调模组或stdout。
- 发现夹具缺件时保留旧成功/失败，补充失效范围；修正后重跑相关组合。不要把早先通过数量当完整环境合格。
- 本次只证实scene.xml遗漏和其初始化后果；未证明其他模组资源全部穷尽，也未证明房间耗时达标。
