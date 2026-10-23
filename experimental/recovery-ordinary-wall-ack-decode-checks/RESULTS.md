# 实际组件回归

2026-10-23，原检查内容及条数不变，使用相同合并 WIV `8e254a384f3b9c1da1911e36d67884558a19621e116e769decc4c3edd55c636a`。

- `build/m52/recovery-ordinary-wall-ack-component-02`：真实编译、AIR 退出0，20/0；SWF `7407c3c7b9536a7a235eee1f7335a5a898178fb8c1051a55f94e3a14c0338c49`。
- `build/m52/recovery-ordinary-wall-ack-regression-01`：原153项真实编译、AIR 退出0，153/0；SWF `40755f169badd52bac409d616675bc59c810f3c55c7c794ec387dc3eb828f5d7`。

两轮共享登记、小组件内存门槛、私有桌面/存储及原收尾不变，源码和安装核对通过。首次 ACK-only 的组件01 #2058失败保留；没有把异常改成可接受结果，修正是普通解码路径对坏载荷明确拒绝。

这证明墙面类的确认信号和原有状态/像素组件行为，不含完整 Session 的快发、真实 TCP、房间切换或性能。生产候选及安装尚未合入该合并类。
