# 准确20墙块解码候选独立审查

**未发现阻止隔离原生验证的确定问题。两处变化可分别比较；组件／冷解码计时不构成密集场景性能或发布资格。** 本审查未改交付、生产或结果，未启动编译／AIR。

已只读核对 `recovery-wall-decode-fast/handoff.json` 的28份文件指纹，并运行其纯只读 `prepare.verify()`：两份生产覆盖、四份完整类变换、原 codec 副本、pack 与 Base64 后半段逐字保持，全部符合准确 `build/m52/recovery-20`。交付handoff SHA `609956e7c78bf045be74245cf5bdd2369a55c40929d734c9b3c991468cebb937`；候选 WallCellCodec SHA `28e069808e93edcf479bd1fc977fe226036d5f030b65532a3ff15c564527b1f3`，WallImpactVisuals SHA `580a3998ac3a3cd56fca45ab6fe9bb64fc4104791b9c67cfbe47a5a6881e3c2f`。

## 接收语义

| 项目 | 核对结果 |
|---|---|
| 字符分类 | 128项REVERSE只给原64字符合法值，其余−1。quartet长度已验证，charCodeAt必读现存UTF-16单元；≥128直接拒绝，不会截断高字节后误命中ASCII。 |
| padding／规范低位 | 第一、二位不允许`=`；第三位padding要求第四位也是padding；padding只能在最后quartet；双padding时b低4位、单padding时c低2位仍必须为0。条件与原版相同。 |
| 两字节写入 | `(a<<10)|(b<<4)|(c>>2)` 的默认大端writeShort，恰等于旧两个writeByte的低8位依次输出；第三字节及双padding单字节路径不变。最大值65535的位模式也保持。 |
| 限额及异常 | PREFIX、MAX_TEXT=13340、MAX_COMPRESSED=10000、MAX_RAW=9602、1600像素、原生uncompress、展开长度、严格递增索引和精确字节长度检查保留。非法zlib的原生异常仍由外层decode捕获。原生inflate先展开后验MAX_RAW的既有边界未改变，不能称新增了有界inflate。 |
| 去重复校验 | W1解码器只返回`Number(readUnsignedShort())`索引及`Number(readUnsignedInt())`颜色；数量≤1600、索引严格递增且<1600已保证，uint均为可精确表示的有限整数。省去的循环条件均由此蕴含；返回值类型仍Number。legacy继续原Number强制转换和嵌套可变对象排除，未改变其宽松兼容规则。 |
| 缓存／副本 | W1旧numeric本就恒true，新版同样缓存；命中返回concat，写入保存concat，冷返回与内部缓存也分离。legacy含字符串／嵌套数组不会因新分支被缓存。FIFO数量／词数／字符限额与reset原样保持。 |
| 包原子性／ACK | 坐标、重复格键、64格/48000字符等外层检查未绕过。整包decode成功后才put；旧版本坏块仍能拒绝后面新块；匹配seq但坏ACK仍不清pending。失败包可能预热已验证缓存，predict路径也原本会先observe本机变化，故“原子性”准确指不提前写入收到的像素／放行ACK，不是所有内部状态绝对不变。 |

## 组件证明及边界

四份完整实际类确切组合为：Before=原wall+原codec；CodecOnly=原wall+新codec；VerifyOnly=去重wall+原codec；After=两项组合。没有把组合依赖误接到单项。组件GameBridge、Log和Bullet仍是原有限替身，真实BitmapData／ByteArray与实际完整墙面类参与；未加载游戏，不覆盖原生场景、Socket、外模组或绘制节奏。

原49项检查文本结构保留，新增17项语义检查和1项包规模检查。重点实际覆盖了四位置非法ASCII/非ASCII、0/1/2 padding、低位不规范、截断、非法inflate及限额、旧格式转换、冷/热返回数组独立、旧版本坏块整包拒绝、坏ACK预测保护。缓存淘汰与跨房来源主要仍靠未改源码保证，未新增一套缓存容量压力用例；这不阻断本次两处局部变化。

根会话随后完成的 `build/m52/recovery-wall-decode-fast-component-01` 已回读：**67条断言全部passed、0 failed**，编译/进程退出0，安装和来源未变。SWF `c57507991c9d0258735b9df62bc101ed98445c408856f51ca881b9cc7be7909a`；component-result SHA `fb123ee9ff6024fe3d8dc105bdeaf402b77ce56392fd51458bfadc8cf150604e`，receipt SHA `440e6b8dae02e08488007ef8394735662a833147de1660356e57ceb18f6c4890`。这是根执行的真实组件结果，不是本审查启动测试。

## ABBA解释

三组独立对照各两轮ABBA，实际24块；每块覆盖相同七组输入。以下均为完整decode累计ms，顺序A/B/B/A/A/B/B/A，不是单一Base64片段：

| 比较 | 8块结果 |
|---|---|
| 原版→仅字符／writeShort | 850 / 733 / 727 / 864 / 869 / 751 / 732 / 867 |
| 原版→仅W1验证去重 | 877 / 781 / 767 / 874 / 878 / 802 / 794 / 873 |
| 原版→组合 | 880 / 634 / 665 / 870 / 845 / 648 / 631 / 833 |

各配对8块的calls/cells/words/checksum已独立核为一致。计时包含实际包边界校验、Base64、inflate、解析和缓存写入；reset、遍历checksum、JSON及文件写入在时钟外。每批强制冷缓存，包内重复空载荷仍自然命中；未计入真实缓存命中比例。两个大包是确定性合成40k–48k字符，历史82载荷也不是本轮原生载荷采样。

可以分别评价两个单项及组合的**配对冷解码成本**；不可直接相加单项差额、跨三组不同时段共用一个基线，或用旧采样占比换算整机收益。未改legacy在24块中仍为291–327ms，说明时序／GC等噪声存在；ABBA仅减轻顺序偏差，不消除。checksum是工作量防错而非逐词等价证明，逐词／返回类型／像素等价来自前面的专用检查与源码核对。接收热缓存、持续GC、绘制长帧及实际七阶段门槛仍须在准确完整候选中原样实测，不能因67/0放宽。
