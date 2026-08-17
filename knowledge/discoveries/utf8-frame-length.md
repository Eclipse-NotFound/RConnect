---
domain: knowledge-validation
type: discoveries

game-version:
  - "1.02"

confidence: high
verified: true

discovered-by: RConnect

evidence:
  - kind: runtime-experiment
    summary: "真机双实例联测：传输含俄文房间名（worldInfo.roomId）的消息后，
      客户端解析到坏帧（bad frame length: 577794671——误把 JSON 文本当长度）；
      改为 ByteArray 计算 UTF-8 字节数后消失"

date-updated: 2026-08-15
---

# 发现：长度前缀协议必须用 UTF-8 字节数（俄文房间名引发的流错位）

## 现象

- 客户端反复 "bad frame length: 577794671"（≈0x226D5F6F，字节即 `"m_o`
  的 ASCII——解析器误把 JSON 文本当成长度前缀），连接循环重建。
- 触发条件：宿主进入马哈顿废墟后（worldInfo 携带**俄文房间名** roomId）。

## 根因

- 帧格式 = uint32 长度 + UTF-8 字节体；原实现用 `String.length`（UTF-16
  字符数）做长度，而写入用 `writeUTFBytes`（UTF-8 字节）。
- 纯 ASCII 时两者相等（一直正常）；消息含非 ASCII（俄文房间名每字符
  2 字节）时长度前缀小于实际字节数 → 读取端多留的字节被当下一条长度 →
  全流错位。

## 修复

- 发送端：`ByteArray.writeUTFBytes(body)` 后用 `ba.length`（真实字节数）
  做长度前缀，`writeBytes` 写出。
- 读取端不变（readUTFBytes(len) 本就读字节）。

## 适用性

- 任何"长度前缀 + 变长文本"的自定义协议（模组间通信、日志传输等）
  都应按 UTF-8 字节计数；测试用例要覆盖非 ASCII 文本（游戏内含大量
  俄文命名：房间名/单位显示名/物品名）。
