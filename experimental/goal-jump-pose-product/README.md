# jumppose1 隔离产品构建

准确正式 78C / recovery-room-production-05 为底，只覆盖已冻结 jump-pose-interpolation 的 GameBridge、RemoteMotion、NativeJumpPose，以及 RConnectMod 版本 `0.2.24-jumppose1`。81个原类中78个原样、3个变化（含版本），新增1类；不合入 motionv2、selfecho 或 UI 修正。

`prepare.py --prepare` 只生成本目录四份小源码、diff和清单，遇不同内容拒绝覆盖；`prepare.py --check` 只读核验。复用原候选的完整 manifest verifier，原候选目录不改。72项组件资格与原生/性能资格不由这个构建入口冒领。

`build.py --check` 另核当前22项安装与正式RC仍为78C，不创建构建输出、不启动Java或AIR。实际构建由根执行：`python -B -X utf8 experimental/goal-jump-pose-product/build.py build/m52/goal-jump-pose-product-01 --registry-wait 900`（工作目录为RConnect）。输出必须全新。

构建复用已冻结 recovery-room-production-v5/build.py，本地绑定 prepare 模块和 HERE，与已审 goal-self-echo-prune/build.py 模式一致。原共享登记、每条命令1 GiB启动余量、384 MiB Java、300秒上限、隐藏编译器、自有PID清理、完整源码/工具/实际22项前后指纹核验均不变；复制原完整src/tools仅在真实构建时进入新build目录。历史78C环境只证明来源，当前环境在构建开始重新读取并保持一致。

只读 `build.verify(absolute_output)` 要求真实 compiled、两命令成功、安装与源码不变以及实际SWF哈希；没有compile.json或只有prepare绝不通过。构建不会启动游戏、修改release或部署宿主。准备及源码核验通过不代表72项组件或真实画面已通过。
