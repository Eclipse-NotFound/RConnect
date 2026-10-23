# ACK 退休信号与坏载荷拒绝：合并组件输入

这里只准备独立组件输入，不构建、不启动 AIR、不部署、不修改任何原记录或活动候选。

合并的真实 `WallImpactVisuals` 明确来自三份指纹：C6A3 基底；ACK-only（只增加 Boolean 退休信号）；decode-only（只在 ordinaryDecode 的 decodeWords 调用处 catch Error 返回 null）。准备脚本先证明 decode-only 恰好是 C6A3 的这一处替换，再把同一处替换施加于 ACK-only。三份原件与合并结果均记在 manifest，分别提供三份可读差异。

两个组件源目录使用同一份合并 WIV：

- `components20/WallAckChecks.as`：取真实失败的 `recovery-ordinary-wall-ack-component-01/src`，20 项检查和其他 9 文件范围内的载体保持原字节，唯一替换为 WIV。第 7 项仍要求坏载荷拒绝，不允许把 #2058 当作通过。
- `components153/WallSurfaceChecks.as`：取真实通过 153/0 的 `recovery-ordinary-wall-sv-component-02/src`，全部其余文件逐字复制，仅替换 WIV。

`prepare.py` 拒绝覆盖，`--verify` 核全部来源、输出和两个目录“除了 WIV 逐字不变”。原失败与原通过结果仅证明来源身份，**不代表新合并类已通过 20/153**。根可用既有组件运行器分别指定以上 source 目录、入口及 expected=20/153，使用新 build 输出，不改旧回执。

这些组件不包含完整 Session/真实 socket，不验证 ACK 后即时发送、切房门限或网络失败重入；那些边界和性能收益仍待实际实例验证。
