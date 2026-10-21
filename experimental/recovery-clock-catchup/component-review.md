# 实际 AS 回放与隔离整合

2026-10-22，`build/m52/recovery-clock-catchup-component-01` 实际 AIR **40/0**，SWF `8258a54bf18e2e768bba9b1a11f3dbba42700dd0b916cf20f6c1ce622189e855`。安装22项与输入不变。完整180条时序，旧真实类复现记录，新真实类首段可播46159→45956，有效帧后等待194ms。不是原游戏实际出图快203ms的证据。

两项准确增量（RemoteMotion及入口版本）整合到10，SWF `184eea3d6405ee57cb0bc3f6cfa78668f5ca9334888b0ca2af04095bc17c4608`。原生高速 `recovery-flight-native-09 / 9898f0da34` 八组完整，但case7闪电104ms整帧间隔和131ms动画保持未过；不得部署或称整体流畅。

本次实际使用整合配方保存在 `merge-recipe-used-10.py`，与10的integration_recipe_sha256绑定。独立审阅指出该旧配方部分写入时的回滚不完整：实际此次成功、85文件和冻结编译后核验一致，没有发生部分写入。未来工具已改为先写完整临时文件及回滚副本、核对后原子替换，并绑定实际组件intent入口/expected/source；没有重写冻结10或将工具修正当生产性能修正。

11只在10上追加单文件NativeTileState等价优化；上述时钟源码原字节不变。最终同候选原生玩法与性能仍须核验。安装保持574D。
