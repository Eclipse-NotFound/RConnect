# 首次失败的实机证据

2026-10-23。诊断03编译成功，`EA5691CF97CBA75A256122F3D0357880D9A93F5733E75EE4BED9D186D7A0E9BE`；两次JVM退出0，冻结输入及22安装未变。02的显式日志import编译错误保留。

首次双人诊断 `recovery-ordinary-wall-room-diagnostic-01` / `bede6e0944` 在启动前因可提交余量4,707,008,512 bytes低于6 GiB退出，未启动AIR。用户释放资源后用完全相同诊断产物复跑。

第二次 `recovery-ordinary-wall-room-diagnostic-02` / `618e7154ac` 实际捕获：加入侧 `random_mane//0,0,0`、48×25、当前权威、tile(5,19)，旧front=A、mat=1。`structure-prepare` 的真实错误为 `Error: Unreviewed ordinary material mask class`，范围为空；后续 `structure-before` 的对象身份全部一致，但准备标记无效，因此 nativeFailure=true。checkpoint异常明确 raster=false、bridge=false。原生破墙完成而交接被拒的链路已经复现。

根在已有首错及后续checkpoint证据后写入原runner的取消标记；原框架exit130、自有实例及运行副本回收，取消与失败均保留，绝不记通过。详细事件、日志SHA及取消回执见新 diagnostic-result.json。没有改判断门槛，没有部署。

现有枚举只列大写六类；原生Material会从素材定义取得另一些具体蒙版类。已经核到A的边缘使用 `maskSimple`，不在旧名单；邻格也参与范围计算，当前记录不支持声称首个拒绝的一定是A边缘。下一步核实际原生全部蒙版与角帧范围后做明确的小范围支持，不允许任意类，也不删除失败检查。
