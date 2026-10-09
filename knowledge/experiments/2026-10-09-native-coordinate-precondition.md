---
domain: knowledge-validation
type: experiments
game-version:
  - "1.02"
confidence: medium
verified: false
discovered-by: RConnect
evidence:
  - kind: runtime-experiment
    summary: "正式27 db93f16896宿主本机/远端全局轴同时为零；三次同候选定向检查未复现，新增原生有效轴前提"
  - kind: runtime-experiment
    summary: "独立AIR窗口probe04，初始visible属性false但Win32实际窗口可见，显式设置只改变属性读值"
date-updated: 2026-10-09
---

# 武器姿态检查的原生坐标前提

## 已确认

正式27的WeaponAngleTestDoc / db93f16896在双方七角度均报告所有样本不一致。现成NATIVE CHANGE与MISMATCH日志显示：宿主本地原生枪和远端枪的归一化全局轴xx/xy/yx/yy均为0；加入侧两把枪均为正常单位轴，因收到宿主的零轴参考而失败。原夹具只检查对象已经在stage上，没有单独确认全局基底有效。该失败保留，不改为成功。

## 观察到

隔离weapon-coordinate-probe-01 / fcf294c5d9保持32602e77候选、原生LMG七角度和原0.08误差门槛，只记录每轮首帧的显示祖先矩阵、窗口与相机状态，65/0。03 / 74a6481f16去掉测试游戏CREATE_NO_WINDOW，04 / da2743cb16再显式SW_SHOWNORMAL，两次也是65/0。三次全局轴均正常，相机1280×800、scale=2/3。无法证明后两项启动改动解决了原故障，因此均未采用。02在准备脚本替换断言处失败，未启动AIR。

三次日志中的NativeWindow.visible仍为false，最初据此怀疑窗口被隐藏。独立window-runtime-probe-04（无游戏/存档，独立AppID）同时取AIR属性与Win32同PID窗口：前四秒属性false，但336×239游戏内容窗口实际visible=true；第五秒显式visible=true后属性变true，OS窗口状态、全局点(100,100)和320×200舞台尺寸不变。本机此运行时的该属性初值不能单独证明窗口隐藏。没有证据将此前坐标零值归因于隐藏、启动参数或其它程序。

独立窗口01缺AIR_HOME编译失败，02在AIR拒绝applicationDirectory写入后由控制器结束自有进程，03无stdout trace但正常退出，04改为独立applicationStorageDirectory成功取得两路记录。所有过程保留，只清理自有PID。未改其它模组、安装或玩家存档。

## 推测

原失败涉及宿主全局显示基底，而不只是远程枪的翻转；可能是瞬时窗口/显示状态或全局坐标计算异常，但缺少失败当时的祖先矩阵，原因尚不能确定。不能把三次通过写成该低频问题已修复。

## 尚未验证

正式28仅在原WeaponAngle驱动增加每轮显示链记录和独立原生单位轴有效性断言，保留全部原远程比较、开火断言及阈值。未来若原生坐标退化，须明确报原生前提失败，不能算远端几何通过。相同生产字节的五组27成功已按完整输入核对承接，其余33组及旧21对照继续，诊断不计发布证据。
