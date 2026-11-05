/*
 * 斯安维斯坦模组 (Sandevistan Mod) for Fallout Equestria: Remains
 * 逻辑核心 —— 由补丁后的 MainFE 在游戏启动时加载进游戏域并调用 SandevistanMod.init()
 *
 * 时停实现：World.onPause = true（游戏自身冻结 land.step / 实体 / 粒子），
 * 然后本模组每帧手动调用 loc.gg.step() 让玩家照常行动；
 * 同时手动步进链表中的 Part 粒子（特效继续，实体冻结）。
 * 残影：彩虹色调色板 + 加法混合，残影层挂在 world.visual 内（相机自动跟随）。
 * 回放：生效期间记录玩家路径，结束后以 N 倍速回放残影。
 */
package
{
   import modlocales.sandy.SandyLocale;
   import fe.serv.SandyHighFpsClock;
   import flash.desktop.NativeApplication;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.display.IBitmapDrawable;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.media.Sound;
   import flash.media.SoundChannel;
   import flash.media.SoundTransform;
   import flash.events.IOErrorEvent;
   import flash.net.URLRequest;
   import flash.system.ApplicationDomain;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.ui.Keyboard;
   import flash.utils.getTimer;
   import flash.utils.Dictionary;

   public class SandevistanMod extends Sprite
   {
      // ---------- 配置（默认值，被 SandevistanMod/config.txt 覆盖） ----------
      private var cfgHotkey:int = Keyboard.BACKSLASH;   // 默认 \
      private var cfgDuration:int = 210;                // 生效帧数（30fps -> 7 秒）
      private var cfgCooldown:int = 0;                  // 冷却帧数（默认 0 = 无冷却，便于调试）
      private var cfgReplaySpeed:Number = 5;            // 回放速度倍率（回放时世界冻结，无渲染压力）
      private var cfgGhostEvery:int = 5;                // 每 N 帧生成一个残影（时停期，默认 5）
      private var cfgFxRun:Boolean = true;              // 时停期间粒子特效是否继续

      // ---------- 运行时状态 ----------
      private static var inst:SandevistanMod = null;
      private var keybinds:SandyKeybinds;
      private var world:Object;                         // fe.World.World.w
      private var authority:SandyAuthority;
      private var authorityState:Object;
      private var highFpsChecked:Boolean = false;
      private var highFpsHost:Class = null;
      private var highFpsView:SandyHighFpsView = new SandyHighFpsView();
      private var hooked:Boolean = false;

      private var sandyActive:Boolean = false;
      private var sandyLeft:int = 0;                    // 剩余帧数
      private var cooldownLeft:int = 0;                 // 冷却剩余帧数
      private var savedOnPause:Boolean = false;
      private var ghostLayer:Sprite;                    // 残影容器（世界坐标，挂在 world.visual 内）
      private var ghosts:Array = [];                    // 存活残影
      private var rainbowIdx:int = 0;
      private var history:Array = [];                   // 记录玩家路径 {x,y,s,r,v}
      private var replaying:Boolean = false;
      private var replayIdx:int = 0;
      private var savedGod:Boolean = false;             // 回放期间无敌
      private var savedGgCtrl:Boolean = true;           // 回放前控制状态
      private var startWeapon:Object = null;               // 时停开始时的武器（回放开始切回它）
      private var endWeapon:Object = null;                 // 时停结束时的武器（回放结束切回它）
      private var replayWpn:Object = null;                 // 回放期间钉住的武器（防游戏切换动画乱切）
      private var sandyEndSnap:Object = null;              // 时停结束快照（全武器弹夹+背包弹药，回放结束恢复）
      private var fxTicks:int = 0;
      private var diagTick:int = 0;
      private var replayDiagTick:int = 0;      // 回放段诊断计数
      private var replayDiagOnce:Boolean = false;  // 回放开始诊断（每轮回放一次）
      private var replayAtkTick:int = 0;       // 回放段攻击链路诊断计数
      private var replayBodyTick:int = 0;      // 回放段攻击体状态诊断计数
      private var replayAnimTick:int = 0;      // 回放段动画像素哈希诊断计数
      private var replayFireTick:int = 0;      // 回放段开火诊断计数
      private var replayGhostDisp:int = 0;    // 回放残影显示帧计数
      private var sandyAtkTick:int = 0;        // 时停段攻击状态诊断计数
      private var sandyEnemyTick:int = 0;      // 时停段敌人移动诊断计数
      private var mouseAtkDown:Boolean = false;   // 鼠标攻击键按住状态
      private var mouseAtkPulse:Boolean = false;  // 鼠标攻击键按下脉冲（同帧 DOWN+UP 不丢）
      private var savedOtbros:Number = -1;        // 回放近战击退原始值（缩放到 1/5 抵消加速）
      private var savedRapids:Object = {};        // 回放中改过的武器 rapid 原始值（结束恢复）
      private var cfgSlowFactor:Number = 5;       // 时停慢速倍率（1/N 速，config slowfactor）
      private var slowTick:int = 0;               // 节流计数器（每 slowfactor 帧 step 1 次）
      private var slowPartClass:Class = null;     // 粒子类（节流 step 跳过，特效单独处理）
      private var replayObjs:Dictionary = new Dictionary();  // 重演对象 → 每帧状态数组 {x,y,f,s}
      private var replayObjArr:Array = [];        // 重演对象引用列表
      private var seenPos:Dictionary = new Dictionary();    // 场景对象移动检测快照
      private var sndClass:Class = null;          // fe.Snd（重演音效播放）
      // 预判死亡（时停中统计玩家攻击本应造成的伤害，≥血量则放死亡动画，不真杀）
      private var predDam:Dictionary = new Dictionary();   // 敌人 → 预判累计伤害
      private var origDam:Dictionary = new Dictionary();   // 攻击体 → 原始伤害（清零前捕获）
      private var hitCred:Dictionary = new Dictionary();   // 攻击体 → {parr, targets}：按挥击代次去重
      private var damagePredictor:SandyDamagePredictor = new SandyDamagePredictor();
      private var predDead:Dictionary = new Dictionary();  // 敌人 → true（时停中放死亡动画）
      private var replayBlit:SandyBlitReplay = new SandyBlitReplay();
      private var replayAnimCat:Dictionary = new Dictionary();  // 回放动画档位迟滞（防 walk/run 抖动）
      private var endSnapWpnHp:Number = -1;  // 时停结束时武器耐久（回放结束恢复——防双倍损耗）
      private var endSnapMana:Number = -1;   // 时停结束时魔法值（回放结束恢复——防双倍消耗）
      private var thrownDamWall:Dictionary = new Dictionary();  // 时停中被投掷单位 → 原始 damWall（回放结束恢复——撞墙伤害延后结算）
      private var recPrevHold:Number = -1;  // 开火记录：上一帧同武器弹夹（帧间下降=子弹真实生成）
      private var recPrevTA:int = -1;       // 开火记录：上一帧 t_attack（上升沿=攻击初始化）
      private var recPrevWid:String = "";   // 开火记录：上一帧武器 id（换武器重置基线）
      private var recDiagCnt:int = 0;        // 录像对象诊断计数（每轮时停重置）
      private var recDoorCnt:int = 0;        // 门对象诊断计数（每轮时停重置）
      private var rFixCnt:int = 0;           // 回放重钉诊断计数（每轮回放重置）
      private var doorPrevDop:Dictionary = new Dictionary();  // 门重演：上一帧 dop（防重复 setVisState 音效）
      private var lastGhostX:Number = 0;   // 上一残影位置（叠加防护：最小位移门槛）
      private var lastGhostY:Number = 0;
      private var lastGgControl:Boolean = true;
      private var savedInter:Object = null;
      private var keyPressTime:Array = [];      // 按键按下时间戳（防 UP 丢失卡键）
      private var keyMap:Object = {};            // 键码 -> 键布尔名（解析自游戏 keyXML）
      private var keyMapBuilt:Boolean = false;
      private var keyDownSeen:Array = new Array(256); // 最近按键按下记录（时间戳）
      private var ime229Count:int = 0;                // 短时间内 229 事件计数（仅诊断日志）
      private var ime229Time:int = 0;
      private var imeMissCount:int = 0;               // UP无DOWN 计数（2秒窗口，仅诊断日志）
      private var imeMissTime:int = 0;

      // 解析游戏默认键位表（keyXML 是 public），建立键码->布尔名映射
      private function buildKeyMap():void
      {
         try
         {
            var kx:* = world.ctr.keyXML;
            if (kx == null) return;
            keyMap = {};
            var keys:XMLList = kx.key;
            for each (var k:XML in keys)
            {
               var id:String = String(k.@id);
               var defs:Array = [String(k.@def), String(k.@alt)];
               for each (var dv:String in defs)
               {
                  var code:int = parseInt(dv, 10);
                  if (dv != "" && !isNaN(code) && code > 0 && code < 256)
                  {
                     keyMap[code] = id;
                  }
               }
            }
            keyMapBuilt = true;
            log("[SandyMod] keyMap built: " + keyMap[65] + "/" + keyMap[68] + "/" + keyMap[32] + "/" + keyMap[220]);
         }
         catch (e:*) { log("[SandyMod] buildKeyMap error: " + e); }
      }
      private var prevVisX:Number = 0;
      private var prevVisY:Number = 0;

      private var hud:TextField;                        // 顶部状态文字
      private var hudBg:Sprite;
      private var debugTest:Boolean = false;             // 自动测试模式（config debugtest=1）
      private var cfgHud:Boolean = true;                 // v1.125：顶部状态 UI（启动中/回放中/充能中）显示开关
      private var cfgGhostBlend:int = 1;                  // 残影混合: 1=normal柔和 0=add发光
      private var cfgGhostAlpha:int = 70;                 // 残影不透明度（百分比，默认 70）
      private var cfgReplayGhost:int = 1;                 // 回放残影生成间隔（每 N 个显示帧 1 个）
      private var cfgReplayGhostLife:int = 4;             // 回放残影寿命（显示帧，短寿命=拖尾）
      private var cfgColorMode:int = 0;                   // 残影配色: 0=彩虹 1=边缘行者绿蓝紫
      private var cfgEdgeThresh:Number = 15;             // 边缘行者渐变门槛（速度≥此值全绿）
      private var playerAnimCat:int = 0;                  // 回放玩家动画档位迟滞（1=待机 2=走 3=跑）
      private var thrownImpacts:Dictionary = new Dictionary();  // 被投掷单位 → {frame, dam} 首次撞击（回放该帧结算伤害）
      private var thrownPreV:Dictionary = new Dictionary();     // 被投掷单位 → {dx, dy} 节流步前速度（撞击检测）
      private var thrownUnits:Dictionary = new Dictionary();    // 时停中被投掷过的单位（回放全程只重钉不 step）
      private var enemyAtks:Dictionary = new Dictionary();      // 敌对单位 → [{frame, w, cx, cy}] 时停记录的开火事件（回放复现）
      private var preExistB:Dictionary = new Dictionary();       // 时停开始时已在飞的玩家攻击体（不清除，回放继续飞行）
      private var gSnapKol:Number = -1;   // 时停结束时手雷库存（回放结束恢复——重演抛掷不二次消耗）
      // v1.127：以下四个字段原为"投掷物可击落（手雷击落）"技能配置——
      // 该技能已迁移到 mods/MoreSkills&Weapons（MSWProjHits.as），Sandevistan
      // 侧停用（默认 false、config 键失效、面板行移除）。声明与实现保留
      // 作为备份（完整源码另存 state/migration-backup-v1.126/）。stepProjHits
      // 的回放重演分支抽成 replayProjBoom() 脱离本开关（斯安维斯坦回放系统
      // 对时停中自然爆炸的重演不受影响）。
      private var cfgProjHits:Boolean = false;   // 已迁移 MSW：投掷物可被击落（手雷/导弹/榴弹受击至 0 爆炸）
      private var cfgProjHp:Number = 30;        // 投掷物血量（已迁移 MSW，备份）
      private var cfgProjArmor:Number = 0;      // 投掷物护甲（已迁移 MSW，备份）
      private var projHp:Dictionary = new Dictionary();  // 投掷物 → 当前血量（已迁移 MSW，备份）
      private var projHpOver:Object = null;     // v1.114：按武器 id 的血量覆盖（已迁移 MSW，备份）
      private var projArmorOver:Object = null;  // v1.114：按武器 id 的护甲覆盖（已迁移 MSW，备份）
      // ===== v1.115：敌人斯安维斯坦（Enemy Sandevistan）=====
      // 触发=敌人 AI 锁定玩家（celUnit==gg）且待机（不在冷却）即开启；
      // v1.126 起无上升沿要求（见 stepEnemySandy：玩家保持在视野内时冷却
      // 结束可重复触发；玩家时停中进入视野同样能触发——stepEnemySandyB）。
      // 每房间装备名额 v1.119 起为房间敌人数的 cfgESPer%（默认 50，即一半；
      // esRoomCnt 按 room.id 计数）；持续/冷却/倍率可配置。
      private var cfgEnemySandy:String = "UnitRaider,UnitMerc,UnitAlicorn,UnitEncl,UnitRanger,UnitZebra";
      private var cfgESDur:int = 150;            // 持续帧（30帧=1秒 → 5秒）
      private var cfgESCd:int = 300;             // 冷却帧（10秒）
      private var cfgESSpd:int = 5;              // 加速倍率（每显示帧补 spd-1 次 step）
      private var cfgESGhost:Boolean = true;     // 敌人残影（边缘行者配色）
      private var cfgESGhostLife:int = 12;       // v1.122：敌人残影寿命（显示帧，线性淡出）
      private var cfgESMark:Boolean = true;      // 调试"S"徽标
      private var cfgESPer:int = 50;             // v1.119：每房间装备百分比（50=一半；0=关闭；100=全部）
      private var cfgESEnabled:Boolean = false;  // v1.136：默认关（用户要求——不生成斯安维斯坦敌人）；config/F9/设置页可开
      private var cfgESRoomProb:int = 100;       // v1.131：房间出现斯安维斯坦敌人的概率%（100=每个候选房间都有）
      // ===== v1.139：时停主题曲 =====
      private var cfgMusicOn:Boolean = true;     // 主题曲开关（默认开，用户选定）
      private var cfgMusicVol:int = 70;          // 音量 0-100%（独立于游戏音效，默认 70）
      private var cfgMusicFade:int = 90;         // 回放结束后淡出帧数（默认 90 = 3 秒）
      private var esClasses:Array = [];          // 白名单类名（config enemysandy 解析）
      private var esEnemies:Dictionary = new Dictionary(); // 敌人 → {st,left,cd,px,py}
      private var esRoomCnt:Object = {};         // v1.119：roomId → 已装备敌人数（名额=房间候选数×esandyper%）
      private var esMarks:Dictionary = new Dictionary(); // 敌人 → 徽标 TextField
      private var esMarkLayer:Sprite = null;     // v1.119：徽标容器（挂 grafon.visual 顶层，免疫图层重建）
      private var esMarkDiag:int = 0;            // v1.119：徽标诊断计数
      private var esCreateDiag:int = 0;          // v1.124：徽标创建诊断计数（按敌人逐个记）
      private var esQuotaDiag:int = 0;           // v1.119：名额诊断计数
      private var esLastLoc:Object = null;       // v1.124：上次房间（loc 变化时清空敌方状态）
      private var esRoomAllow:Boolean = true;    // v1.131：本房间是否允许生成斯安维斯坦敌人（换房间掷一次）
      private var esOffVisDiag:int = 0;          // v1.128：敌人斯安维斯坦结束后隐身诊断计数
      private var esOrphanDiag:int = 0;          // v1.128：敌人残影 vis 摘挂孤儿诊断计数
      private var esInvDiag:int = 0;             // v1.129：敌人在隐形瞬间的记录计数
      private var recSitFrames:int = 0;          // v1.123：时停中 isSit 帧计数（翻滚诊断）
      private var recRollFrames:int = 0;         // v1.123：时停中 animState=="roll" 帧计数
      private var recTotFrames:int = 0;          // v1.123：时停录像总帧数
      private var rRollDiag:int = 0;             // v1.123：回放翻滚喂入诊断计数
      private var esDiagCnt:int = 0;
      private var projDiagTick:int = 0;      // v1.117：常规玩法击落诊断计数
      private var projHitDiagCnt:int = 0;    // v1.117：常规玩法命中诊断计数
      private var seenAtk:Dictionary = new Dictionary(); // 攻击体追踪器（v1.85：按引用录像，绕开链扫描之谜）
      private var projBoom:Dictionary = new Dictionary(); // v1.91：时停中引爆的投掷物 → {f,x,y}（回放对应帧真实爆炸）
      private var reExecPin:Dictionary = new Dictionary(); // v1.94：重执行爆弹体 → 录像孪生体（回放钉到录像轨迹）
      private var boomDiagCnt:int = 0;                     // v1.94：boom 触发诊断计数
      private var twinSavExpl:Dictionary = new Dictionary(); // v1.98：回放重执行爆炸体的原始 damageExpl（endReplay 对存活体恢复）
      private var twinDiagCnt:int = 0;                     // v1.98：孪生体惰性化诊断计数
      private var partDiagOnce:Boolean = false;            // v1.98：时停粒子视觉类型诊断（每轮一次）
      private var recPaired:Dictionary = new Dictionary(); // v1.99：已配对录像体去重（防同一录像体被多个孪生体配对）
      private var cfgSwapRun:Boolean = false;          // v1.127：已迁移 mods/MoreSkills&Weapons（MSWSwaprun.as），Sandevistan 停用（默认关、config 键失效、面板行移除；实现保留作备份，完整源码见 state/migration-backup-v1.126/）
      private var leashLeft:int = 0;                   // v1.100：回放结束后弹药防泄漏钳制剩余帧数
      private var leashSnap:Object = null;             // v1.100：防泄漏钳制用的时停结束快照
      private var leashDiagCnt:int = 0;                // v1.100：防泄漏钳制诊断计数
      private var swapRunDiagCnt:int = 0;              // v1.101：疾跑切枪拦截诊断计数
      private var partErrCnt:int = 0;                  // v1.105：回放粒子 step 异常计数
      private var replayPartTick:int = 0;              // v1.105：回放粒子存活诊断计数
      private var reattDiagCnt:int = 0;                // v1.105：重挂诊断计数

      // ===== v1.107：爆炸位置视觉清点——定位"回放开始到爆炸结束时段"的鬼影 =====
      // 扫描显示树（grafon.visObjs 各图层）中爆炸记录位置附近的视觉
      // （类名/坐标/可见性）——直接点名鬼影本体（粒子/对象/重挂 vis/瓦片
      // 贴花都不放过）。
      private function ghostScan(tag:String):void
      {
         try
         {
            var gVis:Object = world["grafon"];
            if (gVis == null || gVis.visObjs == null) return;
            var nB:int = 0;
            for (var kBx:Object in projBoom)
            {
               if (nB >= 2) break;
               var bmx:Object = projBoom[kBx];
               if (bmx == null) continue;
               nB++;
               for (var sl:int = 0; sl < 8; sl++)
               {
                  var lay:Object = gVis.visObjs[sl];
                  if (lay == null) continue;
                  try
                  {
                     var nc:int = lay.numChildren;
                     var found:int = 0;
                     for (var ci:int = 0; ci < nc && found < 4; ci++)
                     {
                        var ch:* = lay.getChildAt(ci);
                        if (ch == null) continue;
                        var ddxG:Number = ch.x - bmx.x;
                        var ddyG:Number = ch.y - bmx.y;
                        if (ddxG * ddxG + ddyG * ddyG <= 300 * 300)
                        {
                           found++;
                           log("[DIAG] ghostScan" + tag + ": sloy=" + sl + " cls=" + flash.utils.getQualifiedClassName(ch)
                               + " x=" + ch.x + " y=" + ch.y + " vis=" + (ch.visible != false ? 1 : 0)
                               + " alpha=" + (ch.alpha != null ? ch.alpha : -1));
                        }
                     }
                  }
                  catch (e:*) { }
               }
            }
         }
         catch (e:*) { }
      }
      private var reattached:Dictionary = new Dictionary(); // 回放中重挂过 vis 的对象（结束摘除，防残留画面）
      private function addEnemyAtk(u:Object, ev:Object):void
      {
         var arr:Array = enemyAtks[u];
         if (arr == null) { arr = []; enemyAtks[u] = arr; }
         arr.push(ev);
      }
      private var testStage:int = 0;                     // v1.136 状态机：0=开机 1=进游戏 2=传送 3=到达 4=拉怪 5=热身 6=时停 7=回放 8=pip/菜单设置 9=独立面板移除 10=总结
      private var testTicks:int = 0;
      private var testSub:int = 0;                       // v1.136：子步骤（pip/面板细分阶段）
      private var testPass:int = 0;                      // v1.136：断言通过计数
      private var testFail:int = 0;                      // v1.136：断言失败计数
      private var testFailNames:String = "";             // v1.136：失败断言名单（SUMMARY 用）
      private var testSkipCnt:int = 0;                   // v1.136：SKIP 断言数（不参与 pass/fail）
      private var testTravelTries:int = 0;               // v1.136：gotoLand 重试计数
      private var testPreTravelLoc:Object = null;        // v1.136：传送前 loc 引用（到达判定）
      private var testEnemy:Object = null;               // v1.136：拉怪目标
      private var testAtkT:int = 0;                      // v1.136：合成攻击脉冲相位
      private var testAnimSamples:String = "";           // v1.136：回放期玩家动画帧采样
      private var testDeadAtkSnap:Dictionary = new Dictionary(); // v1.144：已存在弹体，按对象身份登记
      private var testDeadOwners:Dictionary = new Dictionary(); // 上一次采样已死亡的非 postDie 单位
      private var testDeadSnapN:int = 0;                 // v1.144：有死亡样本时才给出死亡开火检查结论
      private var testPipCloses:int = 0;                 // v1.137：pip 守卫关闭计数
      private var testDeadAtkNew:int = 0;                // v1.144：已死亡敌人新生成的攻击体计数
      private var testReplaySeen:Boolean = false;        // v1.136：本轮回放确实发生过
      private var testSandySeen:Boolean = false;         // v1.136：时停确实激活过（自然结束≠未启动）
      private var testGgDowned:Boolean = false;          // v1.136：时停期间玩家曾倒地（sost>=2，动画断言作废）
      private var testFlagsBase:Dictionary = new Dictionary();  // v1.136：时停瞬间单位可见性/抓取基线（unit → esVisState 串）
      private var testGgX:Number = 0;                    // v1.136：pip 暂停检测基线
      private var testGgY:Number = 0;
      private var testErrDiag:int = 0;                   // v1.136：verror 解冻诊断计数
      private var testDone:Boolean = false;              // v1.136：SUMMARY 已输出
      // ===== v1.140：独立 ModSettings 中枢注册 =====
      private var hubRegistered:Boolean = false;         // 已注册成功（幂等，不再重试）
      private var hubViaCarrier:Boolean = false;         // v1.138：经 ModSettingsCarrier 会合点注册
      private var hubRegTries:int = 0;                   // 注册重试帧计数（≤300，契约见 ModSettings/README.md）

      // 彩虹色调色板（边缘行者风格，高饱和）—— alpha 由 config ghostalpha 控制
      private function palette(idx:int):ColorTransform
      {
         var a:Number = Math.max(0.05, Math.min(1, cfgGhostAlpha / 100));
         var cols:Array = [
            [1.6, 0.4, 0.4, 40, 0, 0], [1.7, 0.8, 0.3, 50, 10, 0], [1.7, 1.4, 0.4, 40, 30, 0],
            [0.5, 1.7, 0.5, 0, 50, 10], [0.4, 1.4, 1.6, 0, 40, 50], [0.4, 0.5, 1.8, 0, 10, 60],
            [1.5, 0.4, 1.7, 40, 0, 50], [1.6, 0.3, 1.0, 50, 0, 40]
         ];
         var c:Array = cols[idx % cols.length];
         return new ColorTransform(c[0], c[1], c[2], a, c[3], c[4], c[5], 0);
      }

      // 边缘行者绿-蓝-紫渐变（索引 0=绿 ... 7=紫红）
      private function edgePalette(idx:int):ColorTransform
      {
         var a:Number = Math.max(0.05, Math.min(1, cfgGhostAlpha / 100));
         var cols:Array = [
            [1.2, 2.3, 1.1, 0, 110, 20],  // 绿（加亮——快速跑动时明显绿色）
            [0.9, 1.9, 1.5, 0, 70, 90],   // 青绿
            [0.7, 1.6, 1.9, 0, 45, 120],  // 青
            [0.6, 1.2, 2.0, 0, 0, 150],   // 蓝青
            [0.7, 0.9, 2.0, 0, 0, 175],   // 蓝
            [0.9, 0.6, 2.0, 20, 0, 195],  // 蓝紫
            [1.2, 0.4, 1.9, 50, 0, 195],  // 紫
            [1.4, 0.3, 1.5, 70, 0, 175]   // 紫红
         ];
         var c:Array = cols[Math.max(0, Math.min(7, idx))];
         return new ColorTransform(c[0], c[1], c[2], a, c[3], c[4], c[5], 0);
      }

      // 速度→渐变索引：非线性——速度 ≥10 全绿；10→0 才渐变（幂曲线加速向蓝紫）
      private function speedToEdgeIdx(spd:Number):int
      {
         var t:Number = spd / (cfgEdgeThresh > 0 ? cfgEdgeThresh : 10);
         if (t >= 1) { return 0; }
         var idx:int = Math.round(7 * Math.pow(1 - t, 1.4));
         if (idx < 0) { idx = 0; }
         if (idx > 7) { idx = 7; }
         return idx;
      }

      // 残影配色分发：colormode=1 边缘行者（速度映射绿蓝紫）；否则彩虹循环
      private function ghostColor(spd:Number):ColorTransform
      {
         if (cfgColorMode == 1)
         {
            return edgePalette(speedToEdgeIdx(spd));
         }
         var ct:ColorTransform = palette(rainbowIdx);
         rainbowIdx++;
         return ct;
      }

      public function SandevistanMod()
      {
         super();
         trace("[MOD] ctor stage=" + (stage != null));
      }

      // ==================== 入口（由补丁后的 MainFE 调用） ====================
      public static function init(main:Object):void
      {
         if (inst != null)
         {
            return;
         }
         inst = new SandevistanMod();
         inst.log("[SandyMod] init called");
         inst.loadConfig();
         inst.keybinds = new SandyKeybinds(main, inst.cfgHotkey, function(code:int):void {
            inst.cfgHotkey = code; inst.saveCfgQuiet();
            if (inst.authority != null) inst.authority.release();
         });
         inst.cfgHotkey = int(inst.keybinds.binding.code);
         inst.authority = new SandyAuthority(inst.authoritySettings, inst.presentAuthority,
            function():Boolean { return !inst.sandyActive && !inst.replaying; });
         main.addChild(inst.authority);
         // v1.136：自动测试双重门控——config debugtest=1 且 app id ≠ "pfe" 才激活。
         // 用户实例即使 config 残留 debugtest=1 也不会被自动开档驱动；测试实例
         // （独立 app id）的存档/日志随 app id 天然隔离。
         try
         {
            var aid:String = NativeApplication.nativeApplication.applicationID;
            inst.log("[SandyMod] app id=" + aid);
            if (inst.debugTest && aid == "pfe")
            {
               inst.debugTest = false;
               inst.log("[SandyMod] debugtest ignored on user app id (pfe)");
            }
         }
         catch (e0:*) { }
         // v1.110：初始化粒子类引用——recordReplayObjects 的"粒子跳过"分支
         // 依赖它，但此前从未赋值（oR is null 恒 false）→ 时停中粒子被误
         // 录像 → 回放 v1.87 reatt 把已死粒子的 vis 重新挂回显示树、钉在
         // 死亡位置 = 鬼影真因。
         try { inst.slowPartClass = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class; } catch (e:*) { }
         // v1.101：版本标记——日志确认实际加载运行的构建版本与关键开关
         // v1.121：追加 esmark/esper/espd——排查"徽标不可见"类问题的第一手数据
         // v1.127：swaprun/projhits 已迁移 mods/MoreSkills&Weapons（此处不再输出）
         inst.log("[SandyMod] v1.145 loaded"
             + " esmark=" + (inst.cfgESMark ? 1 : 0) + " esghost=" + (inst.cfgESGhost ? 1 : 0) + " esper=" + inst.cfgESPer
             + " esen=" + (inst.cfgESEnabled ? 1 : 0) + " esprob=" + inst.cfgESRoomProb);
         if (main != null && main.stage != null)
         {
            main.stage.addEventListener(Event.ENTER_FRAME, inst.onFrame);
            main.stage.addEventListener(KeyboardEvent.KEY_DOWN, inst.onKey);
            main.stage.addEventListener(KeyboardEvent.KEY_UP, inst.onKeyUp);
            main.stage.addEventListener(Event.DEACTIVATE, inst.onDeactivateClear);
            // 鼠标左键按住状态（时停中近战拦截后，历史记录真实攻击意图用）
            main.stage.addEventListener(MouseEvent.MOUSE_DOWN, inst.onMouseDown);
            main.stage.addEventListener(MouseEvent.MOUSE_UP, inst.onMouseUp);

         }
         inst.log("[SandyMod] hooks registered");
         inst.loadThemeSound();
      }

      // ==================== 文件日志（模组内 trace 不输出，写文件） ====================
      private var cfgDiagLog:Boolean = false;           // 独立诊断日志开关（config diaglog=1）
      private function log(msg:String):void
      {
         if (!debugTest && !cfgDiagLog) return;   // 正式版不写日志（diaglog=1 时例外）
         var err:String = "";
         try
         {
            var f:File = File.applicationStorageDirectory.resolvePath("sandy_modlog.txt");
            var stream:FileStream = new FileStream();
            stream.open(f, FileMode.APPEND);
            stream.writeUTFBytes(msg + String.fromCharCode(13, 10));
            stream.close();
         }
         catch (e:*) { err = String(e); }
         try
         {
            var f2:File = File.applicationDirectory.resolvePath("mods/Sandevistan/release/modlog.txt");
            var s2:FileStream = new FileStream();
            s2.open(f2, FileMode.APPEND);
            s2.writeUTFBytes(msg + String.fromCharCode(13, 10) + (err != "" ? " [appDirErr: " + err + "]" : "") + String.fromCharCode(13, 10));
            s2.close();
         }
         catch (e2:*) { }
      }

      // ==================== 配置 ====================
      private function loadConfig():void
      {
         try
         {
            var cfg:File = File.applicationDirectory.resolvePath("mods/Sandevistan/release/config.txt");
            var txt:String = readTextIf(cfg);
            if (txt != null) { parseConfigLines(txt); }
         }
         catch (e:*) { trace("[SandyMod] config error: " + e); }
         // v1.137：应用存储持久层覆盖——F9 面板/MSW 设置中枢保存时，应用目录
         // 在 AIR 只读沙箱下写不进去，落点是这里（SandevistanMod_config.txt）；
         // 后读的键覆盖先读的，故用户经菜单调过的值优先于模板 config.txt
         try
         {
            var stF:File = File.applicationStorageDirectory.resolvePath("SandevistanMod_config.txt");
            var txt2:String = readTextIf(stF);
            if (txt2 != null) { parseConfigLines(txt2); }
         }
         catch (e2:*) { }
         if (cfgDuration < 30) cfgDuration = 30;
         if (cfgDuration > 3600) cfgDuration = 3600;
         if (cfgCooldown < 0) cfgCooldown = 0;
         if (cfgReplaySpeed < 1) cfgReplaySpeed = 1;
         if (cfgSlowFactor < 1) cfgSlowFactor = 1;
         if (cfgSlowFactor > 20) cfgSlowFactor = 20;
         if (cfgGhostEvery < 1) cfgGhostEvery = 1;
         if (cfgGhostAlpha < 5) cfgGhostAlpha = 5;
         if (cfgGhostAlpha > 100) cfgGhostAlpha = 100;
         if (cfgReplayGhost < 1) cfgReplayGhost = 1;
         if (cfgReplayGhostLife < 1) cfgReplayGhostLife = 1;
         // v1.127：cfgProjHp/cfgProjArmor 钳制随 projhits 迁移一并移除（已迁移 MSW）
         // v1.115：敌人斯安维斯坦白名单与数值钳制
         if (cfgESDur < 30) cfgESDur = 30;
         if (cfgESDur > 3600) cfgESDur = 3600;
         if (cfgESCd < 0) cfgESCd = 0;
         if (cfgESCd > 7200) cfgESCd = 7200;
         if (cfgESSpd < 2) cfgESSpd = 2;
         if (cfgESSpd > 10) cfgESSpd = 10;
         if (isNaN(cfgESPer)) cfgESPer = 50;      // v1.119：每房间装备百分比
         if (cfgESPer < 0) cfgESPer = 0;
         if (cfgESPer > 100) cfgESPer = 100;
         if (isNaN(cfgESRoomProb)) cfgESRoomProb = 100;   // v1.131：房间出现概率
         if (cfgESRoomProb < 0) cfgESRoomProb = 0;
         if (cfgESRoomProb > 100) cfgESRoomProb = 100;
         if (isNaN(cfgESGhostLife)) cfgESGhostLife = 12;   // v1.122：敌人残影寿命
         if (cfgESGhostLife < 1) cfgESGhostLife = 1;
         if (cfgESGhostLife > 120) cfgESGhostLife = 120;
         // v1.139：主题曲
         if (isNaN(cfgMusicVol)) cfgMusicVol = 70;
         if (cfgMusicVol < 0) cfgMusicVol = 0;
         if (cfgMusicVol > 100) cfgMusicVol = 100;
         if (isNaN(cfgMusicFade)) cfgMusicFade = 90;
         if (cfgMusicFade < 30) cfgMusicFade = 30;
         if (cfgMusicFade > 600) cfgMusicFade = 600;
         esClasses = [];
         var arrES:Array = cfgEnemySandy.split(",");
         for (var iES:int = 0; iES < arrES.length; iES++)
         {
            var cnES:String = String(arrES[iES]).replace(/^\s+|\s+$/g, "");
            if (cnES.length > 0)
            {
               // v1.117：getQualifiedClassName 返回 "fe.unit::UnitRaider" 全名——
               // 裸类名与全名比较永远不匹配（v1.115 无人注册/S 徽标不出现的
               // 根因）。统一存全名（已带前缀的照存）。
               if (cnES.indexOf("fe.unit::") == 0) { esClasses.push(cnES); }
               else { esClasses.push("fe.unit::" + cnES); }
            }
         }
         trace("[SandyMod] config hotkey=" + cfgHotkey + " dur=" + cfgDuration + " cd=" + cfgCooldown);
      }

      // v1.137：读文本文件，不存在/失败返回 null（lessons：try/catch 内不 return）
      private function readTextIf(f:File):String
      {
         var r:String = null;
         try
         {
            if (f.exists)
            {
               var stream:FileStream = new FileStream();
               stream.open(f, FileMode.READ);
               r = stream.readUTFBytes(stream.bytesAvailable);
               stream.close();
            }
         }
         catch (e:*) { r = null; }
         return r;
      }

      // v1.137：config 文本解析（loadConfig 双层调用：应用目录模板 → 应用存储覆盖）
      private function parseConfigLines(txt:String):void
      {
         var lines:Array = txt.split(/\r?\n/);
         // v1.127：projhp_<id>/projarmor_<id> 与 projhits/swaprun 键已移除——
         // 两技能迁移到 mods/MoreSkills&Weapons（MSWProjHits/MSWSwaprun，
         // SharedObject 持久化），Sandevistan 侧不再解析，已有 config 无法开启
         for each (var line:String in lines)
         {
            line = line.replace(/^\s+|\s+$/g, "");
            if (line.length == 0 || line.charAt(0) == "#") continue;
            var kv:Array = line.split("=");
            if (kv.length < 2) continue;
            var k:String = kv[0].replace(/^\s+|\s+$/g, "").toLowerCase();
            var v:String = kv[1].replace(/^\s+|\s+$/g, "");
            // v1.121：剥离行尾注释——此前 `esandymark=1  # 注释` 的布尔
            // 精确匹配（v=="1"）失败 → cfgESMark 恒 false=S 徽标三轮
            // "修复"全部无效的真根因（esandyghost 同样中招=敌人残影
            // 一直未开启）；parseInt 键靠数字前缀侥幸存活
            var hs:int = v.indexOf("#");
            if (hs >= 0) { v = v.substring(0, hs); }
            v = v.replace(/^\s+|\s+$/g, "");
            if (k == "hotkey") cfgHotkey = parseInt(v);
            else if (k == "duration") cfgDuration = parseInt(v);
            else if (k == "cooldown") cfgCooldown = parseInt(v);
            else if (k == "replayspeed") cfgReplaySpeed = parseFloat(v);
            else if (k == "ghostevery") cfgGhostEvery = parseInt(v);
            else if (k == "fxrun") cfgFxRun = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "debugtest") debugTest = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "showhud") cfgHud = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "diaglog") cfgDiagLog = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "ghostblend") cfgGhostBlend = parseInt(v);
            else if (k == "ghostalpha") cfgGhostAlpha = parseInt(v);
            else if (k == "replayghost") cfgReplayGhost = parseInt(v);
            else if (k == "replayghostlife") cfgReplayGhostLife = parseInt(v);
            else if (k == "slowfactor") cfgSlowFactor = parseFloat(v);
            else if (k == "colormode") cfgColorMode = parseInt(v);
            else if (k == "edgethresh") cfgEdgeThresh = parseFloat(v);
            else if (k == "enemysandy") cfgEnemySandy = v;
            else if (k == "esandydur") cfgESDur = parseInt(v);
            else if (k == "esandycd") cfgESCd = parseInt(v);
            else if (k == "esandyspd") cfgESSpd = parseInt(v);
            else if (k == "esandyghost") cfgESGhost = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "esandyghostlife") cfgESGhostLife = parseInt(v);
            else if (k == "esandymark") cfgESMark = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "esandyper") cfgESPer = parseInt(v);
            else if (k == "esandyenabled") cfgESEnabled = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "esandyroomprob") cfgESRoomProb = parseInt(v);
            else if (k == "musicon") cfgMusicOn = v.toLowerCase() == "1" || v.toLowerCase() == "true";
            else if (k == "musicvol") cfgMusicVol = parseInt(v);
            else if (k == "musicfade") cfgMusicFade = parseInt(v);
         }
      }

      // ==================== 帧循环 ====================
      private function onFrame(e:Event):void
      {
         if (keybinds != null) keybinds.step();
         try
         {
            onFrameInner();
         }
         catch (err:*) { log("[SandyMod] onFrame error: " + err); }
      }

      private function onFrameInner():void
      {
         if (world == null)
         {
            try
            {
               var wc:Class = ApplicationDomain.currentDomain.getDefinition("fe.World") as Class;
               if (wc != null) world = wc["w"];
            }
            catch (err:*) { }
            if (world == null) return;
            log("[SandyMod] World found");
         }

         if (authority != null && authority.attached)
         {
            if (!hubRegistered && hubRegTries < 36000 && ++hubRegTries % 10 == 1) stepHubRegister();
            updateHud();
            if (authorityState == null || !authorityState.paused) tickMusic();
            return;
         }

         // The high-FPS host schedules one 30 Hz logic step and optional render-only
         // frames. Read its already-computed result; calling Gov60.frame() here
         // would advance the scheduler twice. Ordinary hosts keep the original path.
         if (!highFpsChecked)
         {
            highFpsChecked = true;
            try { highFpsHost = ApplicationDomain.currentDomain.getDefinition("fe.serv.Gov60") as Class; }
            catch (noHighFps:*) { }
            if (highFpsHost != null) log("[FPS] host clock connected; simulation=host logic");
         }
         if (highFpsHost != null && !SandyHighFpsClock.isLogicFrame()) return;
         var manualFrame:Boolean = sandyActive || replaying;
         var wasSandy:Boolean = sandyActive;
         var wasReplay:Boolean = replaying;
         var oldPlayerX:Number = world.gg != null ? world.gg.X : 0;
         var oldPlayerY:Number = world.gg != null ? world.gg.Y : 0;
         try
         {
            if (world != null && world.verror != null && world.verror.visible)
            {
               var errtxt:String = "?";
               try { errtxt = String(world.verror.txt.text); } catch (e:*) { }
               log("[ERRDIALOG] " + errtxt);
            }
         }
         catch (e:*) { }

         if (debugTest)
         {
            stepDebugTest();
         }

         // 独立 ModSettings 异步加载；36000 帧内每 10 帧重试一次。
         // 未安装设置中枢时静默跳过；不创建独立设置弹窗。
         if (!hubRegistered && hubRegTries < 36000)
         {
            hubRegTries++;
            if (hubRegTries % 10 == 1)
            {
               stepHubRegister();
            }
            if (debugTest && hubRegTries % 600 == 0)
            {
               log("[TEST] hub tries=" + hubRegTries);
            }
         }

         try
         {
            if (world != null && world.gg != null)
            {
               var gc:Boolean = world.gg.ggControl;
               if (gc != lastGgControl && debugTest)
               {
                  log("[DIAG] ggControl changed to " + gc + " hp=" + world.gg.hp + " sost=" + world.gg.sost
                      + " X=" + world.gg.X + " Y=" + world.gg.Y + " sandy=" + sandyActive + " replay=" + replaying);
               }
               lastGgControl = gc;
            }
         }
         catch (e:*) { }

         if (!keyMapBuilt && world != null && world.ctr != null && world.ctr.keyXML != null)
         {
            buildKeyMap();
         }



         if (sandyActive)
         {
            stepSandy();
         }
         else if (replaying)
         {
            stepReplay();
         }
         else if (cooldownLeft > 0)
         {
            --cooldownLeft;
         }

         // v1.100：回放结束后弹药防泄漏钳制（4 秒窗口）
         if (leashLeft > 0)
         {
            ammoLeashTick();
         }

         // 注：疾跑切枪（swaprun）拦截在 KEY_DOWN 事件层（onKey）——游戏
         // World.step 的 ENTER_FRAME 先于模组注册，帧层拦截永远晚于游戏
         // 按键处理（v1.100 教训，见 onKey 内 v1.104 注释）。

         // v1.139：主题曲状态沿——时停开始沿放/续播，回放结束沿淡出
         tickMusic();
         if (sandyActive && !prevSandyActive) { playTheme(); }
         if (!replaying && prevReplaying) { fadeTheme(); }
         prevSandyActive = sandyActive;
         prevReplaying = replaying;

         // v1.89：投掷物击落**独立化**——常规游戏（无时停/回放）中每帧
         // 也执行判定：射击手雷/导弹/榴弹至血量归零随时引爆（projhits
         // 开关控制；时停/回放中各自的判定在 stepSandy/stepReplay 内）
         try
         {
            if (!sandyActive && !replaying && cfgProjHits && world != null && world.loc != null)
            {
               stepProjHits(world.loc, false);
            }
         }
         catch (e:*) { }
         // v1.115：敌人斯安维斯坦（常规游戏分支——场景 A：敌人 N× 补步；
         // 场景 B 的挂钩在 stepSandy 内）
         // v1.135：加 inGameplay() 门控——本体 pip 打开时 allStat=2 暂停世界，
         // 但本函数每显示帧照跑（5× 补步+状态机+徽标）→ 激活中的敌人继续
         // 移动= "打开哔哔小马界面时游戏不能暂停"（用户实测）。
         try
         {
            if (!sandyActive && !replaying && inGameplay())
            {
               stepEnemySandy();
            }
         }
         catch (e:*) { }

         updateHud();
         updateGhosts();
         if (highFpsHost != null)
         {
            highFpsView.finish(world, Number(highFpsHost["alpha"]),
               manualFrame || sandyActive || replaying, oldPlayerX, oldPlayerY,
               wasSandy != sandyActive || wasReplay != replaying);
         }
         if (cfgDiagLog)
         {
            if (diagTick++ % 60 == 0)
            {
               try
               {
                  var kL:Boolean = world.ctr.keyLeft;
                  var kR:Boolean = world.ctr.keyRight;
                  var kU:Boolean = world.ctr.keyBeUp;
                  var kD:Boolean = world.ctr.keySit;
                  var kJ:Boolean = world.ctr.keyJump;
                  var kA:Boolean = world.ctr.keyAttack;
                  log("[STATE] L=" + kL + " R=" + kR + " U=" + kU + " D=" + kD + " J=" + kJ + " A=" + kA
                      + " ggX=" + (world.gg != null ? world.gg.X : -1) + " ggY=" + (world.gg != null ? world.gg.Y : -1)
                      + " focus=" + world.swfStage.focus);
               }
               catch (err:*) { }
            }
         }
      }

      private function inGameplay():Boolean
      {
         if (world == null) return false;
         try
         {
            if (world.allStat < 1) return false;
            if (world.gg == null || world.loc == null) return false;
            if (world.onConsol) return false;
            if (world.pip != null && world.pip.active) return false;
            if (world.sats != null && world.sats.active) return false;
            if (world.stand != null && world.stand.active) return false;
            if (world.gui != null && world.gui.guiPause) return false;
            return true;
         }
         catch (e:*) { return false; }
         return false;
      }

      // ==================== 自动测试 ====================
      // v1.136 重写：覆盖 MEMORY §4 待验证清单的机器可验证项——
      //   ① 开新档 → 传送 random_mane → 拉怪（合成 ctr 输入实战）
      //   ② 玩家斯安维斯坦 + 回放（v1.130 玩家动画帧驱动采样；v1.132-134
      //      敌人回放：死亡敌人开火体冻结 / 无敌形 / 无念力抓取残留）
      //   ③ v1.135 哔哔小马（pip）打开时 allStat=2 + inGameplay()=false、
      //      关闭后恢复（stepEnemySandy 门控的输入侧；敌桑行为面按用户
      //      要求暂不测——esandy 默认已关）
      //   ④ v1.131 敌人斯安维斯坦三控件渲染（F9 面板 + 设置页 7→10 项、
      //      v1.136 默认"关"）
      //   ⑤ v1.127 迁移回归（projhits/swaprun 本侧停用断言）
      // 激活条件：config debugtest=1 且 app id ≠ "pfe"（见 init）——用户
      // 实例即使 config 残留 debugtest=1 也不会被自动驱动。断言逐条输出
      // [TEST-ASSERT] name=PASS/FAIL，结尾 [TEST] SUMMARY 汇总。
      private function stepDebugTest():void
      {
         try
         {
            // 错误对话框自愈（仅测试实例）：记录完整内容后模拟关闭，防全局冻结
            if (world != null && world.verror != null && world.verror.visible && testErrDiag < 6)
            {
               testErrDiag++;
               var et:String = "?";
               try { et = String(world.verror.txt.text); } catch (e2:*) { }
               log("[TEST] verror unfreeze #" + testErrDiag + ": " + et);
               world.verror.visible = false;
            }

            if (testStage == 0)
            {
               // 等开机完成：菜单就绪且 landData 已建（boot stage-2 没跑完
               // 就放菜单 → newGame 时 Game 构造器访问 landData #1009）
            if (world != null && world.mm != null && world.mm.loaded && world.landData != null)
            {
               log("[TEST] boot ready, driver starting");
               testAssert("esandy-default-off", cfgESEnabled == false, "cfgESEnabled=" + cfgESEnabled);
               testAssert("migrated-keys-off", cfgProjHits == false && cfgSwapRun == false,
                          "projhits=" + cfgProjHits + " swaprun=" + cfgSwapRun);
               world.mm.mainMenuOff();
               world.newGame(-1, "TEST", { "dif": 2, "propusk": true });
               testStage = 1;
               testTicks = 0;
            }
               else if (++testTicks > 1800) { testAssert("boot-ready", false, "timeout"); testStage = 10; }
            }
            else if (testStage == 1)
            {
               if (world.allStat >= 1 && world.gg != null && world.loc != null && world.game != null)
               {
                  var land1:String = "";
                  try { land1 = String(world.game.curLandId); } catch (eL:*) { }
                  log("[TEST] in game: land=" + land1 + " ggX=" + world.gg.X + " ggY=" + world.gg.Y);
                  testStage = 2;
                  testTicks = 0;
               }
               else if (++testTicks > 2700) { testAssert("new-game", false, "timeout"); testStage = 10; }
            }
            else if (testStage == 2)
            {
               // 传送马哈顿废墟（敌人最丰富）；重入当前土地/加载中旅行会挂死，先防护。
               // MSWAutoTest（测试实例同样自激活）会把 pip 开在设置页——先清场再走
               if (testSub == 0)
               {
                  try
                  {
                     if (world.pip != null && world.pip.active)
                     {
                        world.pip.onoff(-1);
                        log("[TEST] closed leftover pip (foreign driver state)");
                     }
                  }
                  catch (eP:*) { }
                  testSub = 1;
                  testTicks = 0;
               }
               else if (testSub == 1 && ++testTicks < 30)
               {
                  // 等 30 帧让 pip 关闭动画走完
               }
               else
               {
                  var clId:String = "";
                  try { clId = String(world.game.curLandId); } catch (e3:*) { }
                  if (clId != "" && clId != "random_mane")
                  {
                     log("[TEST] gotoLand random_mane (from " + clId + ")");
                     testPreTravelLoc = world.loc;
                     world.game.gotoLand("random_mane");
                     testStage = 3;
                     testTicks = 0;
                     testSub = 0;
                  }
                  else if (clId == "random_mane") { testStage = 3; testTicks = 0; testSub = 0; }
                  else if (++testTicks > 600) { testAssert("travel-start", false, "curLandId=" + clId); testStage = 10; }
               }
            }
            else if (testStage == 3)
            {
               testPipGuard();
               // 到达判定：curLandId 变更 + loc 引用已切换 + 90 帧稳定
               var arrB:Boolean = false;
               try
               {
                  arrB = (String(world.game.curLandId) == "random_mane" && world.loc != null
                          && world.loc != testPreTravelLoc && world.land != null && world.land.act != null);
               }
               catch (e4:*) { }
               if (arrB && ++testTicks > 90)
               {
                  log("[TEST] arrived random_mane, scanning enemies");
                  testStage = 4;
                  testTicks = 0;
               }
               else if (!arrB && ++testTicks > 1800)
               {
                  testTravelTries++;
                  if (testTravelTries < 3) { log("[TEST] travel retry #" + testTravelTries); testStage = 2; testTicks = 0; }
                  else { testAssert("travel-done", false, "3 tries timeout"); testStage = 10; }
               }
            }
            else if (testStage == 4)
            {
               testPipGuard();
               var ens:Array = testScanEnemies();
               if (ens.length > 0)
               {
                  testEnemy = ens[0];
                  var lst:String = "";
                  for (var iE:int = 0; iE < ens.length && iE < 5; iE++)
                  {
                     lst += flash.utils.getQualifiedClassName(ens[iE]).replace("fe.unit::", "") + "(hp=" + ens[iE].hp + ") ";
                  }
                  log("[TEST] enemies=" + ens.length + ": " + lst);
                  try { world.gg.setPos(testEnemy.X + 150, testEnemy.Y); } catch (e5:*) { }
                  log("[TEST] gg moved near enemy, combat warmup");
                  testStage = 5;
                  testTicks = 0;
                  testAtkT = 0;
               }
               else if (++testTicks > 1200)
               {
                  testAssert("enemies-found", false, "no hostiles in 40s");
                  testStage = 10;
               }
            }
            else if (testStage == 5)
            {
               if (testSub == 0)
               {
                  // 战斗热身 60 帧（拉仇恨、产生真实输入流）——站在怪堆里必挨打，
                  // 期间持续治疗，之后等恢复；带伤(sost=2)进时停会让门控拒启
                  if (testTicks == 0) { log("[TEST] combat warmup"); }
                  testDriveCombat();
                  if (testTicks % 45 == 30) { try { world.pers.healAll(); } catch (eH0:*) { } }
                  testTicks++;
                  if (testTicks >= 60)
                  {
                     testStopKeys();
                     try { world.pers.healAll(); } catch (eH:*) { }
                     try { world.gg.controlOn(); } catch (e6:*) { }   // 开场对话可能 ggControl=false
                     log("[TEST] warmup done, waiting recovery+enemies");
                     testSub = 1;
                     testTicks = 0;
                  }
               }
               else if (testSub == 1)
               {
                  testPipGuard();
                  var igp5:Boolean = inGameplay();
                  var sost5:int = 3;
                  try { sost5 = world.gg.sost; } catch (e5b:*) { }
                  if (!igp5)
                  {
                     // 倒地/治疗恢复周期：每 30 帧补一次治疗（斑马群 dps 下
                     // 120 帧间隔会被再次放倒），持续等
                     if (testTicks % 30 == 15) { try { world.pers.healAll(); } catch (eH2:*) { } }
                     testTicks++;
                     if (testTicks > 1200)
                     {
                        testAssert("player-recovered", false, "inGameplay never true (sost=" + sost5 + ")");
                        testStage = 8; testSub = 0; testTicks = 0;
                     }
                  }
                  else if (sost5 >= 2)
                  {
                     testTicks++;
                     if (testTicks > 900)
                     {
                        testAssert("player-recovered", false, "sost stuck >=2 (" + sost5 + ")");
                        testStage = 8; testSub = 0; testTicks = 0;
                     }
                  }
                  else
                  {
                     // 已恢复：等敌人回到可交战状态（飞行怪飞远会被游戏 disabled）
                     var base2:Array = testScanEnemies();
                     if (base2.length > 0 || testTicks > 600)
                     {
                        if (base2.length == 0)
                        {
                           log("[TEST] no engaged enemies after wait, proceed (residue asserts will be vacuous)");
                           testDiagUnits();
                        }
                        // 基线：时停瞬间每个敌人的可见性/抓取状态（回放后对比变化）
                        testFlagsBase = new Dictionary();
                        var nB:int = 0;
                        for (var iB:int = 0; iB < base2.length; iB++)
                        {
                           testFlagsBase[base2[iB]] = esVisState(base2[iB]);
                           nB++;
                        }
                        // 造击杀机会：全部敌人压到 30% 血、最弱的打到 1hp
                        //（时停中快速减员 → dead-fire 断言有数据、挨打窗口缩短）
                        for (var iW:int = 0; iW < base2.length; iW++)
                        {
                           try
                           {
                              var uW:Object = base2[iW];
                              uW.damage(Math.max(1, uW.hp * 0.7), 0, null, false);
                           }
                           catch (eW:*) { }
                        }
                        var weak:Object = null;
                        for (var iW2:int = 0; iW2 < base2.length; iW2++)
                        {
                           try
                           {
                              if (weak == null || base2[iW2].hp < weak.hp) { weak = base2[iW2]; }
                           }
                           catch (eW2:*) { }
                        }
                        if (weak != null) { try { weak.damage(weak.hp - 1, 0, null, false); } catch (eD2:*) { } }
                        log("[TEST] startSandy inGameplay=" + igp5 + " hp=" + world.gg.hp + " sost=" + sost5
                            + " enemies=" + base2.length + " baseFlags=" + nB);
                        testAssert("inGameplay-before-sandy", igp5, "");
                        testGgDowned = (sost5 >= 2);
                        startSandy();
                        testStage = 6;
                        testTicks = 0;
                        testAtkT = 0;
                        testSandySeen = false;
                     }
                     else { testTicks++; }
                  }
               }
            }
            else if (testStage == 6)
            {
               // 时停段：持续合成输入（玩家全速攻击/走位），结束后回放
               testPipGuard();
               if (testTicks == 1 && !sandyActive)
               {
                  // startSandy 首次未生效（门控未过）——重试一次
                  try { world.gg.controlOn(); startSandy(); } catch (e7:*) { }
                  log("[TEST] startSandy retry, sandyActive=" + sandyActive);
               }
               if (sandyActive)
               {
                  testSandySeen = true;
                  if (world.gg.sost >= 2) { testGgDowned = true; }
                  // 时停中持续治疗：敌人 1/5 速但仍能放倒 Fresh 小马 → 动画断言失真
                  if (testTicks % 30 == 15) { try { world.pers.healAll(); } catch (eH3:*) { } }
                  testDriveCombat();
                  if (testTicks % 60 == 30)
                  {
                     log("[TEST] sandy t=" + testTicks + " left=" + sandyLeft + " hp=" + world.gg.hp + " sost=" + world.gg.sost);
                  }
               }
               testTicks++;
               if (testSandySeen && !sandyActive)
               {
                  // duration 计满由 stepSandy 自动 endSandy（210 帧 ≈ t=151）——
                  // 自然结束≠未启动，直接进入回放观察
                  log("[TEST] sandy ended naturally at t=" + testTicks + ", waiting replay");
                  testStopKeys();
                  testStage = 7;
                  testTicks = 0;
                  testAnimSamples = "";
                  testDeadAtkSnap = new Dictionary();
                  testDeadSnapN = 0;
                  testDeadAtkNew = 0;
                  testReplaySeen = false;
               }
               else if (!testSandySeen && testTicks > 90)
               {
                  testAssert("sandy-started", false, "never activated");
                  testStage = 8; testSub = 0; testTicks = 0;
               }
               else if (testTicks >= 600)
               {
                  // 保险：duration 被调大时强停（正常路径到不了这里）
                  testStopKeys();
                  if (sandyActive) { endSandy(); }
                  log("[TEST] sandy force-ended at t=" + testTicks);
                  testStage = 7;
                  testTicks = 0;
                  testAnimSamples = "";
                  testDeadAtkSnap = new Dictionary();
                  testDeadSnapN = 0;
                  testDeadAtkNew = 0;
                  testReplaySeen = false;
               }
            }
            else if (testStage == 7)
            {
               // 回放段：逐逻辑步检查死亡后新增攻击，逐 5 帧采样玩家动画帧
               testPipGuard();
               if (replaying)
               {
                  if (!testReplaySeen)
                  {
                     testReplaySeen = true;
                     testDeadAtkSample("start");
                     log("[TEST] replay started, sampling");
                  }
                  if (testTicks % 5 == 0 && testTicks > 0)
                  {
                     testAnimSamples += animFrameOf(world.gg) + ",";
                  }
                  testDeadAtkSample("run");
                  testTicks++;
                  if (testTicks > 5400)
                  {
                     testAssert("replay-finished", false, "timeout 180s");
                     testFinishReplayChecks();
                     testStage = 8; testSub = 0; testTicks = 0;
                  }
               }
               else if (!testReplaySeen)
               {
                  testTicks++;
                  if (testTicks > 30)
                  {
                     testAssert("replay-started", false, "replaying never observed");
                     testStage = 8; testSub = 0; testTicks = 0;
                  }
               }
               else
               {
                  testFinishReplayChecks();
                  testStage = 8; testSub = 0; testTicks = 0;
               }
            }
            else if (testStage == 8)
            {
               // v1.135：哔哔小马打开 → allStat=2 世界暂停 + inGameplay()=false；
               // 设置页（page=5）打开时模组设置区渲染（v1.131 三控件、10 项）
               if (testSub == 0)
               {
                  // 清场：MSWAutoTest（测试实例自激活）可能把 pip 留在打开状态，
                  // 先强制关闭再走自己的开关序列
                  try
                  {
                     if (world.pip != null && world.pip.active)
                     {
                        world.pip.onoff(-1);
                        log("[TEST] closed leftover pip before pip test");
                     }
                  }
                  catch (eP8:*) { }
                  testSub = 5;
                  testTicks = 0;
               }
               else if (testSub == 5 && ++testTicks > 30)
               {
                  log("[TEST] pip test pre: inGameplay=" + inGameplay() + " allStat=" + world.allStat);
                  try { world.pip.onoff(0); } catch (e8:*) { log("[TEST] pip open err: " + e8); }
                  testSub = 1; testTicks = 0;
               }
               else if (testSub == 1 && ++testTicks > 45)
               {
                  var pA:Boolean = false;
                  try { pA = world.pip.active; } catch (e9:*) { }
                  testAssert("pip-open", pA, "");
                  testAssert("pip-pauses-gameplay", pA && !inGameplay() && world.allStat == 2,
                             "pip=" + pA + " inGameplay=" + inGameplay() + " allStat=" + world.allStat);
                  try { world.pip.onoff(5); } catch (e10:*) { log("[TEST] pip opt err: " + e10); }
                  testSub = 3; testTicks = 0;
               }
               else if (testSub == 3 && ++testTicks > 45)
               {
                  var legacyOverlay:Boolean = false;
                  for (var childIndex:int = 0; childIndex < world.main.numChildren; childIndex++)
                  {
                     var settingsText:TextField = world.main.getChildAt(childIndex) as TextField;
                     if (settingsText != null && settingsText.visible && settingsText.text.indexOf("-- SandevistanMod --") >= 0) legacyOverlay = true;
                  }
                  testAssert("legacy-settings-overlay-removed", !legacyOverlay, "");
                  if (hubRegistered)
                  {
                     try
                     {
                        var menuAPI:Object = world.main.getChildByName("ModSettingsCarrier")["modAPI"];
                        var menuOpened:Boolean = menuAPI.selectPage("sandevistan");
                        testAssert("settings-menu-opens", menuOpened && menuAPI.isOpen(), "");
                        var registeredPage:Object = null;
                        for each (var settingPage:Object in menuAPI.getPages())
                           if (settingPage.modId == "sandevistan") registeredPage = settingPage;
                        var durationItem:Object = null;
                        for each (var settingItem:Object in registeredPage.items)
                           if (settingItem.key == "duration") durationItem = settingItem;
                        var originalDuration:Number = durationItem.get();
                        var trialDuration:Number = originalDuration == 9 ? 10 : 9;
                        durationItem.set(trialDuration);
                        menuAPI.togglePage("sandevistan"); // Real close callback flushes sliders.
                        var storageFile:File = File.applicationStorageDirectory.resolvePath("SandevistanMod_config.txt");
                        var storageStream:FileStream = new FileStream();
                        storageStream.open(storageFile, FileMode.READ);
                        var savedSettings:String = storageStream.readUTFBytes(storageStream.bytesAvailable);
                        storageStream.close();
                        cfgDuration = 30; loadConfig(); debugTest = true; // Saved config disables automation; keep this isolated test running.
                        testAssert("menu-settings-save-reload", cfgDuration == trialDuration * 30
                           && savedSettings.indexOf("duration=" + int(trialDuration * 30)) >= 0
                           && savedSettings.indexOf("panelkey=") < 0, "duration=" + cfgDuration);
                        durationItem.set(originalDuration); registeredPage.onPageClose();
                     }
                     catch (menuError:*) { testAssert("settings-menu-flow", false, String(menuError)); }
                  }                  try { world.pip.onoff(-1); } catch (e11:*) { }
                  testSub = 4; testTicks = 0;
               }
               else if (testSub == 4 && ++testTicks > 45)
               {
                  var pA2:Boolean = true;
                  try { pA2 = world.pip.active; } catch (e12:*) { }
                  testAssert("pip-resume", !pA2 && inGameplay(), "pip=" + pA2 + " inGameplay=" + inGameplay());
                  testSub = 0;
                  testStage = 9;
                  testTicks = 0;
               }
            }
            else if (testStage == 9)
            {
               // Removed standalone shortcut must not create a display or consume input.
               var childrenBefore:int = world.main.numChildren;
               var f9Reached:Boolean = false;
               var f9Observer:Function = function(event:KeyboardEvent):void { f9Reached = true; };
               world.main.stage.addEventListener(KeyboardEvent.KEY_DOWN, f9Observer, false, -1000);
               world.main.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_DOWN, true, false, 0, Keyboard.F9));
               world.main.stage.removeEventListener(KeyboardEvent.KEY_DOWN, f9Observer);
               world.main.stage.dispatchEvent(new KeyboardEvent(KeyboardEvent.KEY_UP, true, false, 0, Keyboard.F9));
               testAssert("standalone-f9-removed", world.main.numChildren == childrenBefore && f9Reached,
                          "children=" + childrenBefore + "->" + world.main.numChildren + " forwarded=" + f9Reached);
               testSub = 0; testStage = 11; testTicks = 0;
            }            else if (testStage == 11)
            {
               // v1.139：第二周目——第二次 startSandy 应从断点续播主题曲
               testPipGuard();
               if (testSub == 0)
               {
                  try { world.gg.controlOn(); } catch (eS2:*) { }
                  if (inGameplay())
                  {
                     startSandy();
                     log("[TEST] second sandy cycle (music resume check)");
                     testSub = 1;
                     testTicks = 0;
                  }
                  else if (++testTicks > 300)
                  {
                     testAssert("second-sandy", false, "not in gameplay");
                     testStage = 10; testSub = 0; testTicks = 0;
                  }
               }
               else if (testSub == 1)
               {
                  // 时停自然结束→回放→回放结束（第二次淡出）后收尾
                  testTicks++;
                  if (testTicks > 900 || (!sandyActive && !replaying && testTicks > 90))
                  {
                     testStage = 10; testSub = 0; testTicks = 0;
                  }
               }
            }
            else if (testStage == 10)
            {
               if (!testDone)
               {
                  testDone = true;
                  // v1.137：hub 注册——跨域限制（各模组独立子域，MainFE 用
                  // LoaderContext(false) 加载）下类名查找必然 #1065，不是本侧
                  // 缺陷；重试常驻，宿主侧可达性修复后 10 帧内自动接上
                  if (hubRegistered)
                  {
                     testPass++;
                     log("[TEST-ASSERT] hub-registered=PASS (via=" + (hubViaCarrier ? "carrier" : "getDefinition")
                         + " tries=" + hubRegTries + ")");
                     // 端到端：从宿主登记簿反查本页（13 项）——证明宿主真正收到了
                     try
                     {
                        var cP:* = world.main.getChildByName("ModSettingsCarrier");
                        var pages:Array = cP["modAPI"]["getPages"]();
                        var foundI:int = -1;
                        for (var ip:int = 0; ip < pages.length; ip++)
                        {
                           if (pages[ip]["modId"] == "sandevistan") { foundI = ip; }
                        }
                        testAssert("hub-page-listed", foundI >= 0 && pages[foundI]["items"].length == 16,
                                   "pages=" + pages.length + " foundIdx=" + foundI
                                   + (foundI >= 0 ? " items=" + pages[foundI]["items"].length : ""));
                     }
                     catch (eG:*) { testAssert("hub-page-listed", false, String(eG)); }
                  }
                  else
                  {
                     testSkipCnt++;
                     log("[TEST-ASSERT] hub-registered=SKIP (cross-domain blocked; retry standing, tries=" + hubRegTries + ")");
                  }
                  testAssert("hub-items-16", hubBuildItems().length == 16, "n=" + hubBuildItems().length);
                  // v1.139：主题曲链路断言（start/断点续播/fade/stop 旗标由音乐模块埋设）
                  testAssert("music-start", musStartSeen, "");
                  testAssert("music-resume-breakpoint", musResumeSeen, "lastPos=" + int(musLastPos));
                  testAssert("music-fade", musFadeSeen, "");
                  testAssert("music-stop", musStopSeen, "");
                  log("[TEST] SUMMARY pass=" + testPass + " fail=" + testFail + " skip=" + testSkipCnt
                      + (testFail > 0 ? " failed=[" + testFailNames + "]" : ""));
                  log("[TEST] done");
               }
            }
         }
         catch (e:*) { log("[TEST] error: " + e); }
      }

      // v1.136：断言记录——每条一行 [TEST-ASSERT]，SUMMARY 汇总
      private function testAssert(name:String, cond:Boolean, detail:String):void
      {
         if (cond) { testPass++; }
         else
         {
            testFail++;
            testFailNames = testFailNames + (testFail > 1 ? ";" : "") + name;
         }
         log("[TEST-ASSERT] " + name + "=" + (cond ? "PASS" : "FAIL") + (detail != "" ? " (" + detail + ")" : ""));
      }

      // v1.136：扫描当前房间敌对单位（fraction∈[1,99]、sost<3、未禁用、非触发器）
      private function testScanEnemies():Array
      {
         var out:Array = [];
         try
         {
            var us:* = world.loc.units;
            for each (var u:Object in us)
            {
               try
               {
                  if (u == null || u.disabled) continue;
                  var fr:Number = Number(u.fraction);
                  if (!(fr >= 1 && fr <= 99)) continue;
                  if (u.sost >= 3) continue;
                  var qn:String = flash.utils.getQualifiedClassName(u);
                  if (qn.indexOf("UnitTrigger") >= 0) continue;
                  out.push(u);
               }
               catch (eS:*) { }
            }
         }
         catch (eO:*) { }
         return out;
      }

      // v1.136：合成战斗输入（攻击脉冲 + 走位）——直接写 ctr 键位字段
      private function testDriveCombat():void
      {
         try
         {
            var c:Object = world.ctr;
            var ph:int = testAtkT % 40;
            c.keyAttack = (ph < 12);
            var mv:Boolean = ((testAtkT % 160) < 80);
            c.keyRight = (mv && ph < 30);
            c.keyLeft = (!mv && ph < 30);
            c.keyBeUp = (ph >= 12 && ph < 24);
            testAtkT++;
         }
         catch (e:*) { }
      }

      // v1.136：松开全部合成键位
      private function testStopKeys():void
      {
         try
         {
            var c:Object = world.ctr;
            c.keyAttack = false;
            c.keyRight = false;
            c.keyLeft = false;
            c.keyBeUp = false;
            c.keySit = false;
            c.keyJump = false;
         }
         catch (e:*) { }
      }

      // v1.144：死亡禁止新开火，已发射的弹体仍可飞行/按录像移动。
      // 先按引用登记攻击体，再记录死亡状态，避免将同一步先开火后死亡误判。
      private function testDeadAtkSample(phase:String):void
      {
         if (world.loc == null) return;
         if (phase == "start")
         {
            testDeadAtkSnap = new Dictionary();
            testDeadOwners = new Dictionary();
            testDeadSnapN = 0;
            testDeadAtkNew = 0;
            // 录像可能持有已离开链表的旧弹体，重新可见仍不是新开火。
            for each (var recorded:Object in replayObjArr) testDeadAtkSnap[recorded] = true;
         }
         var o:Object = world.loc.firstObj;
         var g:int = 0;
         while (o != null)
         {
            try
            {
               var qn:String = flash.utils.getQualifiedClassName(o);
               if (qn.indexOf("fe.weapon::") == 0)
               {
                  var owner:Object = o["owner"];
                  if (phase != "start" && testDeadAtkSnap[o] == null && owner != null
                      && owner != world.gg && testDeadOwners[owner] == true
                      && int(owner.sost) >= 3 && !Boolean(owner.postDie))
                  {
                     testDeadAtkNew++;
                     if (testDeadAtkNew <= 3) log("[TEST] new shot from already-dead owner: " + qn);
                  }
                  testDeadAtkSnap[o] = true;
               }
            }
            catch (eD:*) { }
            o = o.nobj;
            if (++g > 20000) break;
         }
         var units:Array = world.loc.units.concat(replayObjArr);
         for each (var u:Object in units)
         {
            try
            {
               if (u != world.gg && int(u.sost) >= 3 && !Boolean(u.postDie)
                   && testDeadOwners[u] == null)
               {
                  testDeadOwners[u] = true;
                  testDeadSnapN++;
               }
            }
            catch (eU:*) { }
         }
      }
      // 回放结束断言组（动画帧驱动 / 尸体新增攻击 / 隐形与抓取残留）
      private function testFinishReplayChecks():void
      {
         // ① v1.130：玩家动画帧采样——站立玩家回放中 osn.body.currentFrame 应有多个值；
         //    倒地玩家本就只有一帧姿态（静态是正确表现）→ SKIP
         if (testGgDowned)
         {
            testSkipCnt++;
            log("[TEST-ASSERT] replay-player-anim-driven=SKIP (player downed during sandy; static downed pose is correct)");
         }
         else
         {
            var distinct:Array = [];
            var sa:Array = testAnimSamples.split(",");
            for each (var sf:String in sa)
            {
               if (sf != "" && distinct.indexOf(sf) < 0) { distinct.push(sf); }
            }
            testAssert("replay-player-anim-driven", distinct.length >= 2, "frames=[" + testAnimSamples + "]");
         }
         // ② 已死亡且非 postDie 的敌人不得新开火；无死亡样本时明确跳过。
         if (testDeadSnapN == 0)
         {
            testSkipCnt++;
            log("[TEST-ASSERT] dead-enemy-no-new-attacks=SKIP (no dead owner observed)");
         }
         else testAssert("dead-enemy-no-new-attacks", testDeadAtkNew == 0,
                         "new=" + testDeadAtkNew + " deadOwners=" + testDeadSnapN);
         // ③ v1.132：无隐身/抓取残留——对比时停瞬间基线，只对活单位的状态"变化"报警。
         //    invis/levitPoss 有合法状态相（钻地=inv1+lev0；部分怪自带隐身相），绝对值
         //    断言必误报；残留的用户可见症状 = 活单位渲染消失 / 念力抓取能力丢失
         var resInv:int = 0;
         var resLev:int = 0;
         var det:String = "";
         var aliveN:int = 0;
         var deadN:int = 0;
         try
         {
            for each (var u2:Object in world.loc.units)
            {
               try
               {
                  var qn2:String = flash.utils.getQualifiedClassName(u2);
                  if (qn2.indexOf("fe.unit::") != 0 || qn2.indexOf("UnitTrigger") >= 0) continue;
                  var baseS:String = testFlagsBase[u2];
                  if (baseS == null) continue;               // 无基线（新生成单位）不判
                  if (u2.sost >= 3) { deadN++; continue; }   // 死亡引起的状态变化合法
                  aliveN++;
                  var nowS:String = esVisState(u2);
                  var bInv:Boolean = testFlagOf(baseS, "inv=");
                  var nInv:Boolean = testFlagOf(nowS, "inv=");
                  var bLev:Boolean = testFlagOf(baseS, "lev=");
                  var nLev:Boolean = testFlagOf(nowS, "lev=");
                  var bVis:Boolean = testFlagOf(baseS, "vis=");
                  var nVis:Boolean = testFlagOf(nowS, "vis=");
                  if ((nInv && !bInv) || (bVis && !nVis))
                  {
                     resInv++;
                     det += qn2.replace("fe.unit::", "") + "(inv " + (bInv ? 1 : 0) + "->" + (nInv ? 1 : 0)
                          + " vis " + (bVis ? 1 : 0) + "->" + (nVis ? 1 : 0) + ") ";
                  }
                  if (bLev && !nLev)
                  {
                     resLev++;
                     det += qn2.replace("fe.unit::", "") + "(lev 1->0) ";
                  }
               }
               catch (eI:*) { }
            }
         }
         catch (eO:*) { }
         testAssert("no-invisibility-residue", resInv == 0, "alive=" + aliveN + " dead=" + deadN + " " + det);
         testAssert("no-telegrab-residue", resLev == 0, "alive=" + aliveN + " dead=" + deadN + " " + det);
         log("[TEST] replay checks done: animSamples=" + testAnimSamples);
      }

      // v1.136：从 esVisState 输出串中取 "key=" 后的 0/1 值
      private function testFlagOf(s:String, key:String):Boolean
      {
         var i:int = s.indexOf(key);
         if (i < 0) return false;
         var c:String = s.charAt(i + key.length);
         return c == "1" || c == "t";
      }

      // v1.137：MSWAutoTest（appid≠pfe 自激活）会在测试实例里自行开 pip 到
      // 设置页——inGameplay() 检查 pip.active，pip 开着时停/pip 断言全废。
      // 各阶段循环前清场。
      private function testPipGuard():void
      {
         try
         {
            if (world.pip != null && world.pip.active)
            {
               world.pip.onoff(-1);
               testPipCloses++;
               if (testPipCloses <= 6) { log("[TEST] pip-guard closed foreign pip #" + testPipCloses); }
            }
         }
         catch (e:*) { }
      }

      // v1.136：诊断输出当前 loc 全部单位的状态（敌人等不到位时定性用）
      private function testDiagUnits():void
      {
         try
         {
            var n:int = 0;
            for each (var u:Object in world.loc.units)
            {
               try
               {
                  if (u == null) continue;
                  var qn:String = flash.utils.getQualifiedClassName(u);
                  if (qn.indexOf("fe.unit::") != 0 || qn.indexOf("UnitTrigger") >= 0) continue;
                  log("[TEST] unit diag: " + qn.replace("fe.unit::", "")
                      + " sost=" + u.sost + " dis=" + (u.disabled ? 1 : 0)
                      + " fr=" + u.fraction + " hp=" + u.hp + " X=" + u.X + " Y=" + u.Y);
                  if (++n >= 8) break;
               }
               catch (eU:*) { }
            }
         }
         catch (eO:*) { }
      }

      // ==================== 选项页模组设置 ====================
      // ===== 清除时停期间玩家发射的冻结子弹（回放重演避免双倍火力）=====
      private function clearFrozenBullets():void
      {
         try
         {
            var loc:Object = world.loc;
            if (loc == null) return;
            var obj:Object = loc.firstObj;
            var guard:int = 0;
            var nFe:int = 0;      // 攻击体对象总数（fe.weapon::*）
            var nRem:int = 0;     // 实际清除数
            var nSkip:int = 0;    // 未清除数（owner 不是玩家，或异常）
            while (obj != null)
            {
               var nxt:Object = obj.nobj;
               try
               {
                  var qn:String = flash.utils.getQualifiedClassName(obj);
                  if (qn.indexOf("fe.weapon::") == 0)
                  {
                     nFe++;
                     // v1.91：投掷武器（G 键手雷）抛出的投掷物保留——回放
                     // 不重执行抛掷（keyGrenad 不回喂），录像体=唯一实体，
                     // 按记录重演轨迹，回放结束后继续自然飞行/爆炸。其余
                     // 玩家攻击体（子弹/魔法/枪械投掷物）由回放重执行生成
                     // 新体，冻结原体清除（防双倍火力）。
                     var isThrownP:Boolean = false;
                     try { isThrownP = obj.weap != null && obj.weap == world.gg["throwWeapon"]; } catch (e:*) { }
                     if (obj.owner == world.gg && preExistB[obj] == null && !isThrownP)
                     {
                        loc.remObj(obj);
                        nRem++;
                     }
                     else
                     {
                        nSkip++;
                     }
                  }
               }
               catch (e:*) { }
               obj = nxt;
               if (++guard > 20000) break;
            }
            log("[DIAG] clearFrozenBullets: feWeapon=" + nFe + " removed=" + nRem + " skip=" + nSkip);
         }
         catch (e:*) { }
      }

      // ===== 攻击体追踪器（v1.85）：攻击体按引用录像，绕开"链扫描录不到
      // 攻击体"之谜（nPb 诊断证明对象在链中、录像却恒 0——按引用持有对象
      // 逐帧记录，不依赖链扫描）。玩家步后/节流步后调用登记新生成的攻击体。
      private function registerAtk(oA:Object):void
      {
         try
         {
            if (oA == null || seenAtk[oA] != null || replayObjs[oA] != null) return;
            seenAtk[oA] = true;
            var arr:Array = [];
            replayObjs[oA] = arr;
            replayObjArr.push(oA);
            var frameN:int = cfgDuration - sandyLeft;
            var sndA:String = "";
            try { if (oA.weap != null && oA.weap.sndShoot != null) { sndA = oA.weap.sndShoot; } } catch (e:*) { }
            for (var f:int = 0; f <= frameN; f++)
            {
               // v1.90：生成前补帧 vv=false——时停中新生成的攻击体（时停中
               // 才出手的枪械/投掷）在回放开头不可见（否则冻结显示在生成
               // 位置，表现为"回放开头凭空出现"）
               arr.push({ x: oA.X, y: oA.Y, f: -1, s: (f == frameN ? sndA : ""), wx: 0, wy: 0, twx: 0, twy: 0, vv: f == frameN, sto: 1, wrot: -99 });
            }
            log("[DIAG] recAtk: cls=" + flash.utils.getQualifiedClassName(oA) + " X=" + oA.X + " Y=" + oA.Y + " frameN=" + frameN);
         }
         catch (e:*) { }
      }

      // ===== 时停中记录重演状态（场景级录像：每帧位置+动画帧+生成音效）=====
      // 单位/攻击体必记录；场景对象移动检测（静态对象不记录，省存储）
      private function recordReplayObjects():void
      {
         try
         {
            var frameN:int = cfgDuration - sandyLeft;   // 时停内帧号（0 起）
            var locR:Object = world.loc;
            if (locR == null) return;
            var oR:Object = locR.firstObj;
            var gR:int = 0;
            while (oR != null)
            {
               var nxR:Object = oR.nobj;
               try
               {
                  if (oR == world.gg) { /* 玩家跳过（历史记录） */ }
                  else if (slowPartClass != null && oR is slowPartClass) { /* 粒子跳过 */ }
                  else if (seenAtk[oR] != null) { /* 攻击体由追踪器记录（v1.85） */ }
                  else
                  {
                  var qnR:String = flash.utils.getQualifiedClassName(oR);
                  var isAtk:Boolean = qnR.indexOf("fe.weapon::") == 0;
                  // 单位判断：fe.unit:: / fe.serv::（NPC 在 serv 包）/ 有 setPos 方法
                  // （Unit 子类）。v1.90：setPos 括号探测改 try/catch——密封类
                  // （Bullet/Box）上访问不存在成员抛 ReferenceError，此前整个
                  // 链扫描体被吞（"链扫描之谜"：nPb 有值但录像恒 0 的真因）
                  var isUnit:Boolean = qnR.indexOf("fe.unit::") == 0 || qnR.indexOf("fe.serv::") == 0;
                  try { if (!isUnit && oR["setPos"] != null) { isUnit = true; } } catch (e:*) { }
                     // 敌人武器位置（回放中武器不 step，记录位置供回放恢复——否则武器
                     // 滞留在时停结束位置，与重演的身体脱节）
                     var wxR:Number = 0;
                     var wyR:Number = 0;
                     // 投掷武器（手雷/投掷物，非 currentWeapon）与魔法武器同样记录
                     var txR:Number = 0;
                     var tyR:Number = 0;
                     // 视觉可见性（v1.76：尸鬼钻地/炮塔死亡隐藏等按记录重演）
                     var vvR:Boolean = true;
                     try { if (oR.vis != null) { vvR = oR.vis.visible; } } catch (e:*) { }
                     // v1.132：记录隐身/可抓取标志（回放 AI 分歧会推入 burrow/隐身：
                     // aiState=5 → invis=true + levitPoss=false，按记录强压回去）
                     var ivR:Boolean = false;
                     try { if (oR.invis != null) { ivR = Boolean(oR.invis); } } catch (e:*) { }
                     var lvR:Boolean = true;
                     try { if (oR.levitPoss != null) { lvR = Boolean(oR.levitPoss); } } catch (e:*) { }
                     // v1.134：记录敌人 animState + osn 标签（MC 小马类回放按帧
                     // 快照；Blit 怪无标签 → "" → 走 dx 喂入）
                     var anR:String = "";
                     try { anR = oR.animState != null ? String(oR.animState) : ""; } catch (e:*) { }
                     var blR:String = osnLabelOf(oR);
                     var bpR:Object = isUnit ? replayBlit.capture(oR) : null;
                     // 朝向与武器转动（v1.79：回放中 AI 因位置重钉不转向、
                     // 瞄准目标失真——按记录恢复 storona 与武器 rot）
                     var stoR:Number = 1;
                     try { if (oR.storona != null) { stoR = oR.storona; } } catch (e:*) { }
                     var wrotR:Number = -99;
                     try
                     {
                        var cwRec:* = oR["currentWeapon"];
                        if (cwRec != null && cwRec.rot != null) { wrotR = cwRec.rot; }
                     }
                     catch (e:*) { }
                     // 视觉帧（v1.81：门开关等场景交互动画——帧变化触发记录，
                     // 回放按帧重演）
                     var vfR2:int = -1;
                     try { if (oR.vis != null && oR.vis.currentFrame != null) { vfR2 = oR.vis.currentFrame; } } catch (e:*) { }
                     try
                     {
                        var cwR:* = oR["currentWeapon"];
                        if (cwR != null) { wxR = cwR.X; wyR = cwR.Y; }
                        var twR:* = oR["throwWeapon"];
                        if (twR != null) { txR = twR.X; tyR = twR.Y; }
                        else
                        {
                           var mwR:* = oR["magicWeapon"];
                           if (mwR != null) { txR = mwR.X; tyR = mwR.Y; }
                        }
                     }
                     catch (e:*) { }
                     var arrR:Array = replayObjs[oR];
                     // 诊断（v1.84）：前几个 fe.weapon/fe.loc 对象——定位
                     // "录像 atk 恒 0 / 投掷箱不重演"之谜（对象在链中却不被录）
                     try
                     {
                        if (recDiagCnt < 6 && (isAtk || qnR.indexOf("fe.loc::") == 0))
                        {
                           recDiagCnt++;
                           log("[DIAG] recObj: cls=" + qnR + " X=" + oR.X + " Y=" + oR.Y
                               + " arr=" + (arrR != null ? 1 : 0) + " frameN=" + frameN);
                        }
                     }
                     catch (e:*) { }
                     if (arrR == null)
                     {
                        if (isAtk || isUnit)
                        {
                           // 单位/攻击体：必记录（补前期帧为当前位置，数组对齐 replayIdx）
                           arrR = [];
                           replayObjs[oR] = arrR;
                           replayObjArr.push(oR);
                           var sndR:String = "";
                           if (frameN > 0)
                           {
                              // 时停中生成的攻击体：记录生成音效（重演时重播）
                              try
                              {
                                 if (oR.weap != null && oR.weap.sndShoot != null) { sndR = oR.weap.sndShoot; }
                              }
                              catch (e:*) { }
                           }
                           for (var f0:int = 0; f0 < frameN; f0++) { arrR.push({ x: oR.X, y: oR.Y, f: -1, s: "", wx: wxR, wy: wyR, twx: txR, twy: tyR, vv: vvR, sto: stoR, wrot: wrotR, iv: ivR, lv: lvR, an: anR, bl: blR, bp: bpR }); }
                           arrR.push({ x: oR.X, y: oR.Y, f: animFrameOf(oR), s: sndR, wx: wxR, wy: wyR, twx: txR, twy: tyR, vv: vvR, sto: stoR, wrot: wrotR, iv: ivR, lv: lvR, an: anR, bl: blR, bp: bpR });
                        }
                        else
                        {
                           // 场景对象：移动或视觉帧变化（门开关/机关动画）才记录
                           // ——视觉帧变化=交互动画（位置不动也记录，回放按帧重演）
                           var sp:Object = seenPos[oR];
                           if (sp == null) { seenPos[oR] = { x: oR.X, y: oR.Y, vf: vfR2 }; }
                           else if (sp.x != oR.X || sp.y != oR.Y || sp.vf != vfR2)
                           {
                              arrR = [];
                              replayObjs[oR] = arrR;
                              replayObjArr.push(oR);
                              for (var f1:int = 0; f1 < frameN; f1++) { arrR.push({ x: sp.x, y: sp.y, f: -1, s: "", wx: 0, wy: 0, twx: 0, twy: 0, vv: vvR, vf: sp.vf }); }
                              arrR.push({ x: oR.X, y: oR.Y, f: -1, s: "", wx: 0, wy: 0, twx: 0, twy: 0, vv: vvR, vf: vfR2 });
                              sp.vf = vfR2;
                           }
                        }
                     }
                     else
                     {
                        arrR.push({ x: oR.X, y: oR.Y, f: animFrameOf(oR), s: "", wx: wxR, wy: wyR, twx: txR, twy: tyR, vv: vvR, sto: stoR, wrot: wrotR, vf: vfR2, iv: ivR, lv: lvR, an: anR, bl: blR, bp: bpR });
                     }
                  }
               }
               catch (e:*) { }
               oR = nxR;
               if (++gR > 20000) break;
            }
            // 箱子/物品对象（loc.objs——Box 不在 firstObj 链，念力投掷的箱子
            // 之前没被记录导致不回演）：移动检测，动了才记录
            try
            {
               var objsArr:Array = locR.objs;
               if (objsArr != null)
               {
                  for each (var oB2:Object in objsArr)
                  {
                     try
                     {
                        if (oB2 == null || oB2 == world.gg || replayObjs[oB2] != null) continue;
                        var vfB:int = -1;
                        try { if (oB2.vis != null && oB2.vis.currentFrame != null) { vfB = oB2.vis.currentFrame; } } catch (e:*) { }
                        // 门（v1.82）：门的开合=其瓦片 opac 淡出（Box.door→tiles[]）——
                        // 记录瓦片不透明度变化并重演
                        var dopB:Number = -1;
                        try
                        {
                           if (oB2.door != null && oB2.door > 0 && oB2.tiles != null && oB2.tiles.length > 0 && oB2.tiles[0] != null)
                           {
                              dopB = oB2.tiles[0].opac;
                           }
                        }
                        catch (e:*) { }
                        var sp2:Object = seenPos[oB2];
                        // 门诊断（v1.85）：首个门对象的状态（定位门不重演之谜）
                        try
                        {
                           if (recDoorCnt < 3 && oB2.door != null && oB2.door > 0)
                           {
                              recDoorCnt++;
                              log("[DIAG] recDoor: X=" + oB2.X + " vf=" + vfB + " dop=" + dopB
                                  + " seen=" + (sp2 != null ? 1 : 0));
                           }
                        }
                        catch (e:*) { }
                        if (sp2 == null)
                        {
                           seenPos[oB2] = { x: oB2.X, y: oB2.Y, vf: vfB, dop: dopB };
                        }
                        else if (sp2.x != oB2.X || sp2.y != oB2.Y || sp2.vf != vfB || sp2.dop != dopB)
                        {
                           var arr2:Array = [];
                           replayObjs[oB2] = arr2;
                           replayObjArr.push(oB2);
                           var vvB:Boolean = true;
                           try { if (oB2.vis != null) { vvB = oB2.vis.visible; } } catch (e:*) { }
                           for (var f2:int = 0; f2 < frameN; f2++) { arr2.push({ x: sp2.x, y: sp2.y, f: -1, s: "", wx: 0, wy: 0, twx: 0, twy: 0, vv: vvB, vf: sp2.vf, dop: sp2.dop }); }
                           arr2.push({ x: oB2.X, y: oB2.Y, f: -1, s: "", wx: 0, wy: 0, twx: 0, twy: 0, vv: vvB, vf: vfB, dop: dopB });
                           sp2.vf = vfB;
                           sp2.dop = dopB;
                        }
                     }
                     catch (e:*) { }
                  }
               }
            }
            catch (e:*) { }
            // 攻击体追踪器追加（v1.85）：按引用逐帧记录（绕开链扫描之谜）。
            // 子弹在链中=存活继续录；投掷箱 isThrow 期间持续录；死亡后停止
            // （数组止于死亡位置；死亡对象的 vis 已被摘除→回放中不可见）。
            try
            {
               for (var kA:Object in seenAtk)
               {
                  try
                  {
                     var aliveA:Boolean = false;
                     try { aliveA = kA.in_chain == true || kA["isThrow"] == true; } catch (e:*) { }
                     if (!aliveA)
                     {
                        // v1.90：死亡帧补录 vv=false——回放中攻击体飞到死亡点后
                        // 隐藏（否则重挂的 vis 在死亡位置冻结显示到回放结束）
                        try
                        {
                           var arrA2:Array = replayObjs[kA];
                           if (arrA2 != null)
                           {
                              arrA2.push({ x: kA.X, y: kA.Y, f: -1, s: "", wx: 0, wy: 0, twx: 0, twy: 0, vv: false, sto: 1, wrot: -99 });
                           }
                        }
                        catch (e:*) { }
                        // v1.91：自然爆炸（导火索到期/撞墙/被击落未走 stepProjHits）
                        // 的投掷物——回放死亡帧真实爆炸（isExpl 判定排除
                        // 飞出界/被清除）
                        try
                        {
                           if (kA.isExpl == true && projBoom[kA] == null)
                           {
                              // v1.93：普通 Bullet 带爆炸半径（野火核弹/榴弹——
                              // 时停前已在飞的爆炸死亡也记录，回放重演爆炸）
                              var qnA2:String = flash.utils.getQualifiedClassName(kA);
                              var isBoomB:Boolean = qnA2 == "fe.weapon::PhisBullet" || qnA2 == "fe.weapon::SmartBullet"
                                  || (qnA2 == "fe.weapon::Bullet" && kA.explRadius != null && kA.explRadius > 0);
                              if (isBoomB)
                              {
                                 projBoom[kA] = { f: cfgDuration - sandyLeft, x: kA.X, y: kA.Y };
                              }
                           }
                        }
                        catch (e:*) { }
                        delete seenAtk[kA];
                        continue;
                     }
                     var arrA:Array = replayObjs[kA];
                     if (arrA != null)
                     {
                        // v1.94：已引爆体补帧 vv=false——回放中爆炸发生后
                        // 精灵立即隐藏（不再"爆炸动画与飞行精灵重叠"的
                        // 异常引爆动画）
                        var vvA:Boolean = true;
                        try { vvA = !(kA.isExpl == true); } catch (e:*) { }
                        arrA.push({ x: kA.X, y: kA.Y, f: -1, s: "", wx: 0, wy: 0, twx: 0, twy: 0, vv: vvA, sto: 1, wrot: -99 });
                     }
                  }
                  catch (e:*) { }
               }
            }
            catch (e:*) { }
         }
         catch (e:*) { }
      }

      // ===== 回放中重演：敌人/物品/场景/攻击体按历史状态设置（位置+动画帧+生成音效）=====
      private function replayObjects():void
      {
         try
         {
            if (sndClass == null)
            {
               try { sndClass = ApplicationDomain.currentDomain.getDefinition("fe.Snd") as Class; } catch (e:*) { }
            }
            var idxR:int = replayIdx;
            for each (var oR:Object in replayObjArr)
            {
               try
               {
                  var arrR:Array = replayObjs[oR];
                  if (arrR == null || arrR.length == 0) continue;
                  var stR:Object = arrR[Math.min(idxR, arrR.length - 1)];
                  if (stR == null) continue;
                  // v1.90：setPos/setVisPos 仅 Unit 拥有——对密封类（Box/Bullet/
                  // PhisBullet 等）括号访问不存在成员会抛 ReferenceError，整段 try
                  // 被吞 → 非单位对象"完全不重演"且 rFix 从不打印的根因。
                  // try/catch 探测一次，后续全部用布尔判断。
                  var hasSP:Boolean = false;
                  try { hasSP = oR["setPos"] != null; } catch (e:*) { }
                  var hasSVP:Boolean = false;
                  try { hasSVP = oR["setVisPos"] != null; } catch (e:*) { }
                  // v1.91：被 clearFrozenBullets 清除的玩家攻击体（子弹/魔法/
                  // 枪械投掷物——回放由重执行生成新体）——录像原体隐藏，
                  // 否则与重执行体重叠成"鬼影"（投掷武器的手雷不重执行，
                  // 录像体保留显示）
                  if (!hasSP)
                  {
                     try
                     {
                        var isThrownB:Boolean = false;
                        try { isThrownB = oR.weap != null && oR.weap == world.gg["throwWeapon"]; } catch (e:*) { }
                        // v1.93：仅隐藏"时停中生成"的清除体（补帧 arrR[0].vv=false）
                        // ——其由回放重执行生成新体渲染；时停前已在飞的攻击体
                        // （含时停中爆炸死亡的核弹/导弹/榴弹）保持重演——
                        // 重执行不覆盖它们，录像体是唯一实体
                        var spawnedInS:Boolean = false;
                        try { spawnedInS = arrR.length > 0 && arrR[0].vv == false; } catch (e:*) { }
                        if (oR["owner"] == world.gg && oR.in_chain != true && !isThrownB && spawnedInS)
                        {
                           try { if (oR.vis != null) { oR.vis.visible = false; } } catch (e:*) { }
                           continue;
                        }
                     }
                     catch (e:*) { }
                  }
                  // 位置（setPos 更新碰撞边界——玩家子弹命中重演位置敌人正常结算）
                  if (hasSP) { oR.setPos(stR.x, stR.y); }
                  else { oR.X = stR.x; oR.Y = stR.y; }
                  // 重钉诊断（v1.89）：首个非单位对象——验证重钉是否应用
                  try
                  {
                     if (rFixCnt < 2 && !hasSP)
                     {
                        rFixCnt++;
                        log("[DIAG] rFix: cls=" + flash.utils.getQualifiedClassName(oR)
                            + " stX=" + stR.x + " stY=" + stR.y + " X=" + oR.X + " Y=" + oR.Y
                            + " visX=" + (oR.vis != null ? oR.vis.x : -1) + " visPar=" + (oR.vis != null && oR.vis.parent != null ? 1 : 0));
                     }
                  }
                  catch (e:*) { }
                  // 视觉同步（setPos 不更新 vis——否则敌人视觉固定在时停结束位置）
                  try
                  {
                     if (hasSVP) { oR.setVisPos(); }
                     else if (oR.vis != null) { oR.vis.x = stR.x; oR.vis.y = stR.y; }
                  }
                  catch (e:*) { }
                  // 攻击体/投掷物视觉重挂（v1.87）：时停中死亡或移除的对象
                  // （子弹命中玩家、手雷爆炸、箱子撞毁）其 vis 被 remVisual
                  // 从显示层摘除——回放重钉位置也**不可见**（手雷/导弹/天角兽
                  // 攻击/投掷箱"不重演"的根因）。按原图层重挂后逐帧重演飞行
                  // 轨迹；单位（有 setPos）不走此路径（其 vis 未摘除）。
                  try
                  {
                     // v1.110：排除粒子对象——时停中死亡/被清除的粒子其 vis
                     // 已在 endSandy 被 killPartsDeep 摘除，reatt 把它们挂回
                     // 显示树 = 回放中钉在死亡位置的鬼影（v1.109 日志实证：
                     // reatt fe.graph::Part 钉在爆炸点，R50-R150 全程可见）。
                     if (!hasSP && !(slowPartClass != null && oR is slowPartClass)
                         && oR.vis != null && oR.vis.parent == null && oR.sloy != null)
                     {
                        var gVis2:Object = world["grafon"];
                        if (gVis2 != null && gVis2.visObjs != null && gVis2.visObjs[oR.sloy] != null)
                        {
                           gVis2.visObjs[oR.sloy].addChild(oR.vis);
                           reattached[oR] = true;
                           // v1.105：重挂诊断——定位爆炸位置"火光"鬼影是否
                           // 来自重挂的死亡对象视觉
                           if (reattDiagCnt < 10)
                           {
                              reattDiagCnt++;
                              log("[DIAG] reatt: cls=" + flash.utils.getQualifiedClassName(oR)
                                  + " X=" + oR.X + " Y=" + oR.Y + " sloy=" + oR.sloy);
                           }
                        }
                     }
                  }
                  catch (e:*) { }
                  // 视觉可见性重演（v1.76）：按记录强制 vis.visible——尸鬼钻地
                  // （aiState=5 隐身）、炮塔预判死亡隐藏等，回放中 AI 状态可能与
                  // 记录不同步，可见性按记录恢复（钻地/爆炸消失如实重演）
                  try
                  {
                     if (oR.vis != null && stR.vv != null) { oR.vis.visible = stR.vv; }
                  }
                  catch (e:*) { }
                  // 场景对象视觉帧重演（v1.81）：门开关/机关等交互动画——
                  // 按记录 gotoAndStop（帧动画逐帧恢复；仅非单位对象）
                  try
                  {
                     if (!hasSP && oR.vis != null && stR.vf != null && stR.vf >= 0)
                     {
                        oR.vis.gotoAndStop(stR.vf);
                     }
                  }
                  catch (e:*) { }
                  // 门视觉重演（v1.86）：按记录 dop 变化调 setVisState——
                  // 门的可见形象是 Box 自己的 vis（open/close 帧），不是瓦片
                  // 淡出；dop 变化=开合事件（doorPrevDop 防重复调用重播音效）
                  try
                  {
                     if (!hasSP && stR.dop != null && stR.dop >= 0
                         && oR["setVisState"] != null && oR.door != null && oR.door > 0)
                     {
                        var prevDop:Number = doorPrevDop[oR] != null ? doorPrevDop[oR] : -1;
                        if (prevDop != stR.dop)
                        {
                           doorPrevDop[oR] = stR.dop;
                           oR.setVisState(stR.dop < 0.5 ? "open" : "close");
                        }
                     }
                  }
                  catch (e:*) { }
                  // 门瓦片不透明度重演（v1.82/1.84）：门开合=门框瓦片 opac 淡出——
                  // 按记录恢复 opac + t_visi + visi（渲染路径三处全设，确保可见）
                  try
                  {
                     if (!hasSP && stR.dop != null && stR.dop >= 0
                         && oR.tiles != null)
                     {
                        var tls:Array = oR.tiles;
                        for (var ti:int = 0; ti < tls.length; ti++)
                        {
                           try
                           {
                              if (tls[ti] != null)
                              {
                                 try { tls[ti].opac = stR.dop; } catch (e:*) { }
                                 try { tls[ti].t_visi = stR.dop; } catch (e:*) { }
                                 try { tls[ti].visi = stR.dop; } catch (e:*) { }
                              }
                           }
                           catch (e:*) { }
                        }
                     }
                  }
                  catch (e:*) { }
                  // 敌人武器位置恢复（回放中武器不 step——按历史位置放回，与重演身体贴合）
                  try
                  {
                     var cwE:* = oR["currentWeapon"];
                     if (cwE != null && stR.wx != null)
                     {
                        cwE.X = stR.wx;
                        cwE.Y = stR.wy;
                        if (cwE.vis != null) { cwE.vis.x = stR.wx; cwE.vis.y = stR.wy; }
                     }
                     // 投掷武器（手雷/投掷物）与魔法武器位置同样恢复（否则滞留在
                     // 时停结束位置——用户报告手雷不复位）
                     if (stR.twx != null && stR.twx != 0)
                     {
                        var twE:* = oR["throwWeapon"];
                        if (twE == null) { twE = oR["magicWeapon"]; }
                        if (twE != null)
                        {
                           twE.X = stR.twx;
                           twE.Y = stR.twy;
                           if (twE.vis != null) { twE.vis.x = stR.twx; twE.vis.y = stR.twy; }
                        }
                     }
                  }
                  catch (e:*) { }
                  // 动画驱动（核心修复）：根据历史位移设置 dx/dy/stay 并调 animate()——
                  // 游戏自身动画管线计算 animState（walk/run/jump/stay）并渲染。
                  // 怪物的 anims（BlitAnim）是 internal 读不到，驱动公开的 animate()
                  // 是唯一路径（读 vis.osn.body 帧对怪物永远 -1，故不依赖帧记录）
                  try
                  {
                     if (hasSP && oR["animate"] != null)
                     {
                        var nxtR2:Object = arrR[Math.min(idxR + 1, arrR.length - 1)];
                        var mvx:Number = (nxtR2.x - stR.x) * cfgReplaySpeed;
                        var mvy:Number = (nxtR2.y - stR.y) * cfgReplaySpeed;
                        // 动画驱动（v1.71 定稿）：敌对单位完整 step + 位置重钉——
                        // enemyAct=1 让 AI 状态机运行（aiState/aiTCh 推进，动画
                        // 状态随 AI 自然变化——走路/跑步/待机全部正常）但**不寻敌
                        // 不攻击**（findCel 需 >1、攻击需 >=3）；step 内 run() 会
                        // 移动单位，步后重钉到记录位置（视觉按记录重演，动画按
                        // AI 状态自然播放）。NPC 保留量化驱动（其 control 无
                        // enemyAct 门）。
                        var qnR2:String = flash.utils.getQualifiedClassName(oR);
                        var isHostile:Boolean = qnR2.indexOf("NPC") < 0 && oR["currentWeapon"] != null;
                        // v1.84：被念力投掷过的单位并入敌对完整 step——回放中其
                        // damWall 已被时停清零（endReplay 才恢复），step 撞墙不会
                        // 结算伤害；位置步后重钉，飞行/坠落动画由单位自身物理
                        // 状态自然驱动（原"只重钉不 step"导致动画僵死）
                        if (isHostile)
                        {
                           try
                           {
                              // v1.81：攻击改由时停记录的开火事件复现（方向/时机
                              // 忠实重演）——时停中子弹刚生成就命中无敌玩家、活不到
                              // 录像帧（rStart 诊断 atk 恒 0），改在武器层面记录
                              // t_attack 上升沿（含瞄准点），回放逐事件复现。
                              var savedEA:Number = world["enemyAct"];
                              world["enemyAct"] = 2;
                              // v1.81：enemyAct=2——AI 寻敌/追击（走路跑步动画
                              // 自然）但攻击需 >=3 **不会实时出手**（回放期间玩家
                              // 不受攻击）；攻击改由时停记录的开火事件复现
                              // （见下方——方向/时机忠实重演，替代 v1.76 的
                              // "AI 重新开火"——那是瞄准回放中的玩家而非重演）。
                              // v1.78 速率修正：敌对单位每显示帧 step **1** 次——
                              // 时停中世界每 5 显示帧才步 1 次，回放每显示帧消耗
                              // 5 个历史帧 = 恰好 1 个世界步（v1.76 误用 5 次/帧，
                              // 攻击节奏与子弹飞行被错误加速 5 倍——玩家子弹一直
                              // 是 1 次/帧且速度正确，可作对照）。
                              // v1.79 瞄准按记录方向：cel 沿本帧记录的武器角延伸
                              // （替代 v1.77 的"钉到当前玩家"——玩家 5 倍瞬移使
                              // 炮塔头每帧猛甩）。
                              try
                              {
                                 try
                                 {
                                    if (stR.wrot != null && stR.wrot != -99)
                                    {
                                       oR.celX = oR.X + Math.cos(stR.wrot) * 300;
                                       oR.celY = oR.Y + Math.sin(stR.wrot) * 300;
                                    }
                                    oR["celUnit"] = world.gg;
                                 }
                                 catch (e:*) { }
                                 // v1.82/v1.85：封锁实时开火——部分单位（天角兽等）的
                                 // 攻击条件不含 enemyAct>=3 门（只有 findCel 需
                                 // >1），enemyAct=2 下仍会开火 → 回放出现时停中
                                 // 没有的额外攻击。预步把全部武器槽 t_attack 置 1
                                 // （attack() 初始化要求 t_attack<=0 → 该步无法
                                 // 开火）；prep 武器同时清 t_prep。**逐槽 try/catch**：
                                 // 天角兽 psyWeapon 是 internal——bracket 访问抛异常
                                 // 会让整条数组构造失败、守卫全部失效（v1.84 闪电/
                                 // 精神攻击额外攻击仍存在的根源）。
                                 try
                                 {
                                    var wSlots:Array = [];
                                    try { wSlots.push(oR["currentWeapon"]); } catch (e:*) { }
                                    try { wSlots.push(oR["throwWeapon"]); } catch (e:*) { }
                                    try { wSlots.push(oR["magicWeapon"]); } catch (e:*) { }
                                    try { wSlots.push(oR["psyWeapon"]); } catch (e:*) { }
                                    for each (var wG:Object in wSlots)
                                    {
                                       try
                                       {
                                          if (wG != null && wG.t_attack != null)
                                          {
                                             wG.t_attack = 1;
                                             try { if (wG.prep != null && wG.prep > 0 && wG.t_prep != null) { wG.t_prep = 0; } } catch (e:*) { }
                                          }
                                       }
                                       catch (e:*) { }
                                    }
                                 }
                                 catch (e:*) { }
                                 // v1.133：回放中已死的敌人（sost>=3，postDie 除外）
                                 // 不再重跑 AI——step() 对尸体不门控（仅 disabled/
                                 // trigDis），继续跑 control/actions 会让尸体"开火"
                                 // （用户实测：回放期间死亡敌人开枪）。postDie 单位
                                 // 是本体"死后仍行动"设定（如某些不死怪），保留 step。
                                 var cpdSost:int = -1;
                                 try { cpdSost = int(oR.sost); } catch (e:*) { }
                                 var cpdPost:Boolean = false;
                                 try { cpdPost = Boolean(oR.postDie); } catch (e:*) { }
                                 if (cpdSost < 0 || cpdSost < 3 || cpdPost)
                                 {
                                    oR.step();
                                 }
                              }
                              catch (e:*) { }
                              world["enemyAct"] = savedEA;
                              // 重钉位置/视觉（step 内 run() 移动了单位）
                              try { oR.setPos(stR.x, stR.y); } catch (e:*) { }
                              try
                              {
                                 if (hasSVP) { oR.setVisPos(); }
                                 else if (oR.vis != null) { oR.vis.x = stR.x; oR.vis.y = stR.y; }
                              }
                              catch (e:*) { }
                              // 武器位置重钉（step 内武器 step 会移动武器）
                              try
                              {
                                 var cwE2:* = oR["currentWeapon"];
                                 if (cwE2 != null && stR.wx != null)
                                 {
                                    cwE2.X = stR.wx;
                                    cwE2.Y = stR.wy;
                                    if (cwE2.vis != null) { cwE2.vis.x = stR.wx; cwE2.vis.y = stR.wy; }
                                 }
                              }
                              catch (e:*) { }
                              // 朝向与武器转动如实重演（v1.79）：AI 因位置重钉
                              // 不转向（storona 冻结在时停结束方向）；按记录恢复
                              // storona 与武器 rot（武器视觉随 rot 重摆；炮塔头等
                              // 嵌套视觉经 animate() 重摆——炮塔 animate 无逐帧
                              // 动画推进，多调一次无副作用）
                              try
                              {
                                 if (stR.sto != null) { oR.storona = stR.sto; }
                                 try
                                 {
                                    if (hasSVP) { oR.setVisPos(); }
                                    else if (oR.vis != null) { oR.vis.scaleX = stR.sto != null ? stR.sto : 1; }
                                 }
                                 catch (e:*) { }
                                 var cwE3:* = oR["currentWeapon"];
                                 if (cwE3 != null && stR.wrot != null && stR.wrot != -99)
                                 {
                                    cwE3.rot = stR.wrot;
                                    try { if (cwE3.vis != null) { cwE3.vis.rotation = stR.wrot * 180 / Math.PI; } } catch (e:*) { }
                                 }
                                 if (qnR2.indexOf("Turret") >= 0)
                                 {
                                    try { oR.animate(); } catch (e:*) { }
                                 }
                              }
                              catch (e:*) { }
                              // v1.132：回放敌人动画防"偶发僵死" + 防怪物残留隐身/不可抓：
                              // · 位置重钉使 AI 常判"已到目标范围"→dx≈0→animate() 只走
                              //   stay（僵尸/蝎子等 Blit 怪原地定住=僵死）。按记录位移
                              //   折算 dx/dy 补喂 + 补一次 animate()，动画按真实移动档位
                              //   （run/trot/walk）重现。
                              // · 回放 AI 分歧可能把怪物推入 burrow/隐身（aiState=5 →
                              //   vis.visible=false + invis=true + levitPoss=false），
                              //   按记录最后状态强压回去——回放结束也不残留
                              //   "隐身/无法念力抓取"（用户实测：隐身的肉食灵/辐射蝎）。
                              try
                              {
                                 try { oR.dx = (nxtR2.x - stR.x) * cfgReplaySpeed; } catch (e:*) { }
                                 try { oR.dy = (nxtR2.y - stR.y) * cfgReplaySpeed; } catch (e:*) { }
                                 if (oR.vis != null && stR.vv != null) { try { oR.vis.visible = Boolean(stR.vv); } catch (e:*) { } }
                                 if (stR.iv != null) { try { oR.invis = Boolean(stR.iv); } catch (e:*) { } }
                                 if (stR.lv != null) { try { oR.levitPoss = Boolean(stR.lv); } catch (e:*) { } }
                                 // v1.134：敌人动画忠实重演走两路——
                                 // (a) MC 小马类（录到 osn 标签/身体帧）：按帧快照
                                 //     osn.gotoAndStop(bl)+body.gotoAndStop(bf)——含攻击/
                                 //     瞄准/翻滚等任意姿态的中间帧，与玩家回放(v1.130)
                                 //     同款，不受 AI 分歧影响（"僵硬"来源于 dx 喂入
                                 //     只覆盖移动档、站桩攻击姿态全被压成 stay）。
                                 // (b) Blit 怪（无 osn.body，f<0）：继续 dx 喂入+
                                 //     补 animate()，按记录移动档位重现（贴图怪不可
                                 //     逐帧快照——anims/BlitAnim internal）。
                                 // (c) 尸体（sost>=3 非 postDie）：不快照不喂入——
                                 //     保持定格在游戏最后一步留下的死亡姿态（v1.133
                                 //     起尸体不再 step；若录像死亡帧早于回放死亡，快照
                                 //     会把尸体打回存活姿态=穿帮）。
                                 var alvCM:Boolean = true;
                                 try { alvCM = int(oR.sost) < 3 || Boolean(oR.postDie); } catch (e:*) { }
                                 if (alvCM)
                                 {
                                    var frM:int = -1;
                                    try { frM = int(stR.f); } catch (e:*) { }
                                    var blM:String = stR.bl != null ? String(stR.bl) : "";
                                    if (frM > 0 || blM.length > 0)
                                    {
                                       try
                                       {
                                          var vgM:* = oR.vis;
                                          if (vgM != null && vgM["osn"] != null)
                                          {
                                             var osnM:* = vgM["osn"];
                                             if (blM.length > 0 && osnM.currentFrameLabel != blM)
                                             {
                                                try { osnM.gotoAndStop(blM); } catch (e:*) { }
                                             }
                                             if (osnM["body"] != null && frM > 0)
                                             {
                                                try { osnM["body"].gotoAndStop(frM); } catch (e:*) { }
                                             }
                                             var anM:String = stR.an != null ? String(stR.an) : "";
                                             if (anM.length > 0) { try { oR.animState = anM; } catch (e:*) { } }
                                          }
                                       }
                                       catch (e:*) { }
                                    }
                                    else
                                    {
                                       try { oR.animate(); } catch (e:*) { }
                                    }
                                 }
                              }
                              catch (e:*) { }
                              // v1.85：攻击体复现已移除——攻击体由追踪器（seenAtk）
                              // 按引用逐帧录像并在回放中重钉（真实轨迹/方向/时机）；
                              // 事件复现会造成双发且方向不忠实。
                           }
                           catch (e:*) { }
                        }
                        else
                        {
                           // NPC/无武器单位：量化驱动（按记录位移选择动画档位）
                           var spd:Number = Math.sqrt(mvx * mvx + mvy * mvy);
                           var newCat:int = spd < 1.5 ? 1 : (spd < 8 ? 2 : 3);
                           var cat:int = replayAnimCat[oR] != null ? replayAnimCat[oR] : 0;
                           if (cat != 0)
                           {
                              if (cat == 3 && newCat == 2 && spd > 5) { newCat = 3; }
                              else if (cat == 2 && newCat == 1 && spd > 2.5) { newCat = 2; }
                              else if (cat == 1 && newCat == 2 && spd < 3) { newCat = 1; }
                              else if (cat == 2 && newCat == 3 && spd < 10) { newCat = 2; }
                           }
                           replayAnimCat[oR] = newCat;
                           oR.stay = true;
                           oR.dx = newCat == 1 ? 0 : (newCat == 2 ? (mvx >= 0 ? 4 : -4) : (mvx >= 0 ? 12 : -12));
                           oR.dy = 0;
                           oR.animate();
                        }
                     }
                  }
                  catch (e:*) { }
                  // v1.141: Blit enemies (including raiders and ghouls) have no osn.body.
                  // Reapply the recorded body after all AI/animate calls; position plateaus
                  // and new AI decisions must not replace the recorded pose with "stay".
                  // Preserve the existing real-death rule: never paint a living pose over a corpse.
                  if (hasSP && stR.bp != null)
                  {
                     try
                     {
                        if (int(oR.sost) < 3 || Boolean(oR.postDie)) replayBlit.apply(oR, stR.bp);
                     }
                     catch (e:*) { }
                  }
                  // 生成音效（精确帧：攻击体生成事件在对应历史帧重播）
                  if (idxR < arrR.length)
                  {
                     var stS:Object = arrR[idxR];
                     if (stS != null && stS.s != null && stS.s != "" && sndClass != null)
                     {
                        try { sndClass["ps"](stS.s, stS.x, stS.y); } catch (e:*) { }
                     }
                  }
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
      }

      // ===== 回放中玩家攻击体手动 step（世界冻结 onPause=true 时攻击体不自动 step）=====
      private function stepPlayerBullets():void
      {
         try
         {
            var locB:Object = world.loc;
            if (locB == null) return;
            var oB:Object = locB.firstObj;
            var gB:int = 0;
            while (oB != null)
            {
               var nxB:Object = oB.nobj;
               try
               {
                  if (oB["owner"] == world.gg && replayObjs[oB] == null
                      && flash.utils.getQualifiedClassName(oB).indexOf("fe.weapon::") == 0)
                  {
                     // v1.97：重执行孪生体的录像原体已爆炸（vv=false）→ 不再步进
                     // （其导火索若在此步耗尽会自然爆炸，与 boom 重叠成"两次
                     // 爆炸动画"；位置本就由 reExecPin 循环按录像重钉）
                     var twinB:Object = reExecPin[oB];
                     if (twinB != null)
                     {
                        var arrB3:Array = replayObjs[twinB];
                        if (arrB3 != null)
                        {
                           var stB3:Object = arrB3[Math.min(replayIdx, arrB3.length - 1)];
                           if (stB3 != null && stB3.vv == false) { oB = nxB; continue; }
                        }
                     }
                     // v1.98：回放重执行的爆炸体（回放中新生成、不在录像中）
                     // 一律惰性化——爆炸（视觉+伤害）全由 boom 按录像帧重演，
                     // 孪生体只负责飞行轨迹视觉。v1.97 双倍伤害根因：回放重演
                     // 子弹命中**未配对**孪生体触发真实爆炸（日志 replayHit
                     // idx=80 与 boom f=74 同轮回放双爆，dmgExpl=800 双份）+
                     // 配对孪生体导火索耗尽/命中与 boom 的竞态。isExpl=true
                     // 使游戏 explosion() 直接早退（Bullet.as:668 守卫），且
                     // projs 可击落表按 isExpl!=true 过滤——重演子弹不再引爆
                     // 孪生体；endReplay 对仍存活在飞的孪生体恢复爆炸能力
                     // （录像原体时停末仍在飞的场景，回放结束后自然续飞爆炸）。
                     // 时停前在飞攻击体（preExistB）已在录像中，不入此分支。
                     try
                     {
                        if (oB.explRadius != null && oB.explRadius > 0 && oB.isExpl != true && twinSavExpl[oB] == null)
                        {
                           twinSavExpl[oB] = (oB.damageExpl != null ? oB.damageExpl : 0);
                           oB.isExpl = true;
                           oB.damageExpl = 0;
                           try
                           {
                              if (twinDiagCnt < 8)
                              {
                                 twinDiagCnt++;
                                 log("[DIAG] twinInert: cls=" + flash.utils.getQualifiedClassName(oB)
                                     + " X=" + oB.X + " Y=" + oB.Y + " idx=" + replayIdx);
                              }
                           }
                           catch (e:*) { }
                        }
                     }
                     catch (e:*) { }
                     oB.step();
                  }
               }
               catch (e:*) { }
               oB = nxB;
               if (++gB > 20000) break;
            }
         }
         catch (e:*) { }
      }

      // ===== 回放中未被录制的敌人攻击体手动 step（v1.75/1.78）=====
      // 实体型攻击（如天角兽闪电等）若不在录像中（replayObjs 未覆盖——时停中
      // 子弹刚生成就命中无敌玩家、活不到录像帧），回放中会静止在时停结束位置；
      // 回放中敌人重新出手（enemyAct=3）生成的新攻击体同样经此 step。
      // 速率（v1.78 修正）：每显示帧 step **1** 次——时停中攻击体随世界节流
      // 每 5 显示帧步 1 次，回放每显示帧消耗 5 个历史帧 = 恰好 1 个世界步
      // （与玩家攻击体 stepPlayerBullets 同速率；v1.76 误用 5 次/帧，敌人
      // 子弹飞行被错误加速 5 倍）。已录制的攻击体由 replayObjects 按记录重钉。
      private function stepUnrecordedAtk():void
      {
         try
         {
            var locB:Object = world.loc;
            if (locB == null) return;
            var oB:Object = locB.firstObj;
            var gB:int = 0;
            while (oB != null)
            {
               var nxB:Object = oB.nobj;
               try
               {
                  if (oB != world.gg && replayObjs[oB] == null)
                  {
                     // v1.95：玩家方攻击体（回放重执行的子弹/魔法/投掷物）由
                     // stepPlayerBullets 负责步进——此处再步一次=每显示帧
                     // 双步（2 世界步/帧），子弹相对世界快 2 倍：扫掠段错位
                     // 错过交叉点、后发子弹在更远处才命中（"回放引爆位置
                     // 晚于时停"的根因）
                     var isOwnB:Boolean = false;
                     try { isOwnB = oB["owner"] == world.gg; } catch (e:*) { }
                     if (isOwnB) { oB = nxB; continue; }
                     var qnB:String = flash.utils.getQualifiedClassName(oB);
                     // 被投掷的箱子不 step（v1.84：保留飞行惯性——时停结束时的
                     // 速度延续到回放结束后；step 会被 levit 阻尼逐帧消耗 dx）
                     var isThrB:Boolean = false;
                     try { isThrB = oB["isThrow"] == true; } catch (e:*) { }
                     if ((qnB.indexOf("fe.weapon::") == 0 || qnB.indexOf("fe.unit::") == 0 || qnB.indexOf("fe.loc::") == 0) && !isThrB)
                     {
                        if (oB["step"] != null) { oB.step(); }
                     }
                  }
               }
               catch (e:*) { }
               oB = nxB;
               if (++gB > 20000) break;
            }
         }
         catch (e:*) { }
      }

      // ===== 读取对象动画帧（共用视觉体系 vis.osn.body，容错）=====
      private function animFrameOf(o:Object):int
      {
         try
         {
            if (o.vis != null && o.vis.osn != null && o.vis.osn.body != null) { return o.vis.osn.body.currentFrame; }
         }
         catch (e:*) { }
         return -1;
      }
      // v1.134：敌人 osn 当前标签（MC 小马类可录；Blit 怪无 osn.body → "")
      private function osnLabelOf(o:Object):String
      {
         try
         {
            if (o.vis != null && o.vis["osn"] != null)
            {
               var lbl:String = String(o.vis["osn"].currentFrameLabel);
               return lbl != null ? lbl : "";
            }
         }
         catch (e:*) { }
         return "";
      }

      // ===== 投掷物可击落（v1.83）：手雷（PhisBullet）/导弹（SmartBullet）/
      // 榴弹（PhisBullet）受击至血量归零直接爆炸。仅限有爆炸半径的这两类
      // ——普通子弹（含天角兽闪电）不参与。护甲 cfgProjArmor 为预留接口
      // （伤害先减护甲）。时停中爆炸仅视觉（伤害清零——真实伤害由回放中
      // 重演的子弹命中重演的投掷物结算，与攻击结算架构一致）。
      // v1.127：击落技能已迁移 mods/MoreSkills&Weapons（MSWProjHits.as，
      // SharedObject 配置）；Sandevistan 侧停用（cfgProjHits 恒 false、
      // config 键失效、面板行移除）。本函数与下方 stepProjHits 保留作
      // 源码备份（完整备份见 state/migration-backup-v1.126/）。
      // ===== 回放重演（斯安维斯坦回放系统核心，与击落开关无关）=====
      // v1.127：从 stepProjHits 抽出、脱离 cfgProjHits 门控——时停中
      // 自然爆炸（导火索到期/撞墙）由 slowStepWorld 记录进 projBoom，
      // 回放必须照常重演，不能因击落技能停用而失效。
      private function replayProjBoom():void
      {
         if (!replaying) return;
         // v1.91：时停中引爆的投掷物（射击击落/自然到期）在回放对应帧
         // 真实爆炸（damageExpl 从武器恢复——时停中玩家攻击体伤害被清零）
         try
         {
            for (var kB:Object in projBoom)
               {
                  try
                  {
                     var bm:Object = projBoom[kB];
                     if (bm == null) { delete projBoom[kB]; continue; }
                     if (replayIdx >= bm.f)
                     {
                        // v1.96：全部引爆统一走 boom 重演（日志证明位置与时停
                        // 完全一致）——不再跳过重执行体（v1.93 跳过导致
                        // "回放未击中/晚于时停引爆"）；重执行孪生体由
                        // reExecPin 循环在其录像死亡帧终止（隐藏+禁爆），
                        // 不会与 boom 重叠成两份
                        try
                        {
                           if (kB.damageExpl != null && kB.damageExpl <= 0 && kB.weap != null && kB.weap.damageExpl != null)
                           {
                              kB.damageExpl = kB.weap.damageExpl;
                           }
                           // v1.99：爆炸位置按记录精确重演——录像死亡帧比爆炸帧
                           // 晚一步（爆炸后身体再移一步才被移除），回放重钉
                           // 滞后一步 → 爆炸偏移 30-60px。projBoom 的 x/y 为
                           // 时停爆炸瞬间位置。
                           try { kB.X = bm.x; kB.Y = bm.y; } catch (e:*) { }
                           try { if (kB.vis != null) { kB.vis.x = bm.x; kB.vis.y = bm.y; } } catch (e:*) { }
                           kB.isExpl = false;
                           kB.explosion();
                           // v1.101：爆炸后**移除**录像体——集束武器（explKol>1，
                           // 如野火核弹）explosion() 会排定 expl_t 后续连爆，而
                           // expl_t 是 internal（Bullet.as:131），模组子域无法赋值
                           // （v1.99 的 kB.expl_t=0 静默失败）——回放世界冻结期间
                           // 不步进，回放结束后世界恢复才逐帧 explRun 在爆炸位置
                           // 喷出剩余连爆（"两个冲击波"+"时停爆炸位置鬼影"的
                           // 同根因）。remObj 出链后连爆无从触发，只爆一次。
                           // 时停中录像体爆炸后下一世界步即被移除（从无连爆），
                           // 移除即与时停行为一致。
                           try { world.loc.remObj(kB); } catch (e:*) { }
                           // v1.92：引爆即杀（回放结束后不再残留续飞）
                           try { kB.liv = 0; } catch (e:*) { }
                           // v1.105：boom 粒子清单诊断——爆炸后立即清点爆炸
                           // 半径内的粒子（视觉类/类型/寿命），定位"火光"
                           // 鬼影的具体粒子
                           try
                           {
                              var PartC4:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class;
                              if (PartC4 != null)
                              {
                                 var oP4:Object = world.loc.firstObj;
                                 var nP4:int = 0;
                                 var gP4:int = 0;
                                 while (oP4 != null && nP4 < 8)
                                 {
                                    try
                                    {
                                       if (oP4 is PartC4)
                                       {
                                          var ddx4:Number = oP4.X - kB.X;
                                          var ddy4:Number = oP4.Y - kB.Y;
                                          if (ddx4 * ddx4 + ddy4 * ddy4 <= 600 * 600)
                                          {
                                             nP4++;
                                             log("[DIAG] boomPart: vis=" + flash.utils.getQualifiedClassName(oP4.vis)
                                                 + " blit=" + (oP4.blitData != null ? 1 : 0)
                                                 + " anim=" + (oP4.isAnim != null ? oP4.isAnim : -1)
                                                 + " liv=" + (oP4.liv != null ? oP4.liv : -1)
                                                 + " X=" + oP4.X + " Y=" + oP4.Y);
                                          }
                                       }
                                    }
                                    catch (e:*) { }
                                    oP4 = oP4.nobj;
                                    if (++gP4 > 20000) break;
                                 }
                              }
                           }
                           catch (e:*) { }
                           // v1.94：隐藏残体精灵（游戏爆炸流程同款——防爆炸
                           // 动画与飞行精灵重叠的"异常引爆动画"）
                           try { if (kB.vis != null) { kB.vis.visible = false; } } catch (e:*) { }
                           if (boomDiagCnt < 30)
                           {
                              boomDiagCnt++;
                              log("[DIAG] boom: cls=" + flash.utils.getQualifiedClassName(kB)
                                  + " f=" + bm.f + " X=" + kB.X + " Y=" + kB.Y
                                  + " dmgExpl=" + (kB.damageExpl != null ? kB.damageExpl : -1)
                                  + " explKol=" + (kB.explKol != null ? kB.explKol : -1)
                                  + " replIdx=" + replayIdx);
                           }
                           // v1.99：未配对孪生体就近终止——配对失败（开火帧与注册帧
                           // ±1 失配）的惰性化孪生体未被 reExecPin 钉住/终止，回放中
                           // 飞过爆炸点继续飞行（"导弹仍继续飞行"），endReplay 恢复
                           // 爆炸能力后回放结束再爆（"两次爆炸动画"）。boom 触发时
                           // 对爆炸位置附近的惰性化孪生体一并终止（其录像原体爆炸
                           // 已由 boom 重演，孪生体无需续飞）。先收集后终止——
                           // 迭代中删除字典键不安全。
                           try
                           {
                              var killT:Array = [];
                              for (var kTW:Object in twinSavExpl)
                              {
                                 try
                                 {
                                    if (kTW == null || kTW.in_chain != true) continue;
                                    var ddxT:Number = kTW.X - bm.x;
                                    var ddyT:Number = kTW.Y - bm.y;
                                    if (ddxT * ddxT + ddyT * ddyT <= 200 * 200) { killT.push(kTW); }
                                 }
                                 catch (e:*) { }
                              }
                              for each (var vK:Object in killT)
                              {
                                 try { vK.isExpl = true; } catch (e:*) { }
                                 try { vK.liv = 0; } catch (e:*) { }
                                 try { if (vK.vis != null) { vK.vis.visible = false; } } catch (e:*) { }
                                 try { delete reExecPin[vK]; } catch (e:*) { }
                                 try { delete twinSavExpl[vK]; } catch (e:*) { }
                                 try
                                 {
                                    if (twinDiagCnt < 12)
                                    {
                                       twinDiagCnt++;
                                       log("[DIAG] twinKill: cls=" + flash.utils.getQualifiedClassName(vK)
                                           + " X=" + vK.X + " Y=" + vK.Y + " boomF=" + bm.f
                                           + " isExpl=" + (vK.isExpl != null ? vK.isExpl : -1)
                                           + " liv=" + (vK.liv != null ? vK.liv : -1)
                                           + " babah=" + (vK.babah != null ? vK.babah : -1));
                                    }
                                 }
                                 catch (e:*) { }
                              }
                           }
                           catch (e:*) { }
                        }
                        catch (e:*) { }
                        delete projBoom[kB];
                     }
                  }
                  catch (e:*) { }
               }
            }
            catch (e:*) { }
      }
      // ===== 手雷击落判定（v1.83 原 stepProjHits 主体；已迁移 MSW，源码备份）=====
      private function stepProjHits(locP:Object, isSandy:Boolean):void
      {
         // v1.127：回放重演已在 replayProjBoom() 独立处理（见上）
         replayProjBoom();
         if (!cfgProjHits) return;
         try
         {
            var projs:Array = [];
            var objs:Array = [];
            // 投掷物列表（v1.85）：优先从攻击体追踪器取（按引用——
            // 绕开链扫描之谜；链扫描作为补充兜底）
            for (var kP2:Object in seenAtk)
            {
               try
               {
                  var qnP2:String = flash.utils.getQualifiedClassName(kP2);
                  // v1.92：可击落投掷物扩到普通 Bullet——榴弹发射器/野火核弹
                  // 发射器 tip=3 走 Weapon→Bullet（非 PhisBullet/SmartBullet），
                  // 带爆炸半径；天角兽闪电 expl=0 仍排除
                  if ((qnP2 == "fe.weapon::PhisBullet" || qnP2 == "fe.weapon::SmartBullet" || qnP2 == "fe.weapon::Bullet")
                      && kP2.explRadius != null && kP2.explRadius > 0 && kP2.isExpl != true)
                  {
                     projs.push(kP2);
                  }
               }
               catch (e:*) { }
            }
            var o:Object = locP.firstObj;
            var g:int = 0;
            while (o != null)
            {
               try
               {
                  var qn:String = flash.utils.getQualifiedClassName(o);
                  if (qn == "fe.weapon::PhisBullet" || qn == "fe.weapon::SmartBullet" || qn == "fe.weapon::Bullet")
                  {
                     // v1.92：普通 Bullet 带爆炸半径（榴弹/野火核弹/等离子等
                     // 爆炸弹）纳入可击落；无爆炸半径（枪弹/天角兽闪电）
                     // 照常入 objs
                     var isProjQ:Boolean = false;
                     try { isProjQ = o.explRadius != null && o.explRadius > 0 && o.isExpl != true; } catch (e:*) { }
                     if (isProjQ)
                     {
                        if (projs.indexOf(o) < 0) { projs.push(o); }
                     }
                     else
                     {
                        // v1.90：近战攻击体（vel=0 静止在手上）不参与击落判定——
                        // 否则手雷飞过近战范围会被"拳击"引爆并把攻击体 remObj
                        // 出链（破坏近战）
                        try { if (o.vel != null && o.vel < 1) { o = o.nobj; continue; } } catch (e:*) { }
                        objs.push(o);
                     }
                  }
                  else if (qn.indexOf("fe.weapon::") == 0)
                  {
                     // v1.90：近战攻击体（vel=0 静止在手上）不参与击落判定——
                     // 否则手雷飞过近战范围会被"拳击"引爆并把攻击体 remObj
                     // 出链（破坏近战）
                     try { if (o.vel != null && o.vel < 1) { o = o.nobj; continue; } } catch (e:*) { }
                     objs.push(o);
                  }
               }
               catch (e:*) { }
               o = o.nobj;
               if (++g > 20000) break;
            }
            // 清理已消失投掷物的血量记录
            for (var kH:Object in projHp)
            {
               try { if (projs.indexOf(kH) < 0) { delete projHp[kH]; } } catch (e:*) { }
            }
            // v1.117：常规玩法击落诊断——定位"敌人手雷/导弹无法击落"
            // （projs 表是否收录 + 命中是否发生；diaglog=1 时每 60 帧一条）
            if (cfgDiagLog && !isSandy && !replaying && ++projDiagTick % 60 == 0)
            {
               var pds:String = "";
               for (var pdi:int = 0; pdi < projs.length && pdi < 3; pdi++)
               {
                  try { pds += (pds != "" ? "," : "") + flash.utils.getQualifiedClassName(projs[pdi]) + "@" + Math.round(projs[pdi].X) + "," + Math.round(projs[pdi].Y); } catch (e:*) { }
               }
               log("[DIAG] projScan: projs=" + projs.length + " objs=" + objs.length + " [" + pds + "]");
            }
            if (projs.length == 0 || objs.length == 0) return;
            for each (var p:Object in projs)
            {
               for each (var b:Object in objs)
               {
                  try
                  {
                     if (b == p) continue;   // v1.92：自测防护——爆弹类子弹同时
                                             // 出现在 projs/objs 两表
                     // v1.91：同源不再一刀切跳过（"射击自己的手雷不引爆"根因）
                     // ——改为出生护手：同源且投掷物距其 owner <200px（刚出手/
                     // 枪口附近）不判定，防止投掷+连射在自己面前引爆；飞出后
                     // 常规游戏/时停/回放均可射击自己的手雷导弹（回放重执行
                     // 的子弹与重演的手雷同源，必须放行）
                     if (b.owner == p.owner)
                     {
                        try
                        {
                           var pown:Object = p.owner;
                           if (pown != null)
                           {
                              var odx:Number = p.X - pown.X;
                              var ody:Number = p.Y - pown.Y;
                              if (odx * odx + ody * ody < 200 * 200) continue;
                           }
                        }
                        catch (e:*) { }
                     }
                     // v1.92 相对速度扫掠碰撞：子弹与投掷物本步**同时**移动
                     // （各一世界步）——高速相向时旧的"子弹段 vs 投掷物末端"
                     // 会漏判（交叉错过）；投掷物比子弹快时单段测永远追不上
                     // （"弹药飞行状态提前/射击延后"的真因——玩家子弹与导弹
                     // 同速，单测末端差一整个扫掠段）。物理最近点：
                     // R(t)=O+t·RV（O=起步点相对差，RV=相对速度），
                     // t∈[0,1] 钳制，|R(t*)|≤28 即命中（端点自然覆盖）。
                     var sx:Number = b.X - (b.dx != null ? b.dx : 0);
                     var sy:Number = b.Y - (b.dy != null ? b.dy : 0);
                     var pdx:Number = p.dx != null ? p.dx : 0;
                     var pdy:Number = p.dy != null ? p.dy : 0;
                     var hitOK:Boolean = false;
                     var ddx0:Number = sx - (p.X - pdx);
                     var ddy0:Number = sy - (p.Y - pdy);
                     if (ddx0 * ddx0 + ddy0 * ddy0 <= 28 * 28) { hitOK = true; }
                     if (!hitOK)
                     {
                        var rvx:Number = (b.dx != null ? b.dx : 0) - pdx;
                        var rvy:Number = (b.dy != null ? b.dy : 0) - pdy;
                        var rv2:Number = rvx * rvx + rvy * rvy;
                        if (rv2 > 0.0001)
                        {
                           var tS:Number = -(ddx0 * rvx + ddy0 * rvy) / rv2;
                           if (tS < 0) { tS = 0; }
                           if (tS > 1) { tS = 1; }
                           var cxR:Number = ddx0 + rvx * tS;
                           var cyR:Number = ddy0 + rvy * tS;
                           if (cxR * cxR + cyR * cyR <= 28 * 28) { hitOK = true; }
                        }
                     }
                     if (!hitOK) continue;
                     // v1.117：常规玩法命中诊断（定位"无法击落"）
                     if (cfgDiagLog && !isSandy && !replaying && projHitDiagCnt < 12)
                     {
                        projHitDiagCnt++;
                        log("[DIAG] projHit: cls=" + flash.utils.getQualifiedClassName(p)
                            + " bullet=" + flash.utils.getQualifiedClassName(b)
                            + " dmg=" + (b.damage != null ? b.damage : -1)
                            + " P=" + Math.round(p.X) + "," + Math.round(p.Y));
                     }
                     var dmg:Number = b.damage != null ? b.damage : 0;
                     // 时停中玩家子弹伤害被清零——用捕获的原始伤害
                     if (dmg <= 0 && b.owner == world.gg && origDam[b] != null) { dmg = origDam[b]; }
                     if (dmg <= 0) continue;
                     // v1.114：按发射武器 id 的护甲/血量覆盖（projarmor_<id>/projhp_<id>，
                     // 无覆盖项用全局 projarmor/projhp）
                     var wIdP:String = "";
                     try { if (p.weap != null && p.weap.id != null) { wIdP = String(p.weap.id); } } catch (e:*) { }
                     var armP:Number = cfgProjArmor;
                     if (wIdP != "" && projArmorOver != null && projArmorOver[wIdP] != null) { armP = projArmorOver[wIdP]; }
                     dmg -= armP;   // 护甲（伤害先减护甲）
                     if (dmg <= 0) continue;
                     try { locP.remObj(b); } catch (e:*) { }   // 命中子弹弹出
                     var baseHpP:Number = cfgProjHp;
                     if (wIdP != "" && projHpOver != null && projHpOver[wIdP] != null) { baseHpP = projHpOver[wIdP]; }
                     var hpP:Number = projHp[p] != null ? projHp[p] : baseHpP;
                     hpP -= dmg;
                     if (hpP <= 0)
                     {
                        delete projHp[p];
                     if (isSandy)
                     {
                        // 时停中：爆炸仅视觉（伤害清零后爆炸，结束恢复原值；
                        // 真实伤害由回放中重演结算）
                        try
                        {
                           var svExpl:Number = p.damageExpl != null ? p.damageExpl : 0;
                           var svDest:Number = p.destroy != null ? p.destroy : 0;
                           p.damageExpl = 0;
                           p.destroy = 0;
                           p.explosion();
                           p.damageExpl = svExpl;
                           p.destroy = svDest;
                        }
                        catch (e:*) { }
                        // v1.92：引爆即杀（liv=0 → 下一世界步 vse→remObj）——
                        // 否则对象继续沿轨迹飞行（时停中+回放中"爆炸后鬼影"）
                        try { p.liv = 0; } catch (e:*) { }
                        // v1.91：记录引爆帧——回放中该帧真实爆炸
                        if (projBoom[p] == null)
                        {
                           projBoom[p] = { f: cfgDuration - sandyLeft, x: p.X, y: p.Y };
                        }
                        // v1.95：时停命中位置诊断（与回放命中位置对比——
                        // 定位"回放引爆位置晚于时停"）
                        if (boomDiagCnt < 6)
                        {
                           boomDiagCnt++;
                           log("[DIAG] sandyBoom: cls=" + flash.utils.getQualifiedClassName(p)
                               + " f=" + (cfgDuration - sandyLeft) + " X=" + p.X + " Y=" + p.Y);
                        }
                     }
                     else
                     {
                        try { p.explosion(); } catch (e:*) { }
                        // v1.92：引爆即杀——explosion() 不移除对象（babah 不置位、
                        // liv 尚余），否则常规游戏中爆炸后鬼影继续沿轨迹飞行
                        try { p.liv = 0; } catch (e:*) { }
                        // v1.95：回放/常规命中位置诊断（与 sandyBoom 对比）
                        if (replaying && boomDiagCnt < 6)
                        {
                           boomDiagCnt++;
                           log("[DIAG] replayHit: cls=" + flash.utils.getQualifiedClassName(p)
                               + " idx=" + replayIdx + " X=" + p.X + " Y=" + p.Y);
                        }
                     }
                     }
                     else
                     {
                        projHp[p] = hpP;
                     }
                     break;
                  }
                  catch (e:*) { }
               }
            }
         }
         catch (e:*) { }
      }

      // ===== 时停慢速世界：节流调用真实 loc.step()（每 slowfactor 帧 1 次 = 1/N 速）=====
      // "世界真慢速运行"：loc.step 步进玩家+全部对象+交互检测（celObj/celDist）——
      // 移动/计时/AI/交互/动画一致慢速，玩家可交互（门/箱等）。玩家本帧已手动 step
      // 过一次，loc.step 内的玩家步先清键（自由物理步），步后恢复。
      private function slowStepWorld():void
      {
         try
         {
            var locS:Object = world.loc;
            if (locS == null) return;
            // 1. 预判死亡敌人压住位移（sost=3 控制早退的兜底）
            for (var kP:Object in predDead)
            {
               try { kP.dx = 0; kP.dy = 0; kP.stay = true; } catch (e:*) { }
            }
            // 1b. 念力投掷的箱子：钉住 t_throw 防过期——碰撞在 t_throw>0 时
            // 只打晕、过期后结算伤害（时停中不当场结算）；时停结束不恢复，
            // 箱子在回放结束后继续飞行自然结算撞击伤害。
            // 敌人见下方循环：不钉 t_throw（真实反弹+首撞结束投掷），撞击
            // 记录后回放中结算伤害。
            try
            {
               var objsT:Array = locS.objs;
               if (objsT != null)
               {
                  for each (var oT:Object in objsT)
                  {
                     try
                     {
                        if (oT != null && oT.isThrow == true)
                        {
                           oT.t_throw = 5;
                           // 投掷箱由追踪器接管录像（v1.86）：move 检测的录像
                           // 受链扫描之谜影响不可靠——直接建/补追踪器数组，
                           // 逐帧按引用记录，飞行轨迹回放重演
                           try
                           {
                              if (seenAtk[oT] == null)
                              {
                                 seenAtk[oT] = true;
                                 var arrTB:Array = replayObjs[oT];
                                 if (arrTB == null)
                                 {
                                    arrTB = [];
                                    replayObjs[oT] = arrTB;
                                    replayObjArr.push(oT);
                                 }
                                 var fN2:int = cfgDuration - sandyLeft;
                                 while (arrTB.length < fN2 + 1)
                                 {
                                    arrTB.push({ x: oT.X, y: oT.Y, f: -1, s: "", wx: 0, wy: 0, twx: 0, twy: 0, vv: true, sto: 1, wrot: -99 });
                                 }
                                 log("[DIAG] recBox: X=" + oT.X + " Y=" + oT.Y + " frameN=" + fN2);
                              }
                           }
                           catch (e:*) { }
                        }
                     }
                     catch (e:*) { }
                  }
               }
            }
            catch (e:*) { }
            try
            {
               var unitsT:Array = locS.units;
               if (unitsT != null)
               {
                  for each (var uT:Object in unitsT)
                  {
                     try
                     {
                        if (uT != null && uT != world.gg && uT.t_throw > 0)
                        {
                           // 时停中撞墙不当场结算：清零 damWall（damageWall 的
                           // 伤害被跳过，碰撞反弹照常）。**不再钉 t_throw**——
                           // 首次撞击后由模组手动置 0 结束投掷（等价真实
                           // damageWall 行为）→ 单位自然制动下坠，反弹真实。
                           // 步前快照速度，步后检测撞击（见步进后的第 5 步）。
                           try
                           {
                              if (thrownDamWall[uT] == null) { thrownDamWall[uT] = uT.damWall; }
                              uT.damWall = 0;
                              thrownUnits[uT] = true;
                              if (thrownImpacts[uT] == null && thrownPreV[uT] == null)
                              {
                                 thrownPreV[uT] = { dx: uT.dx, dy: uT.dy };
                              }
                           }
                           catch (e:*) { }
                        }
                     }
                     catch (e:*) { }
                  }
               }
            }
            catch (e:*) { }
            // 1c. 敌人攻击事件快照（v1.81）：步前记录敌对单位各武器的
            // t_attack——攻击初始化（attack() 置 t_attack=rapid）产生上升沿，
            // 步后检测=本步开火。回放按记录事件复现攻击（方向/时机忠实
            // 重演，AI 在回放中不再实时开火）。瞄准点取步前 cel（世界坐标）。
            var atkPre:Dictionary = new Dictionary();
            try
            {
               var unitsA:Array = locS.units;
               if (unitsA != null)
               {
                  for each (var uA:Object in unitsA)
                  {
                     try
                     {
                        if (uA == null || uA == world.gg) continue;
                        var qnA:String = flash.utils.getQualifiedClassName(uA);
                        if (qnA.indexOf("NPC") >= 0) continue;
                        var cwA:* = uA["currentWeapon"];
                        if (cwA == null) continue;
                        var recA:Object = { ta: cwA.t_attack != null ? cwA.t_attack : -1,
                                            cx: uA.celX != null ? uA.celX : 0,
                                            cy: uA.celY != null ? uA.celY : 0, tt: -1, tm: -1 };
                        try
                        {
                           var twA:* = uA["throwWeapon"];
                           if (twA != null && twA.t_attack != null) { recA.tt = twA.t_attack; }
                        }
                        catch (e:*) { }
                        try
                        {
                           var mwA:* = uA["magicWeapon"];
                           if (mwA != null && mwA.t_attack != null) { recA.tm = mwA.t_attack; }
                        }
                        catch (e:*) { }
                        atkPre[uA] = recA;
                     }
                     catch (e:*) { }
                  }
               }
            }
            catch (e:*) { }
            // 2. 玩家攻击体清零 + 原始伤害捕获（必须在 loc.step 前——玩家刚手动
            //    step 完，本帧新生成的子弹尚未结算）
            var pendingHits:Array = []; // 步后即使子弹已被 remObj，仍能读取本次碰撞。
            var oS:Object = locS.firstObj;
            var gS:int = 0;
            while (oS != null)
            {
               var nxS:Object = oS.nobj;
               try
               {
                  if (flash.utils.getQualifiedClassName(oS).indexOf("fe.weapon::") == 0 && oS["owner"] == world.gg)
                  {
                     if (origDam[oS] == null && oS.damage > 0) { origDam[oS] = oS.damage; }
                     if (origDam[oS] > 0) pendingHits.push(oS);
                     oS.damage = 0;
                     oS.damageExpl = 0;
                  }
               }
               catch (e:*) { }
               oS = nxS;
               if (++gS > 20000) break;
            }
            // 3. 真实世界步进。玩家在 loc.step 内会被步一次（本帧第二次）——
            //    只清攻击键（防新攻击生成子弹泄漏）；
            //    **保留 keyAction**——control 在 keyAction=false 时走 else 分支
            //    置 actionObj=null（取消交互）→ 按住 E 的开锁/破解进度每节流帧
            //    被取消重来（进度条反复跳动）。actAction 对进行中的交互有
            //    actionObj 幂等检查（只做距离判断），重复调用安全。
            //    **保留 keySit**——下穿平台（throu = (keyJump||!stay) && keySit）
            //    需要按住下蹲键；清掉会让第二遍步 throu=false 覆盖，无法穿过。
            //    **保留 keyJump/keyBeUp**——清 keyJump 会让腾空时的第二遍步
            //    触发二段跳分支反复起跳，破坏念力悬浮并反复消耗魔力。
            //    步后恢复按键与悬浮状态。
            var cSave:Object = {};
            var savedLevit:int = 0;
            try
            {
               var kNames:Array = ["keyAttack","keyPunch","keyReload","keyGrenad","keyMagic"];
               for (var ki:int = 0; ki < kNames.length; ki++)
               {
                  cSave[kNames[ki]] = world.ctr[kNames[ki]];
                  world.ctr[kNames[ki]] = false;
               }
               savedLevit = world.gg["levit"];
            }
            catch (e:*) { }
            try
            {
               locS.step();
            }
            catch (e:*) { log("[SandyMod] loc.step error: " + e); }
            try
            {
               for (var kj:String in cSave)
               {
                  world.ctr[kj] = cSave[kj];
               }
               world.gg["levit"] = savedLevit;
            }
            catch (e:*) { }
            // 3b. 被投掷单位撞击检测（v1.74）：步后速度反转（elast 反弹/落地
            //     dy=0）且 |步前速度|>damWallSpeed = 撞墙/地/天花板。记录首次
            //     撞击帧与伤害（游戏 damageWall 公式：速度/damWallSpeed×damWall），
            //     并手动置 t_throw=0 结束投掷（等价真实 damageWall——单位自然
            //     制动下坠，反弹真实）；伤害在回放中撞击帧结算。
            try
            {
               for (var kTV:Object in thrownPreV)
               {
                  try
                  {
                     var pvT:Object = thrownPreV[kTV];
                     var dwsT:Number = kTV.damWallSpeed != null ? kTV.damWallSpeed : 12;
                     var spdT:Number = Math.sqrt(pvT.dx * pvT.dx + pvT.dy * pvT.dy);
                     var hitT:Boolean = (pvT.dx < -dwsT && kTV.dx >= 0) || (pvT.dx > dwsT && kTV.dx <= 0)
                                      || (pvT.dy < -dwsT && kTV.dy >= 0) || (pvT.dy > dwsT && kTV.dy <= 0);
                     if (hitT)
                     {
                        var dWallT:Number = thrownDamWall[kTV] != null ? thrownDamWall[kTV] : 0;
                        var damT:Number = spdT / dwsT * dWallT;
                        thrownImpacts[kTV] = { frame: cfgDuration - sandyLeft, dam: damT };
                        kTV.t_throw = 0;   // 结束投掷（真实 damageWall 行为）
                        delete thrownPreV[kTV];
                     }
                     else if (kTV.t_throw <= 0)
                     {
                        // 投掷自然过期（未撞击）——无伤害记录
                        delete thrownPreV[kTV];
                     }
                  }
                  catch (e:*) { }
               }
            }
            catch (e:*) { }
            // 3c. 敌人攻击事件检测（v1.81）：t_attack 上升沿=本步开火——
            // 记录 {帧号, 武器槽 0=枪 1=手雷 2=魔法, 瞄准点世界坐标} 供回放复现
            try
            {
               var frameAtk:int = cfgDuration - sandyLeft;
               for (var kA:Object in atkPre)
               {
                  try
                  {
                     var recA2:Object = atkPre[kA];
                     var cwA2:* = kA["currentWeapon"];
                     if (cwA2 != null && cwA2.t_attack > recA2.ta) { addEnemyAtk(kA, { frame: frameAtk, w: 0, cx: recA2.cx, cy: recA2.cy }); }
                     try
                     {
                        var twA2:* = kA["throwWeapon"];
                        if (twA2 != null && twA2.t_attack > recA2.tt) { addEnemyAtk(kA, { frame: frameAtk, w: 1, cx: recA2.cx, cy: recA2.cy }); }
                     }
                     catch (e:*) { }
                     try
                     {
                        var mwA2:* = kA["magicWeapon"];
                        if (mwA2 != null && mwA2.t_attack > recA2.tm) { addEnemyAtk(kA, { frame: frameAtk, w: 2, cx: recA2.cx, cy: recA2.cy }); }
                     }
                     catch (e:*) { }
                  }
                  catch (e:*) { }
               }
            }
            catch (e:*) { }
            // 3d. 投掷物可击落检测（v1.83）：子弹命中手雷/导弹/榴弹——
            // 血量归零直接爆炸（时停中仅视觉）
            stepProjHits(locS, true);
            // 3e. 敌人攻击体追踪登记（v1.85）：节流步后扫描（敌人子弹在
            // loc.step 内生成——按引用录像，回放重演真实轨迹）
            try
            {
               var oNE:Object = locS.firstObj;
               var gNE:int = 0;
               while (oNE != null)
               {
                  try
                  {
                     if (oNE["owner"] != world.gg && seenAtk[oNE] == null
                         && flash.utils.getQualifiedClassName(oNE).indexOf("fe.weapon::") == 0)
                     {
                        registerAtk(oNE);
                     }
                  }
                  catch (e:*) { }
                  oNE = oNE.nobj;
                  if (++gNE > 20000) break;
               }
            }
            catch (e:*) { }
            // 4. 读取步前保留的引用；正常子弹命中后已移出 loc 链表。
            // 每步重新查 parr 的新增接触，去重交给 creditHit。
            for each (var hitBody:Object in pendingHits)
            {
               creditHit(hitBody, origDam[hitBody]);
            }
            freezeMeleeDamage();
         }
         catch (e:*) { }
      }
      // ===== 发射器计数维护（World.step 守卫内的每帧重置，时停中由模组代做）=====
      private function resetFxCounter():void
      {
         try
         {
            var EmitterClass:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Emitter") as Class;
            if (EmitterClass != null)
            {
               EmitterClass["kol2"] = EmitterClass["kol1"];
               EmitterClass["kol1"] = 0;
            }
         }
         catch (e:*) { }
      }

      // WClub 的攻击体不在 loc 链表，而且伤害设定、真正接触发生在不同帧。
      // 保存本挥击伤害，每帧读取其接触列表；零伤害后仍继续追踪。
      private function freezeMeleeDamage():void
      {
         try
         {
            var cwM:Object = world.gg.currentWeapon;
            if (cwM == null || cwM.b == null) return;
            var qnM:String = flash.utils.getQualifiedClassName(cwM);
            // WKick.actions resets damage and calls bindMove inline: its HP loss has
            // already happened. Do not add that real loss again as deferred damage.
            if (qnM == "fe.weapon::WKick") { cwM.b.damage = 0; cwM.b.damageExpl = 0; return; }
            if (qnM != "fe.weapon::WClub" && qnM != "fe.weapon::WPunch") return;
            var b:Object = cwM.b;
            if (b.damage > 0) origDam[b] = b.damage;
            if (origDam[b] > 0) creditHit(b, origDam[b]);
            b.damage = 0;
            b.damageExpl = 0;
         }
         catch (e:*) { }
      }

      private function expectedHitCh(body:Object, enemy:Object):Number
      {
         return damagePredictor.hitChance(body, enemy);
      }

      // Projectile damage already includes weapon condition. Use the native damage
      // order, type-specific defenses and virtual durability; no blanket safety tax.
      private function expectedDam(body:Object, enemy:Object, dmg:Number, commit:Boolean = false):Number
      {
         var remaining:Number = enemy.hp - (predDam[enemy] != null ? Number(predDam[enemy]) : 0);
         return damagePredictor.estimate(body, enemy, dmg, remaining, !world.testDam, commit);
      }

      private function creditHit(body:Object, dmg:Number):void
      {
         try
         {
            var contacts:Array = body.parr as Array;
            if (contacts == null || contacts.length == 0) return;
            // Bullet.udar adds parr BEFORE its RNG hit test. This is a contact, not
            // proof of a hit; expectedDam retains native miss / dodge probabilities.
            // WClub replaces parr for each swing while retaining the same Bullet.
            var credited:Object = hitCred[body];
            if (credited == null || credited.parr !== contacts)
            {
               credited = { parr: contacts, targets: [] };
               hitCred[body] = credited;
            }
            for each (var u:Object in contacts)
            {
               if (u == null || u == world.gg || credited.targets.indexOf(u) >= 0) continue;
               try
               {
                  if (u.sost != 1 || u.fraction == world.gg.fraction) continue;
                  var amount:Number = expectedDam(body, u, dmg, true);
                  credited.targets.push(u);
                  if (!isFinite(amount) || amount <= 0) continue;
                  if (predDam[u] == null) predDam[u] = 0;
                  predDam[u] += amount;
                  checkPredDeath(u);
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
      }
      // ===== 预判死亡判定：累计伤害 ≥ 血量 → sost=3 死亡姿态（慢速死亡动画+停止行动）=====
      // 不真杀（不调 die()）：回放中才真实结算死亡——时停只是"预告"
      private function checkPredDeath(enemy:Object):void
      {
         try
         {
            if (enemy == null || predDead[enemy]) return;
            if (enemy.sost != 1) return;
            var pd:Number = predDam[enemy] != null ? predDam[enemy] : 0;
            if (pd > 0 && enemy.hp > 0 && pd >= enemy.hp)
            {
               predDead[enemy] = true;
               enemy.sost = 3;   // 死亡姿态：control 早退（Monstrik 检查 sost==3）+
                                 // animate 播 die 动画；不走 timerDie（internal 无法访问）
               // 无死亡动画的单位（炮塔/机器等 animate 不检查 sost）：禁用使其
               // 停止行动（Unit.step 对 disabled 早退）——炮塔类死亡判定可视化；
               // v1.75 增补：调用其 expl() 慢速播放爆炸动画（粒子只随节流帧
               // 步进=1/N 慢动作）+ 隐藏本体视觉（真实死亡的爆炸+消失观感；
               // endSandy 的 restorePredDead 恢复，回放中真实结算死亡）
               try
               {
                  var qnPd:String = flash.utils.getQualifiedClassName(enemy);
                  if (qnPd.indexOf("Turret") >= 0 || qnPd.indexOf("Bloat") >= 0
                      || qnPd.indexOf("Robot") >= 0 || qnPd.indexOf("Msp") >= 0)
                  {
                     enemy.disabled = true;
                     try { if (enemy.hpbar != null) enemy.hpbar.visible = false; } catch (e:*) { }
                     try { if (enemy.expl != null) { enemy.expl(); } } catch (e:*) { }
                     try { if (enemy.vis != null) { enemy.vis.visible = false; } } catch (e:*) { }
                  }
               }
               catch (e:*) { }
               log("[SandyMod] 预判死亡: " + flash.utils.getQualifiedClassName(enemy)
                   + " predDam=" + pd + " hp=" + enemy.hp);
            }
         }
         catch (e:*) { }
      }

      // ===== 时停结束：预判死亡的敌人恢复存活（回放中真实结算死亡）=====
      private function restorePredDead():void
      {
         try
         {
            for (var k:Object in predDead)
            {
               try
               {
                  if (k != null && k.sost == 3) { k.sost = 1; }
                  if (k != null && k.disabled) { k.disabled = false; }
                  // 炮塔类预判死亡时隐藏的视觉恢复（回放中真实结算死亡）
                  if (k != null && k.vis != null) { k.vis.visible = true; }
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
         damagePredictor.reset();
         predDam = new Dictionary();
         origDam = new Dictionary();
         hitCred = new Dictionary();
         predDead = new Dictionary();
      }

      // ===== 快照时停结束时的武器/弹药状态（回放结束后恢复，保证回放零净消耗）=====
      private function buildSandyEndSnap():void
      {
         sandyEndSnap = null;
         try
         {
            sandyEndSnap = {};
            endWeapon = world.gg.currentWeapon;
            var wns:* = world.invent.weapons;
            for (var wid:String in wns)
            {
               try
               {
                  var wobj:* = wns[wid];
                  if (wobj != null) { sandyEndSnap["h_" + wid] = wobj.hold; }
               }
               catch (e:*) { }
            }
            // v1.101：快照直接遍历 **items**（id 键）——此前遍历 ammos（base 键）
            // 且用 base 键读 items：换弹型武器（ammoTarg!=ammo）的变种弹药
            // id≠base，其 kol 从未被快照/恢复覆盖——游戏侧返还发生在回放中时
            // 变种弹药永远多出来（"切枪后武器A弹药增加"根因，与 ammoLeash 0 次
            // 日志吻合）。items 含全部物品（弹药物/药水/杂物），双向精确恢复
            // 对回放期间不可能变动的物品无副作用。
            var ammE:* = world.invent.items;
            for (var aE:String in ammE)
            {
               try { sandyEndSnap["it_" + aE] = world.invent.items[aE].kol; } catch (e:*) { }
            }
         }
         catch (e:*) { sandyEndSnap = null; }
      }

      // ===== 模拟游戏 changeWeaponNow：立即切换武器（无切换动画），配套视觉/GUI 更新 =====
      private function switchToWeapon(w:Object):void
      {
         try
         {
            if (world.gg.currentWeapon == w) return;
            if (world.gg.currentWeapon != null)
            {
               try { world.gg.currentWeapon.remVisual(); } catch (e:*) { }
            }
            world.gg.currentWeapon = w;
            world.gg.childObjs[0] = w;
            if (w != null)
            {
               try
               {
                  w.addVisual();
                  w.setNull();
                  w.setPers(world.gg, world.gg.pers);
                  world.gui.setWeapon();
               }
               catch (e:*) { log("[SandyMod] switchToWeapon visual error: " + e); }
            }
            log("[SandyMod] switchToWeapon -> " + (w != null ? w.id : "none"));
         }
         catch (e:*) { log("[SandyMod] switchToWeapon error: " + e); }
      }

      // ===== 恢复时停结束状态：回放结束后弹夹剩余=时停结束时，背包弹药不被回放消耗 =====
      private function restoreSandyEndSnap():void
      {
         if (sandyEndSnap == null) return;
         try
         {
            var wns:* = world.invent.weapons;
            for (var wid:String in sandyEndSnap)
            {
               if (wid.indexOf("h_") == 0)
               {
                  var tW:String = wid.substr(2);
                  try
                  {
                     var wobj:* = wns[tW];
                     if (wobj != null) { wobj.hold = sandyEndSnap[wid]; }
                  }
                  catch (e:*) { }
               }
                  else if (wid.indexOf("it_") == 0)
                  {
                     var tI:String = wid.substr(3);
                     try
                     {
                        var itR:* = world.invent.items[tI];
                        // v1.97：**精确恢复**（不再只向上）——回放中武器切换+
                        // 弹匣强制灌满若触发游戏的弹药返还（reloadWeapon 换弹
                        // 型 / unloadWeapon）会把灌满的弹匣倒回背包，弹药反而
                        // **增加**（"先开火再切换武器→回放后子弹有概率增加"
                        // 根因）；回放期间玩家无操控不可能拾取，双向精确恢复
                        // 安全（拾取不可能发生）
                        if (itR != null && itR.kol != sandyEndSnap[wid])
                        {
                           var dKol:Number = sandyEndSnap[wid] - itR.kol;
                           itR.kol = sandyEndSnap[wid];
                           try
                           {
                              if (world.invent.mass != null && itR.mass != null)
                              {
                                 world.invent.mass[2] += dKol * itR.mass;
                              }
                           }
                           catch (e:*) { }
                        }
                     }
                     catch (e:*) { }
                  }
            }
         }
         catch (e:*) { }
         sandyEndSnap = null;
      }

      // ===== v1.100：回放结束后弹药防泄漏钳制 =====
      // 回放中的弹匣强制灌满+武器切换可能触发游戏侧弹药返还（换弹型
      // reloadWeapon / unloadWeapon 把弹匣倒回背包）——若返还发生在
      // endReplay 的快照恢复之后，武器A的弹药会增加（用户实测：时停中
      // 用A开火再切到B→回放后A弹药增加）。恢复后 120 帧内每帧对背包
      // 弹药"多出快照"的部分钳回快照（正常开火/换弹是减少，不受影响；
      // 4 秒窗口内拾取同型弹药会被钳掉——罕见场景，可接受）；非当前
      // 武器的弹匣同样钳制（已收起武器无法被玩家操作，任何增加都来自
      // 游戏侧返还）。当前武器不动（玩家可正常开火换弹）。
      private function ammoLeashTick():void
      {
         try
         {
            leashLeft--;
            if (leashSnap == null) { return; }
            var wns:Object = world.invent != null ? world.invent.weapons : null;
            var cwL:* = world.gg != null ? world.gg.currentWeapon : null;
            for (var wid:String in leashSnap)
            {
               if (wid.indexOf("it_") == 0)
               {
                  var tI:String = wid.substr(3);
                  try
                  {
                     var itL:* = world.invent.items[tI];
                     if (itL != null && itL.kol > leashSnap[wid])
                     {
                        var dKol:Number = leashSnap[wid] - itL.kol;
                        itL.kol = leashSnap[wid];
                        try
                        {
                           if (world.invent.mass != null && itL.mass != null)
                           {
                              world.invent.mass[2] += dKol * itL.mass;
                           }
                        }
                        catch (e:*) { }
                        if (leashDiagCnt < 8)
                        {
                           leashDiagCnt++;
                           log("[DIAG] ammoLeash: type=" + tI + " kol -> " + leashSnap[wid]);
                        }
                     }
                  }
                  catch (e:*) { }
               }
               else if (wid.indexOf("h_") == 0 && wns != null)
               {
                  var tW:String = wid.substr(2);
                  try
                  {
                     var wL:* = wns[tW];
                     if (wL != null && wL != cwL && wL.hold > leashSnap[wid])
                     {
                        wL.hold = leashSnap[wid];
                        if (leashDiagCnt < 8)
                        {
                           leashDiagCnt++;
                           log("[DIAG] ammoLeash: hold " + tW + " -> " + leashSnap[wid]);
                        }
                     }
                  }
                  catch (e:*) { }
               }
            }
            if (leashLeft <= 0) { leashSnap = null; }
         }
         catch (e:*) { }
      }

      private function saveConfigFile():void
      {
         var NL:String = String.fromCharCode(13, 10);
         var sb:Array = [];
         sb.push("# SandevistanMod config (saved by menu settings)");
         sb.push("# hotkey: 220=\  33=PageUp 34=PageDown 36=Home  F1-F12=112-123");
         sb.push("hotkey=" + cfgHotkey);
         sb.push("duration=" + cfgDuration);
         sb.push("cooldown=" + cfgCooldown);
         sb.push("replayspeed=" + cfgReplaySpeed);
         sb.push("slowfactor=" + cfgSlowFactor);
         sb.push("ghostevery=" + cfgGhostEvery);
         sb.push("replayghost=" + cfgReplayGhost);
         sb.push("replayghostlife=" + cfgReplayGhostLife);
         // v1.127：projhits/projhp/projarmor/projhp_<id>/projarmor_<id>/swaprun
         // 回写已移除——两技能迁移到 mods/MoreSkills&Weapons（MSW 用
         // SharedObject 持久化，见 MSWConfig）
         sb.push("ghostalpha=" + cfgGhostAlpha);
         sb.push("ghostblend=" + cfgGhostBlend);
         sb.push("colormode=" + cfgColorMode);
         sb.push("edgethresh=" + cfgEdgeThresh);
         sb.push("enemysandy=" + cfgEnemySandy);
         sb.push("esandydur=" + cfgESDur);
         sb.push("esandycd=" + cfgESCd);
         sb.push("esandyspd=" + cfgESSpd);
         sb.push("esandyghost=" + (cfgESGhost ? 1 : 0));
         sb.push("esandyghostlife=" + cfgESGhostLife);
         sb.push("esandymark=" + (cfgESMark ? 1 : 0));
         sb.push("esandyper=" + cfgESPer);
            sb.push("esandyenabled=" + (cfgESEnabled ? 1 : 0));
            sb.push("esandyroomprob=" + cfgESRoomProb);
            sb.push("musicon=" + (cfgMusicOn ? 1 : 0));
            sb.push("musicvol=" + cfgMusicVol);
            sb.push("musicfade=" + cfgMusicFade);
         sb.push("fxrun=" + (cfgFxRun ? 1 : 0));
         sb.push("showhud=" + (cfgHud ? 1 : 0));
         sb.push("diaglog=" + (cfgDiagLog ? 1 : 0));
         sb.push("debugtest=0");
         var out:String = sb.join(NL) + NL;
         // ① 应用目录（历史正式位置）——AIR 只读沙箱下必失败（v1.137 前的
         //    "F9 保存无效"潜伏 bug 根因），保留尝试以兼容可写环境
         var okA:Boolean = false;
         try
         {
            var f:File = File.applicationDirectory.resolvePath("mods/Sandevistan/release/config.txt");
            var stream:FileStream = new FileStream();
            stream.open(f, FileMode.WRITE);
            stream.writeUTFBytes(out);
            stream.close();
            okA = true;
         }
         catch (e:*) { okA = false; }
         // ② v1.137：应用存储持久层（必定可写；loadConfig 后读覆盖生效）
         var okS:Boolean = false;
         try
         {
            var f2:File = File.applicationStorageDirectory.resolvePath("SandevistanMod_config.txt");
            var s2:FileStream = new FileStream();
            s2.open(f2, FileMode.WRITE);
            s2.writeUTFBytes(out);
            s2.close();
            okS = true;
         }
         catch (e2:*) { okS = false; }
         log("[SandyMod] config saved appDir=" + (okA ? 1 : 0) + " storage=" + (okS ? 1 : 0));
      }

      private static const THEME_PATH:String = "mods/Sandevistan/release/sandy_theme.mp3";
      private static const MUSIC_GUIDE:String =
         "音乐文件配置\n模组不附带音乐，请自备 MP3。\n\n"
         + "1. 将文件命名为：\nsandy_theme.mp3\n"
         + "2. 放入游戏安装目录下：\nmods/Sandevistan/release/\n"
         + "3. 完全退出并重启游戏。\n"
         + "4. 开启“时停主题曲”，调高音量。\n\n"
         + "未放音乐不影响时停使用。\n"
         + "请勿重复添加 .mp3 后缀；\n其他格式需先转换为 MP3。";
      // ==================== v1.137：MSW 设置中枢接入 ====================
      // Independent ModSettings registry; values and config persistence stay here.
      private function stepHubRegister():void
      {
         try
         {
            var c:* = world.main != null ? world.main.getChildByName("ModSettingsCarrier") : null;
            if(c == null || c["modAPI"] == null) return;
            var pageArgs:Array = ["sandevistan", "斯安维斯坦", hubBuildItems(), hubOnPageClose, MUSIC_GUIDE];
            if("localizationVersion" in c["modAPI"]) pageArgs.push({translate:SandyLocale.render});
            c["modAPI"]["registerPage"].apply(c["modAPI"], pageArgs);
            hubRegistered = true;
            hubViaCarrier = true;
            log("[SandyMod] settings hub registered via ModSettingsCarrier (tries=" + hubRegTries + ")");
         }
         catch(e:*) { if(hubRegTries >= 36000) log("[SandyMod] hub register gave up: " + e); }
      }

      // 菜单设置项：保留既有范围、步进与保存契约。
      // 一期契约仅 check/slider——热键码需按键捕获；沿用 config 的 hotkey 字段。
      private function hubBuildItems():Array
      {
         var m:SandevistanMod = this;
         var items:Array = [];
         items.push({ "key": "duration", "label": "生效时长(秒)", "kind": "slider",
                      "min": 1, "max": 120, "step": 1, "hint": "时停持续时间（30帧=1秒）",
                      "get": function():* { return m.cfgDuration / 30; },
                      "set": function(v:*):void { m.cfgDuration = int(Math.max(1, Math.min(120, Number(v)))) * 30; } });
         items.push({ "key": "cooldown", "label": "冷却(秒)", "kind": "slider",
                      "min": 0, "max": 120, "step": 1, "hint": "0=无冷却",
                      "get": function():* { return m.cfgCooldown / 30; },
                      "set": function(v:*):void { m.cfgCooldown = int(Math.max(0, Math.min(120, Number(v)))) * 30; } });
         items.push({ "key": "replayspeed", "label": "回放速度", "kind": "slider",
                      "min": 1, "max": 20, "step": 1, "hint": "回放倍速（每显示帧消耗N历史帧）",
                      "get": function():* { return m.cfgReplaySpeed; },
                      "set": function(v:*):void { m.cfgReplaySpeed = Math.max(1, Math.min(20, Number(v))); } });
         items.push({ "key": "ghostalpha", "label": "残影不透明度", "kind": "slider",
                      "min": 5, "max": 100, "step": 5, "hint": "百分比",
                      "get": function():* { return m.cfgGhostAlpha; },
                      "set": function(v:*):void { m.cfgGhostAlpha = int(Math.max(5, Math.min(100, Number(v)))); } });
         items.push({ "key": "ghostevery", "label": "残影间隔(帧)", "kind": "slider",
                      "min": 1, "max": 30, "step": 1, "hint": "时停期每N帧生成一个残影，越小越密",
                      "get": function():* { return m.cfgGhostEvery; },
                      "set": function(v:*):void { m.cfgGhostEvery = int(Math.max(1, Math.min(30, Number(v)))); } });
         items.push({ "key": "replayghost", "label": "回放残影间隔(帧)", "kind": "slider",
                      "min": 1, "max": 30, "step": 1, "hint": "每N个显示帧生成1个，调大减少数量",
                      "get": function():* { return m.cfgReplayGhost; },
                      "set": function(v:*):void { m.cfgReplayGhost = int(Math.max(1, Math.min(30, Number(v)))); } });
         items.push({ "key": "replayghostlife", "label": "回放残影寿命(帧)", "kind": "slider",
                      "min": 1, "max": 60, "step": 1, "hint": "越小拖尾越短",
                      "get": function():* { return m.cfgReplayGhostLife; },
                      "set": function(v:*):void { m.cfgReplayGhostLife = int(Math.max(1, Math.min(60, Number(v)))); } });
         items.push({ "key": "edgethresh", "label": "渐变门槛", "kind": "slider",
                      "min": 1, "max": 30, "step": 1, "hint": "边缘行者配色：速度≥此值全绿",
                      "get": function():* { return m.cfgEdgeThresh; },
                      "set": function(v:*):void { m.cfgEdgeThresh = Math.max(1, Math.min(30, Number(v))); } });
         items.push({ "key": "fxrun", "label": "特效继续", "kind": "check",
                      "hint": "时停期间粒子特效继续动画",
                      "get": function():* { return m.cfgFxRun; },
                      "set": function(v:*):void { m.cfgFxRun = (v == true); m.saveCfgQuiet(); } });
         items.push({ "key": "showhud", "label": "顶部状态UI", "kind": "check",
                      "hint": "\"斯安维斯坦启动中/回放中/充能中\"显示开关",
                      "get": function():* { return m.cfgHud; },
                      "set": function(v:*):void { m.cfgHud = (v == true); m.saveCfgQuiet(); } });
         items.push({ "key": "esandyenabled", "label": "敌人斯安维斯坦", "kind": "check",
                      "hint": "生成带斯安维斯坦的敌人（v1.136 起默认关）",
                      "get": function():* { return m.cfgESEnabled; },
                      "set": function(v:*):void { m.cfgESEnabled = (v == true); m.saveCfgQuiet(); } });
         items.push({ "key": "esandyroomprob", "label": "敌人房间概率%", "kind": "slider",
                      "min": 0, "max": 100, "step": 10, "hint": "房间出现斯安维斯坦敌人的概率",
                      "get": function():* { return m.cfgESRoomProb; },
                      "set": function(v:*):void { m.cfgESRoomProb = int(Math.max(0, Math.min(100, Number(v)))); } });
         items.push({ "key": "esandyper", "label": "房内装备占比%", "kind": "slider",
                      "min": 0, "max": 100, "step": 5, "hint": "有斯安维斯坦敌人的房间内装备比例",
                      "get": function():* { return m.cfgESPer; },
                      "set": function(v:*):void { m.cfgESPer = int(Math.max(0, Math.min(100, Number(v)))); } });
         // v1.139：主题曲
         items.push({ "key": "musicon", "label": "时停主题曲", "kind": "check",
                      "hint": MUSIC_GUIDE,
                      "get": function():* { return m.cfgMusicOn; },
                      "set": function(v:*):void { m.cfgMusicOn = (v == true); if (!m.cfgMusicOn) { m.musHardStop(); } m.saveCfgQuiet(); } });
         items.push({ "key": "musicvol", "label": "主题曲音量%", "kind": "slider",
                      "min": 0, "max": 100, "step": 5, "hint": "独立于游戏音效音量",
                      "get": function():* { return m.cfgMusicVol; },
                      "set": function(v:*):void { m.cfgMusicVol = int(Math.max(0, Math.min(100, Number(v)))); m.applyMusVol(m.musFadeLeft > 0 ? m.musFadeLeft / Math.max(1, m.cfgMusicFade) : 1); m.saveCfgQuiet(); } });
         items.push({ "key": "musicfade", "label": "主题曲淡出(帧)", "kind": "slider",
                      "min": 30, "max": 600, "step": 15, "hint": "回放结束后淡出时长（30帧=1秒）",
                      "get": function():* { return m.cfgMusicFade; },
                      "set": function(v:*):void { m.cfgMusicFade = int(Math.max(30, Math.min(600, Number(v)))); m.saveCfgQuiet(); } });
         return items;
      }

      /** 中枢页收起：slider 延迟保存统一落盘（契约 onPageClose）。 */
      private function hubOnPageClose():void
      {
         saveCfgQuiet();
      }

      /** v1.139：静默持久化（中枢 check 即时保存/页收 flush 共用）——
       *  不走 log 报错路径，成功失败只留一行诊断。 */
      private function saveCfgQuiet():void
      {
         try { saveConfigFile(); } catch (e:*) { }
      }

      // ==================== v1.139：时停主题曲 ====================
      // 用户选定行为：仅玩家时停触发（startSandy 唯一入口，经 onFrameInner
      // 状态沿检测）；还在放（含淡出中）→ 取消淡出恢复音量继续放；已停 →
      // 从上次实际停止位置续播（断点，自然播完整首则归零；会话内有效，重启
      // 归零）；回放结束（endReplay 后回放沿）线性淡出。独立 SoundTransform，
      // 不受游戏音量影响；文件缺失/加载失败全程静默降级。
      private var musSound:Sound = null;
      private var musChan:SoundChannel = null;
      private var musFadeLeft:int = 0;           // >0 = 淡出剩余帧
      private var musLastPos:Number = 0;         // 断点（ms）
      private var musFailed:Boolean = false;     // 加载失败——静默禁用
      private var musOrphanT:int = 0;            // 无时停无回放但音乐在放的兜底计时
      private var musStartSeen:Boolean = false;  // 测试断言旗标
      private var musFadeSeen:Boolean = false;
      private var musStopSeen:Boolean = false;
      private var musResumeSeen:Boolean = false;
      private var prevSandyActive:Boolean = false;   // v1.139：时停状态沿检测
      private var prevReplaying:Boolean = false;     // v1.139：回放状态沿检测

      // init 时预加载：第一次时停不承担 10MB 读取延迟
      private function loadThemeSound():void
      {
         var r:String = null;
         try
         {
            var f:File = File.applicationDirectory.resolvePath(THEME_PATH);
            if (!f.exists)
            {
               r = "absent";
            }
            else
            {
               musSound = new Sound();
               musSound.addEventListener(IOErrorEvent.IO_ERROR, onMusLoadError);
               musSound.load(new URLRequest(f.url));
               r = "loading";
            }
         }
         catch (e:*) { musFailed = true; r = "threw " + e; }
         log("[MUSIC] theme preload: " + r);
      }

      private function onMusLoadError(e:Event):void
      {
         musFailed = true;
         log("[MUSIC] theme load error, feature silent");
      }

      // 时停沿：开始/续播
      private function playTheme():void
      {
         try
         {
            if (!cfgMusicOn || musFailed || musSound == null) return;
            if (musChan != null)
            {
               // 还在放：淡出中则取消淡出恢复音量，不打断
               if (musFadeLeft > 0)
               {
                  musFadeLeft = 0;
                  applyMusVol(1);
                  log("[MUSIC] defade resume @" + int(musChan.position));
               }
               return;
            }
            var len:Number = 0;
            try { len = musSound.length; } catch (eL:*) { }
            // 断点续播：上次位置有效（且未到歌尾）则从断点起，否则从头
            var off:Number = (musLastPos > 0 && (len <= 0 || musLastPos < len - 500)) ? musLastPos : 0;
            musChan = musSound.play(off);
            if (musChan == null) { musLastPos = 0; return; }
            musChan.addEventListener(Event.SOUND_COMPLETE, onMusComplete);
            applyMusVol(1);
            if (off > 0) { musResumeSeen = true; }
            musStartSeen = true;
            log("[MUSIC] start @" + int(off) + (off > 0 ? " (resume)" : ""));
         }
         catch (e:*) { log("[MUSIC] play error: " + e); }
      }

      // 回放结束沿：开始淡出
      private function fadeTheme():void
      {
         try
         {
            if (musChan == null || musFadeLeft > 0) return;
            musFadeLeft = Math.max(1, cfgMusicFade);
            musFadeSeen = true;
            log("[MUSIC] fade @" + int(musChan.position) + " over " + musFadeLeft + "f");
         }
         catch (e:*) { }
      }

      // 每帧：淡出推进 + 孤儿兜底（无时停无回放但音乐在放超过 60 帧 → 补淡出，
      // 防 endReplay 未达的错误路径把歌留在外面）
      private function tickMusic():void
      {
         try
         {
            if (musChan == null) { musOrphanT = 0; return; }
            if (musFadeLeft > 0)
            {
               musFadeLeft--;
               if (musFadeLeft <= 0)
               {
                  musLastPos = musChan.position;   // 断点 = 实际停止位置（含淡出段）
                  musChan.removeEventListener(Event.SOUND_COMPLETE, onMusComplete);
                  musChan.stop();
                  musChan = null;
                  musStopSeen = true;
                  log("[MUSIC] stopped, breakpoint @" + int(musLastPos));
                  return;
               }
               applyMusVol(musFadeLeft / Math.max(1, cfgMusicFade));
               return;
            }
            if (!sandyActive && !replaying && (authorityState == null || authorityState.phase == "idle"))
            {
               if (++musOrphanT == 60) { log("[MUSIC] orphan playback, fading"); fadeTheme(); }
            }
            else { musOrphanT = 0; }
         }
         catch (e:*) { }
      }

      private function applyMusVol(k:Number):void
      {
         try
         {
            if (musChan == null) return;
            var v:Number = Math.max(0, Math.min(1, k)) * (cfgMusicVol / 100);
            musChan.soundTransform = new SoundTransform(v);
         }
         catch (e:*) { }
      }

      // musicon 关闭时立即停（断点保留，重开后从断点续）
      private function musHardStop():void
      {
         try
         {
            if (musChan != null)
            {
               musLastPos = musChan.position;
               musChan.removeEventListener(Event.SOUND_COMPLETE, onMusComplete);
               musChan.stop();
               musChan = null;
            }
            musFadeLeft = 0;
            log("[MUSIC] hard stop, breakpoint @" + int(musLastPos));
         }
         catch (e:*) { }
      }

      private function onMusComplete(e:Event):void
      {
         // 自然播完整首：断点归零（下次从头），通道作废
         musChan = null;
         musLastPos = 0;
         musFadeLeft = 0;
         log("[MUSIC] complete, breakpoint reset");
      }

      // ==================== 斯安维斯坦 ====================
      private function startSandy():void
      {
         if (sandyActive || replaying) return;
         if (!inGameplay()) return;
         try
         {
            savedOnPause = world.onPause;
            // 时停慢速世界（v1.46）：onPause=true 冻结世界，模组节流 step——
            // 玩家每帧手动 step（全速），敌人/物品/攻击体每 slowfactor 帧 step 1 次
            // （1/N 速）。注：位移回退方案因帧序（模组先于游戏 step，渲染在游戏后）
            // 回退被全速移动覆盖而无效——节流是"真慢速"（动作/判定同步 1/N）
            world.onPause = true;
            // v1.82 伤害策略：时停中**不再设 godMode**——godMode 的 UnitPlayer.
            // damage 在每次受击后把 hp 复位到受击前值（"掉血-回复反复横跳"的
            // 根源）。现时停中玩家受**真实伤害**（慢速世界中的攻击正常掉血），
            // 回放期间无敌（godMode 在回放开始处设置）。保存原值供结束恢复。
            try
            {
               savedGod = world.godMode;
            }
            catch (e:*) { }
            // 记录时停开始时的武器（回放开始切回它重演，回放结束切回时停结束时武器）
            startWeapon = null;
            try { startWeapon = world.gg.currentWeapon; } catch (e:*) { }
            endWeapon = null;
            sandyEndSnap = null;
            // 键状态处理：先保存当前按住的键，关 SATS（其 clearAll 会清布尔），再恢复，
            // 这样"按住空格/方向键进入时停"的玩家在时停中按键依然有效（Flash 不会为重按的键重发事件）
            try
            {
               var cSave:Array = [];
               var kNames:Array = ["keyLeft","keyRight","keyJump","keySit","keyBeUp","keyRun","keyAttack","keyPunch",
                  "keyReload","keyGrenad","keyMagic","keyDef","keyPet","keyAction","keyCrack","keyTele","keySats"];
               for (var ki:int = 0; ki < kNames.length; ki++)
               {
                  cSave[kNames[ki]] = world.ctr[kNames[ki]];
               }
               if (world.sats != null && world.sats.active)
               {
                  world.sats.onoff(-1);
               }
               for (ki = 0; ki < kNames.length; ki++)
               {
                  world.ctr[kNames[ki]] = cSave[kNames[ki]];
               }
            }
            catch (e:*) { }
            // 时停期间禁用玩家交互（防碰触 NPC/触发点 -> 对话 -> controlOff 锁死控制）
            try
            {
               savedInter = world.gg["inter"];
               world.gg["inter"] = null;
            }
            catch (e:*) { }
            sandyActive = true;
            sandyLeft = cfgDuration;
            history = new Array();
            // 清空上一轮重演记录（场景级录像：敌人/物品/攻击体每帧状态）
            replayObjs = new Dictionary();
            replayAnimCat = new Dictionary();
            replayBlit.reset();
            replayObjArr = [];
            seenPos = new Dictionary();
            thrownImpacts = new Dictionary();   // 投掷撞击记录重置
            thrownPreV = new Dictionary();
            thrownUnits = new Dictionary();
            thrownDamWall = new Dictionary();
            enemyAtks = new Dictionary();       // 敌人攻击事件记录重置
            gSnapKol = -1;
            seenAtk = new Dictionary();         // 攻击体追踪器重置
            projBoom = new Dictionary();        // v1.91：时停引爆记录重置
            reExecPin = new Dictionary();       // v1.94：重执行孪生钉重置
            boomDiagCnt = 0;                    // v1.94：boom 诊断计数重置
            twinSavExpl = new Dictionary();     // v1.98：孪生体惰性化记录重置
            twinDiagCnt = 0;
            partDiagOnce = false;               // v1.98：粒子视觉类型诊断重置
            recPaired = new Dictionary();       // v1.99：配对去重重置
            reattached = new Dictionary();
            doorPrevDop = new Dictionary();
            projHp = new Dictionary();
            recDiagCnt = 0;
            recDoorCnt = 0;
            // 时停开始时已在飞的攻击体：**全部登记录像**（玩家方的也录——
            // 时停前抛出的手雷/导弹在回放中重演其慢速飞行轨迹；v1.87 之前
            // 只录敌人的，玩家的漏录导致"时停前在飞手雷未重演"）。玩家方
            // 同时留 preExistB 快照（endSandy 不清除，回放后继续飞行）。
            preExistB = new Dictionary();
            try
            {
               var oP2:Object = world.loc != null ? world.loc.firstObj : null;
               var gP2:int = 0;
               while (oP2 != null)
               {
                  try
                  {
                     if (flash.utils.getQualifiedClassName(oP2).indexOf("fe.weapon::") == 0)
                     {
                        try { if (oP2["owner"] == world.gg) { preExistB[oP2] = true; } } catch (e:*) { }
                        registerAtk(oP2);
                     }
                  }
                  catch (e:*) { }
                  oP2 = oP2.nobj;
                  if (++gP2 > 20000) break;
               }
            }
            catch (e:*) { }
            try
            {
               var oP:Object = world.loc != null ? world.loc.firstObj : null;
               var gP:int = 0;
               while (oP != null)
               {
                  try
                  {
                     if (oP["owner"] == world.gg && flash.utils.getQualifiedClassName(oP).indexOf("fe.weapon::") == 0)
                     {
                        preExistB[oP] = true;
                     }
                  }
                  catch (e:*) { }
                  oP = oP.nobj;
                  if (++gP > 20000) break;
               }
            }
            catch (e:*) { }
            rainbowIdx = 0;
            fxTicks = 0;
            replayDiagOnce = false;   // 回放开始诊断每轮重置
            recSitFrames = 0;         // v1.123：翻滚诊断计数重置
            recRollFrames = 0;
            recTotFrames = 0;
            rRollDiag = 0;
            rFixCnt = 0;               // 回放重钉诊断计数重置
            recDiagCnt = 0;            // 录像对象诊断计数重置
            playerAnimCat = 0;   // 回放玩家动画档位迟滞重置
            recPrevHold = -1;   // 开火记录基线重置
            recPrevTA = -1;
            recPrevWid = "";
            clearAllGhosts();   // 防上一轮残留的无限残影

            lastGhostX = world.gg.X;
            lastGhostY = world.gg.Y;
            if (ghostLayer == null)
            {
               ghostLayer = new Sprite();
            }
            else if (ghostLayer.parent != null)
            {
               ghostLayer.parent.removeChild(ghostLayer);
            }
            // 残影层插到玩家视觉层**下方**（v1.77：原 addChild 把残影叠在玩家
            // 本体之上——玩家显示在残影下层）。按玩家 vis 所在层（visObjs[sloy]）
            // 的索引前插，残影绘制在玩家本体之后（被本体遮挡）
            try
            {
               var pvParent:Object = world.gg.vis != null ? world.gg.vis.parent : null;
               var pvIdx:int = pvParent != null ? world.visual.getChildIndex(pvParent) : -1;
               if (pvIdx > 0) { world.visual.addChildAt(ghostLayer, pvIdx); }
               else { world.visual.addChild(ghostLayer); }
            }
            catch (e:*) { world.visual.addChild(ghostLayer); }
            log("[SandyMod] 斯安维斯坦 ON");
         }
         catch (err:*) { trace("[SandyMod] start error: " + err); }
      }

      private function endSandy():void
      {
         if (!sandyActive) return;
         sandyActive = false;
         // v1.123：翻滚诊断——时停结束报告录像中趴下/翻滚帧数（回放翻滚
         // 不重现时先看这里：sit=0=记录侧没录到；roll>0=驱动侧问题）
         if (cfgDiagLog)
         {
            log("[DIAG] rollRec: tot=" + recTotFrames + " sit=" + recSitFrames + " roll=" + recRollFrames);
         }
         // v1.82：时停前已在飞的玩家攻击体（手雷/导弹）——恢复时停中清零的
         // 伤害（回放中继续飞行并正常结算）。必须在 restorePredDead 清空
         // origDam 之前。
         try
         {
            for (var kPB:Object in origDam)
            {
               try
               {
                  if (kPB == null || origDam[kPB] == null || origDam[kPB] <= 0) continue;
                  // v1.91：恢复对象=时停前在飞攻击体（preExistB）+ 投掷武器
                  // 抛出的投掷物（时停中抛出、被保留续飞的——伤害被时停
                  // 清零循环清零，必须恢复才能在回放后正常爆炸）
                  var keepPB:Boolean = preExistB[kPB] != null;
                  try { if (!keepPB && kPB.weap != null && kPB.weap == world.gg["throwWeapon"]) { keepPB = true; } } catch (e:*) { }
                  if (!keepPB) continue;
                  kPB.damage = origDam[kPB];
                  try { if (kPB.damageExpl != null && kPB.damageExpl <= 0 && kPB.weap != null && kPB.weap.damageExpl != null) { kPB.damageExpl = kPB.weap.damageExpl; } } catch (e:*) { }
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
         // 预判死亡的敌人恢复存活（回放中真实结算死亡——时停的死亡动画只是预告）
         restorePredDead();
         // 清除时停期间的无限残影（回放开始，残影全部清场）
         clearAllGhosts();
         // 清除时停期间玩家发射的冻结子弹（回放重演攻击，避免双倍火力；
         // 时停前已在飞的不清除——回放继续飞行）
         clearFrozenBullets();
         // v1.100：回放前清空**全部**粒子——爆炸粒子寿命以世界步计（liv 可达
         // 100+，时停 1/5 速下到结束时仍在中途；快粒子可飞出 360px 半径），
         // 残留粒子在回放中继续播放=鬼影/第二个冲击波环（v1.97 FF 60 步与
         // v1.99 半径清除都杀不净）。回放世界冻结（无环境粒子重生），清空后
         // 回放画面干净；回放中的爆炸粒子由 boom 新生成，回放结束后环境
         // 粒子自然重生。
         // v1.108：改走 killPartsDeep——游戏 Part.setNull 不摘除 vis（Part.as:66
         // 只 remObj，从不调 Pt.remVisual），被杀的粒子 vis 遗留在 visObjs 层、
         // 钉在爆炸位置=回放鬼影（"从回放开始到爆炸结束"的亮光——visualFlare
         // 等爆炸视觉，R50/R100 扫描实证钉死不动）。深层清除=先 remVisual
         // 再 setNull + 显示树扫除自然死亡粒子的孤儿 vis。
         killPartsDeep(world.loc, "S");
         // 追踪器数组长度诊断（v1.88）：len=1 说明追加失败（对象"未重演"定位）
         try
         {
            for (var kE:Object in seenAtk)
            {
               var arrE:Array = replayObjs[kE];
               log("[DIAG] recEnd: cls=" + flash.utils.getQualifiedClassName(kE)
                   + " len=" + (arrE != null ? arrE.length : -1)
                   + " inChain=" + (kE.in_chain != null ? kE.in_chain : -1));
            }
         }
         catch (e:*) { }
         // 快照时停结束状态（回放结束后恢复：弹夹剩余=时停结束时，背包弹药不被回放消耗）
         buildSandyEndSnap();
         // 快照武器耐久/魔法值（回放重演会再次消耗——回放结束恢复，防双倍）
         try
         {
            endSnapWpnHp = world.gg.currentWeapon != null ? world.gg.currentWeapon.hp : -1;
            endSnapMana = world.gg["mana"] != null ? world.gg["mana"] : -1;
            // 手雷库存快照（v1.81：回放重演抛掷会二次消耗——结束恢复）
            gSnapKol = -1;
            try
            {
               var twG:* = world.gg["throwWeapon"];
               if (twG != null && twG.ammo != null && world.invent != null
                   && world.invent.items != null && world.invent.items[twG.ammo] != null)
               {
                  gSnapKol = world.invent.items[twG.ammo].kol;
               }
            }
            catch (e:*) { }
         }
         catch (e:*) { }

         try
         {
            // 回放期间世界冻结（场景级重演：敌人/物品不 step，由 replayObjects 重演；
            // 玩家手动 step 驱动攻击）——回放结束 endReplay 恢复 savedOnPause
            world.onPause = true;
            if (savedInter != null)
            {
               try { world.gg["inter"] = savedInter; } catch (e:*) { }
               savedInter = null;
            }
            // 结束时清理键状态（防残留）
            try
            {
               world.ctr.clearAll();
               var kd2:* = world.ctr["keyDowns"];
               if (kd2 != null)
               {
                  for (var ki2:int = 0; ki2 < kd2.length; ki2++) { kd2[ki2] = false; }
               }
            }
            catch (e:*) { }
            // 恢复玩家控制（防时停期间触发的 controlOff 锁死输入）
            try
            {
               if (world.gg.hp > 0 && world.gg.sost < 3)
               {
                  world.gg.controlOn();
               }
            }
            catch (e:*) { }
         }
         catch (e:*) { }
         replaying = true;
         replayIdx = 0;
         cooldownLeft = cfgCooldown;
         // ==== 真回放模式：玩家从起点沿历史路径快速重演（残影跟随玩家本体）====
         try
         {
            // godMode 已由 startSandy 保存（时停前值）——时停+回放全程无敌，结束恢复
            world.godMode = true;                 // 回放期间无敌（世界正常运行）
            savedGgCtrl = world.gg.ggControl;
            // 取消残留的武器切换动画流程（游戏 changeWeapon 冷却 30+20 帧，
            // 回放中武器切换必须立即生效、无冷却，否则动画流程会在回放中乱切武器）
            try
            {
               world.gg.work = "";
               world.gg.t_work = 0;
            }
            catch (e:*) { }
            // 回放开始切回时停开始时的武器（否则回放停留在时停结束时的最后武器）
            replayWpn = startWeapon;
            savedOtbros = -1;   // 重置击退原始值记录（回放中重新保存）
            switchToWeapon(startWeapon);
            if (history.length > 0)
            {
               world.gg.setPos(history[0].x, history[0].y);   // 传送回起点
               world.gg.setVisPos();
            }

         }
         catch (e:*) { log("[SandyMod] replay init error: " + e); }
         log("[SandyMod] 斯安维斯坦 OFF, replay " + history.length + " frames");
      }

      private function stepSandy():void
      {
         try
         {
            // 时停慢速世界（v1.56）帧序：
            // 1. 帧首：近战复用攻击体伤害清零（时停中命中 0 伤害，回放重演结算）
            // 2. 玩家手动 step（全速，每帧）
            // 3. 节流帧：调用真实 loc.step()（世界真慢速运行——移动/计时/AI/交互检测
            //    一致 1/N 速；玩家在 loc.step 内会被再步一次，预先清键使其为
            //    "自由物理步"，步后恢复按键）
            // 4. 记录历史（玩家最终位置）+ 场景录像
            freezeMeleeDamage();
            var wantA:Boolean = false;
            var wantP:Boolean = false;
            try
            {
               // 鼠标脉冲：同帧 DOWN+UP 的快速连点也能记录（按住由 mouseAtkDown 持续）
               wantA = world.ctr.keyAttack || mouseAtkDown || mouseAtkPulse;
               wantP = world.ctr.keyPunch;
            }
            catch (e:*) { }
            mouseAtkPulse = false;   // 脉冲每帧消费一次
            var loc:Object = world.loc;
            loc.gg.step();   // 玩家全速手动 step
            freezeMeleeDamage(); // 本帧新挥击先存伤害，随后帧的接触才记账
            // v1.115：敌人斯安维斯坦（场景 B）——活跃 Sandy 敌人与玩家同权
            // 每帧全速 step（敌我"正常关系"，其余世界 1/N 慢放）；节流帧的
            // loc.step 会再步到它一次（1/N 慢步）——与玩家"自由物理步"同款
            // 现象（净 ~1.2×），接受并记录。
            try { stepEnemySandyB(); } catch (e:*) { }
            // 单步后的武器状态（节流帧第二遍步会再递减一次——用单步值做开火检测，
            // 否则小攻速武器（rapid 1-2）的开火帧记录值与上一帧相同，上升沿检测不到）
            var tAManual:int = world.gg.currentWeapon != null ? world.gg.currentWeapon.t_attack : 0;
            var holdManual:Number = world.gg.currentWeapon != null ? world.gg.currentWeapon.hold : -1;
            // 真实开火逐帧记录（v1.72）：同武器相邻帧弹夹下降=子弹真实生成
            // （shoot() 内 hold-=rashod）；t_attack 上升沿兜底（近战/无弹药武器/
            // recyc 不耗弹）。换武器帧 t_attack>0 视为该帧开火（卸下时 setNull
            // 清零 t_attack，切换后为正=本帧初始化）。每帧 0/1 发记录进历史，
            // 回放直接累加——根除窗口边缘检测导致的吞攻击。
            var cwRec:* = world.gg.currentWeapon;
            var widRec:String = cwRec != null ? cwRec.id : "";
            var dHRec:int = 0;
            var tAEdgeRec:Boolean = false;
            if (cwRec != null)
            {
               if (widRec == recPrevWid)
               {
                  if (recPrevHold >= 0 && holdManual >= 0 && recPrevHold > holdManual)
                  {
                     dHRec = recPrevHold - holdManual;
                  }
                  if (recPrevTA >= 0 && tAManual > recPrevTA) { tAEdgeRec = true; }
               }
               else if (tAManual > 0 && recPrevWid != "")
               {
                  // 换武器帧即开火：新武器 t_attack>0（卸下时 setNull 清零）=
                  // 本帧初始化。recPrevWid!="" 排除时停首帧（进入时停前残留
                  // 的冷却不能算本帧开火）
                  tAEdgeRec = true;
               }
               recPrevWid = widRec;
               recPrevHold = holdManual;
               recPrevTA = tAManual;
            }
            else
            {
               recPrevWid = "";
               recPrevHold = -1;
               recPrevTA = -1;
            }
            var rashodRec:int = 1;
            try { if (cwRec != null && cwRec.rashod != null) { rashodRec = cwRec.rashod; } } catch (e:*) { }
            if (rashodRec < 1) { rashodRec = 1; }
            var fcRec:int = (dHRec >= rashodRec || tAEdgeRec) ? 1 : 0;
            // 攻击体追踪登记（v1.85）：玩家步后立即扫描登记新生成的攻击体
            // （按引用录像，绕开链扫描之谜）
            try
            {
               var oNA:Object = loc.firstObj;
               var gNA:int = 0;
               while (oNA != null)
               {
                  try
                  {
                     if (oNA["owner"] == world.gg && seenAtk[oNA] == null
                         && flash.utils.getQualifiedClassName(oNA).indexOf("fe.weapon::") == 0)
                     {
                        registerAtk(oNA);
                     }
                  }
                  catch (e:*) { }
                  oNA = oNA.nobj;
                  if (++gNA > 20000) break;
               }
            }
            catch (e:*) { }
            slowTick++;
            var isThr:Boolean = (slowTick % cfgSlowFactor == 0);
            if (isThr)
            {
               slowStepWorld();   // 真实 loc.step()：世界 1/N 速步进（含交互检测）
            }
            // v1.98：MC 型粒子每显示帧 stop、节流帧（世界步帧）nextFrame 推 1 帧
            // ——爆炸动画 1/N 慢速播放且不循环（修复"时停中爆炸动画多次加载"）
            mcStepParts(loc, isThr);

            var gg:Object = loc.gg;
            // 记录攻击键状态与瞄准方向（回放时攻击指向时停期间的发射方向）
            // v1.120：追加 si（趴下/蹲下 isSit）与 an（animState）——回放动画
            // 驱动据此重现翻滚（roll）/趴下（down/polz）/起身（up）等非移动
            // 动画（dx 量化只覆盖走/跑/小跑，翻滚永远不出现——用户实测）。
            // v1.130：追加 bl（vis.osn.currentFrameLabel）+bf（vis.osn.body
            // currentFrame）——回放按帧直接快照玩家身体（帧级忠实重演，
            // 彻底解决"起始/结束姿势不一致时动画错乱"；不再依赖状态机重算）。
            var blRec:String = "";
            var bfRec:int = 0;
            try
            {
               if (gg.vis != null && gg.vis["osn"] != null)
               {
                  blRec = String(gg.vis["osn"].currentFrameLabel);
                  try { if (gg.vis["osn"]["body"] != null) { bfRec = int(gg.vis["osn"]["body"].currentFrame); } } catch (e:*) { }
               }
            }
            catch (e:*) { }
            history.push({ x: gg.X, y: gg.Y, s: gg.storona, r: gg.vis != null ? gg.vis.rotation : 0, v: gg.vis != null ? gg.vis.scaleX : 1,
                           a: wantA, p: wantP, g: world.ctr.keyGrenad, m: world.ctr.keyMagic,
                           ax: world.celX, ay: world.celY,
                           w: world.gg.currentWeapon != null ? world.gg.currentWeapon.id : "",
                           wx: world.gg.currentWeapon != null ? world.gg.currentWeapon.X : 0,
                           wy: world.gg.currentWeapon != null ? world.gg.currentWeapon.Y : 0,
                           wrot: world.gg.currentWeapon != null ? world.gg.currentWeapon.rot : 0,
                           tA: tAManual, hold: holdManual, fc: fcRec,
                           tx: world.gg.teleObj != null ? world.gg.teleObj.X : 0,
                           ty: world.gg.teleObj != null ? world.gg.teleObj.Y : 0,
                           si: gg.isSit, an: gg.animState, bl: blRec, bf: bfRec,
                           ci: speedToEdgeIdx(Math.abs(gg.dx) + Math.abs(gg.dy)) });
            // v1.123：翻滚诊断——统计录像中趴下/翻滚帧数（回放不重现时
            // 先看记录侧有没有录到：sit=0 说明记录侧问题，roll>0 说明驱动侧）
            recTotFrames++;
            try { if (gg.isSit) { recSitFrames++; } } catch (e:*) { }
            try { if (gg.animState == "roll") { recRollFrames++; } } catch (e:*) { }
            // 记录重演状态（场景级录像：敌人/物品/攻击体每帧位置+动画帧+生成音效）
            recordReplayObjects();
            // 时停攻击状态诊断（每 30 帧）：观察时停中攻击意图与武器状态；
            // nPb=loc 中玩家攻击体计数（定位录像 atk=0 之谜——子弹为何不被录制）
            if (++sandyAtkTick % 30 == 0)
            {
               try
               {
                  var cwS:* = world.gg.currentWeapon;
                  var nPb:int = 0;
                  var oPB:Object = world.loc != null ? world.loc.firstObj : null;
                  var gPB:int = 0;
                  while (oPB != null)
                  {
                     try
                     {
                        if (oPB["owner"] == world.gg && flash.utils.getQualifiedClassName(oPB).indexOf("fe.weapon::") == 0) { nPb++; }
                     }
                     catch (e:*) { }
                     oPB = oPB.nobj;
                     if (++gPB > 20000) break;
                  }
                  log("[DIAG] sAtk: wantA=" + wantA + " wantP=" + wantP
                      + " A=" + world.ctr.keyAttack + " mouse=" + mouseAtkDown + " pulse=" + mouseAtkPulse
                      + " tA=" + (cwS != null ? cwS.t_attack : -1)
                      + " cw=" + (cwS != null ? flash.utils.getQualifiedClassName(cwS) : "none")
                      + " nPb=" + nPb);
               }
               catch (e:*) { }
            }
            // 时停敌人移动诊断（每 60 帧）：验证节流 step 是否生效（敌人位置应变化）
            if (++sandyEnemyTick % 60 == 0)
            {
               try
               {
                  var oE2:Object = world.loc.firstObj;
                  var gE2:int = 0;
                  while (oE2 != null)
                  {
                     var nxE2:Object = oE2.nobj;
                     try
                     {
                        if (oE2 != world.gg && oE2["setPos"] != null)
                        {
                           log("[DIAG] sEnemy: X=" + oE2.X + " Y=" + oE2.Y + " cls=" + flash.utils.getQualifiedClassName(oE2));
                           break;
                        }
                     }
                     catch (e:*) { }
                     oE2 = nxE2;
                     if (++gE2 > 20000) break;
                  }
               }
               catch (e:*) { }
            }


            fxTicks++;
            if (fxTicks >= cfgGhostEvery)
            {
               fxTicks = 0;
               spawnGhost(gg, ghostColor(Math.abs(gg.dx) + Math.abs(gg.dy)));
            }
            if (diagTick++ % 30 == 0)
            {
               var cam:Object = world.cam;
               log("[DIAG] cam: vx=" + cam.vx + " vy=" + cam.vy + " scaleV=" + cam.scaleV
                   + " visual.x=" + world.visual.x + " visual.y=" + world.visual.y
                   + " visual.scaleX=" + world.visual.scaleX + " visual.scaleY=" + world.visual.scaleY
                   + " gg.vis.parent=" + gg.vis.parent + " ghostLayer.numChildren=" + ghostLayer.numChildren);
            }

            if (cfgFxRun)
            {
               // v1.75：粒子只随节流帧（loc.step）步进 = 1/N 慢速——与"世界真
               // 慢速运行"一致；炮塔预判死亡的爆炸粒子自然慢放（慢动作爆炸）。
               // 每帧仍维护发射器计数（World.step 守卫内的重置由模组代做）
               resetFxCounter();
            }

            // [DIAG] jump simulation: every 60 frames press jump for 3 frames
            diagTick++;
            if (debugTest)
            {
               if (diagTick % 60 < 3)
               {
                  world.ctr.keyJump = true;
               }
               else if (diagTick % 60 == 3)
               {
                  log("[DIAG] jump pressed, Y=" + gg.Y + " dy=" + gg.dy + " stay=" + gg.stay);
               }
               else if (diagTick % 60 == 10)
               {
                  log("[DIAG] after jump 7f: Y=" + gg.Y + " dy=" + gg.dy + " stay=" + gg.stay + " jumpp=" + gg.jumpp
                      + " maxjumpp=" + gg.maxjumpp + " dash_t=" + gg.dash_t + " dash_maxt=" + gg.dash_maxt
                      + " isJump=" + gg.isJump + " isLaz=" + gg.isLaz + " jumpNumb=" + gg.jumpNumb);
               }
            }

            --sandyLeft;
            if (sandyLeft <= 0)
            {
               endSandy();
            }
         }
         catch (err:*) { log("[SandyMod] stepSandy error: " + err); endSandy(); }
      }

      // 只步进链表中是粒子的对象（Part 类），并维护 Emitter 计数
      private function stepParticles(loc:Object):void
      {
         var PartClass:Class = null;
         try { PartClass = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class; } catch (e:*) { return; }
         var EmitterClass:Class = null;
         try { EmitterClass = ApplicationDomain.currentDomain.getDefinition("fe.graph.Emitter") as Class; } catch (e:*) { }
         if (EmitterClass != null)
         {
            EmitterClass["kol2"] = EmitterClass["kol1"];
            EmitterClass["kol1"] = 0;
         }
         var obj:Object = loc.firstObj;
         var guard:int = 0;
         while (obj != null)
         {
            var nxt:Object = obj.nobj;
            if (obj is PartClass)
            {
               // v1.113：移除 v1.104 的寿命钳制（liv>20 压到 20）——钳制把
               // 长寿命爆炸粒子压缩播放：野火核弹 balefire 60 帧压成 20 帧
               // =3 倍速（用户实测"播放速度有些快，野火核弹尤为明显"；
               // baleblast 30→20=1.5 倍）。v1.111/1.112 起未播完的爆炸在
               // 回放结束后自然续播，长寿命粒子不再需要压缩到回放内完结——
               // 回放中按原生 liv 以 1 世界步/显示帧正常播放，剩余部分在
               // 回放后由世界恢复步进自然播完（原生速度、原生时长）。
               try
               {
                  obj.step();
               }
               catch (e2:*)
               {
                  // v1.105：单粒子 step 异常不打断整链步进（异常=粒子冻结
                  // 到回放结束才被世界步进=鬼影候选），记录首个异常
                  if (partErrCnt < 3)
                  {
                     partErrCnt++;
                     log("[DIAG] partErr: cls=" + flash.utils.getQualifiedClassName(obj) + " err=" + e2);
                  }
               }
            }
            obj = nxt;
            if (++guard > 20000) break;
         }
      }

      // ===== 时停中 MovieClip 型粒子慢放（v1.98）=====
      // 游戏 Part 视觉分两类：Blit 型（blitData!=null，blitFrame 随 step 推进
      // ——已随世界 1/N 慢速）与 MovieClip 型（vClass，initVis 后 gotoAndPlay：
      // 播放头按**舞台帧率**推进，与时停慢速无关）。爆炸动画几十帧数秒播完，
      // 而粒子寿命 liv 以世界步计被拉长 5 倍——MC 播完即循环重播 = 用户所见
      // "时停中爆炸动画多次加载"。修复：每显示帧 stop()（防按舞台帧率播放），
      // 节流帧（世界步帧）手动 nextFrame() 推 1 帧——爆炸动画 1/N 慢速播放，
      // 播完停在末帧不循环。
      private function mcStepParts(loc:Object, advance:Boolean):void
      {
         try
         {
            var PartClass:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class;
            if (PartClass == null) return;
            var objP:Object = loc.firstObj;
            var guardP:int = 0;
            var mcN:int = 0;
            var blN:int = 0;
            var clsS:String = "";
            while (objP != null)
            {
               var nxtP:Object = objP.nobj;
               try
               {
                  if (objP is PartClass && objP.vis != null)
                  {
                     var isAnimP:* = objP.isAnim;
                     if (isAnimP != null && isAnimP > 0)
                     {
                        if (objP.blitData == null)
                        {
                           // MovieClip 型：stop + 世界步帧手动推进（不循环）
                           mcN++;
                           if (mcN <= 3)
                           {
                              try { clsS += (clsS != "" ? "," : "") + flash.utils.getQualifiedClassName(objP.vis); } catch (e:*) { }
                           }
                     try { objP.vis.stop(); } catch (e:*) { }
                     if (advance)
                     {
                        try
                        {
                           var otkP:* = objP.otklad;
                           if ((otkP == null || otkP <= 0) && objP.vis.visible == true
                               && objP.vis.currentFrame < objP.vis.totalFrames)
                           {
                              objP.vis.nextFrame();
                              // v1.103：回放中爆炸 MC **播完即杀**——动画结束=
                              // 火光消失。用户实测"火光一直留到爆炸结束才消失"：
                              // MC 停在末帧后粒子 liv 仍余数十帧（回放仅 ~1.4 秒，
                              // 火光滞留整个回放=鬼影）。时停中保持 v1.98 行为
                              // （慢放+停末帧，已确认正常）。
                              if (replaying && objP.vis.currentFrame >= objP.vis.totalFrames)
                              {
                                 // v1.108：先摘 vis 再杀——setNull 不摘除 vis
                                 //（Part.as:66），播完即杀的 MC vis 会遗留在图层
                                 try { objP.remVisual(); } catch (e:*) { }
                                 try { objP.setNull(); } catch (e:*) { }
                              }
                           }
                        }
                        catch (e:*) { }
                     }
                        }
                        else
                        {
                           blN++;   // Blit 型：随 step 慢速，不处理
                        }
                     }
                  }
               }
               catch (e:*) { }
               objP = nxtP;
               if (++guardP > 20000) break;
            }
            // 诊断（每轮时停一次，首个出现动画粒子的帧）：确认爆炸粒子视觉
            // 类型分布（MC/Blit）+ MC 类名样本——定位"多次加载"的 Part 类型
            if (!partDiagOnce && (mcN > 0 || blN > 0))
            {
               partDiagOnce = true;
               log("[DIAG] parts: mc=" + mcN + " blit=" + blN + " mcCls=" + clsS);
            }
         }
         catch (e:*) { }
      }

      // ==================== 回放 ====================
      // ===== v1.108：粒子深层清除（鬼影根治）=====
      // 根因：游戏 Part.setNull（Part.as:66）只 loc.remObj 出链，**从不摘除 vis**
      // （Pt.remVisual 存在但死亡路径不调用）——正常游戏中这些孤儿 vis 由
      // Grafon.setLight→drawAllObjs（Grafon.as:681/703，爆炸破坏瓦片触发光照
      // 重算）重建图层时抹掉；时停+回放世界冻结期间没有重建：时停中爆炸粒子
      // 自然死亡或被 partsKill 杀死后，vis 冻结在爆炸位置（visualFlare 亮光等）
      // =用户所见"回放开始到爆炸结束"的钉死鬼影（v1.107 ghostScan R50/R100
      // 实证：爆炸坐标 (1028.8,299.3) 上 visualFlare+2MC 全程可见，boom 爆炸
      // 破坏瓦片→drawAllObjs 重建图层才消失——与用户"爆炸结束后鬼影消失"
      // 完全吻合）。
      // 修复：①链上每个 Part 先 remVisual 再 setNull（被杀粒子的 vis 一并摘除）；
      // ②显示树扫除——时停中**自然死亡**粒子的 vis（其 Part 已出链，①够不到），
      // 按已知粒子视觉类名集合（AllData <part vis='...'> 清单，v1.02 静态数据）
      // 从 visObjs 各图层移除。
      private var partVisSet:Object = null;
      private function buildPartVisSet():void
      {
         if (partVisSet != null) return;
         partVisSet = {};
         var arrP:Array = ["visualFlare", "visualBum", "visualBumAcid", "visualBumNecro", "visualBlast",
            "visualPlaExpl", "visualImpExpl", "visualIceExpl", "visualSparkleExpl", "visualBaleblast",
            "visualAcidExpl", "visualEclipse", "visualMiniexpl", "visualThrow", "visualBloodblast",
            "visualBloodblast2", "visualNecrblast", "visualNecrblast2", "visualNecrblast3",
            "visualGilza", "visualFlame", "visualTeleFlare", "visualIceFlare", "visualGas",
            "visualPinkGas", "visualKusok", "visualKusokB", "visualKusokD", "visualSteklo",
            "visualKusoch", "visualKusochB", "visualSchep", "visualSchepoch", "visualMetal",
            "visualPole", "visualPole2", "visualBur", "visualPlav", "visualFake", "visualGwall",
            "visualSnow", "visualAcid", "visualSteam", "visualDischarge", "visualShmatok",
            "visualBlack", "visualPoison", "visualStun", "visualSlow", "visualBlind", "visualTele",
            "visualRadioblast", "visualQuake", "visualNecroNoise", "visualZzz", "visualRedRay",
            "visualVsos", "visualBubble", "visualElectro", "visualNoise", "visualSign1",
            "visualMarker", "visualNumb", "visualMagSymbol", "flPlasma", "flPlasma2", "flLaser",
            "flLaser2", "flSpark", "flSparkl", "flDray", "flPlevok", "flPinkPlevok", "flUnlock",
            "flMoln", "flGreen", "flRed", "PlasmaKap", "die_spark", "bloat_kap", "purple_spark",
            "green_spark", "gold_spark", "blue_spark", "orange_spark", "visReplic", "visReplic2",
            "visBulb"];
         for (var iP:int = 0; iP < arrP.length; iP++) { partVisSet[arrP[iP]] = true; }
      }
      private function killPartsDeep(locP:Object, tag:String):void
      {
         buildPartVisSet();
         var nK:int = 0;
         try
         {
            var PartCls:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class;
            if (PartCls != null)
            {
               var oPK:Object = locP.firstObj;
               var gPK:int = 0;
               while (oPK != null)
               {
                  var nxPK:Object = oPK.nobj;
                  try
                  {
                     if (oPK is PartCls)
                     {
                        try { oPK.remVisual(); } catch (e:*) { }
                        try { oPK.setNull(); } catch (e:*) { }
                        nK++;
                     }
                  }
                  catch (e:*) { }
                  oPK = nxPK;
                  if (++gPK > 20000) break;
               }
            }
         }
         catch (e:*) { }
         var nV:int = sweepOrphanPartVis();
         log("[DIAG] partsKillDeep" + tag + ": killed=" + nK + " vis=" + nV);
      }
      // 显示树扫除（倒序遍历，边遍历边移除）：**孤儿**粒子 vis——
      // 类名属于粒子视觉类、且**不属于任何活粒子**的 vis（游戏 Part.setNull
      // 不摘除 vis——正常游戏靠 drawAllObjs 图层重建抹掉，冻结/慢速世界里
      // 需要显式扫除）。
      // v1.112：先收集活粒子的 vis 集合、扫除时跳过——v1.111 的扫除把
      // 回放末段**活粒子**的 vis 也摘了=爆炸动画在回放结束瞬间消失
      // （日志实证：partsAlive n=17 且 boom 在 replIdx=210，partsResumeE
      // vis=6——活粒子丢 vis 后无声死亡）。
      private function sweepOrphanPartVis():int
      {
         buildPartVisSet();
         var liveVis:Dictionary = new Dictionary();
         try
         {
            var PartCls:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class;
            if (PartCls != null)
            {
               var oL:Object = world.loc.firstObj;
               var gL:int = 0;
               while (oL != null)
               {
                  try
                  {
                     if (oL is PartCls && oL.vis != null) { liveVis[oL.vis] = true; }
                  }
                  catch (e:*) { }
                  oL = oL.nobj;
                  if (++gL > 20000) break;
               }
            }
         }
         catch (e:*) { }
         var nV:int = 0;
         try
         {
            var gVisK:Object = world["grafon"];
            if (gVisK != null && gVisK.visObjs != null)
            {
               for (var slK:int = 0; slK < 8; slK++)
               {
                  var layK:Object = gVisK.visObjs[slK];
                  if (layK == null) continue;
                  try
                  {
                     for (var ciK:int = layK.numChildren - 1; ciK >= 0; ciK--)
                     {
                        var chK:* = layK.getChildAt(ciK);
                        if (chK == null) continue;
                        var qnK:String = "";
                        try { qnK = flash.utils.getQualifiedClassName(chK); } catch (e:*) { }
                        if (partVisSet[qnK] == true && liveVis[chK] != true)
                        {
                           try { layK.removeChild(chK); nV++; } catch (e:*) { }
                        }
                     }
                  }
                  catch (e:*) { }
               }
            }
         }
         catch (e:*) { }
         return nV;
      }
      // ===== v1.111：回放结束不再清空粒子——未播完的爆炸动画自然播完 =====
      // 此前 endReplay 走 killPartsDeep：回放末段 boom 生成的爆炸粒子被瞬间
      // 清除（用户实测"未播完的爆炸动画回放结束后直接被清除"）。现在回放
      // 结束后世界恢复步进，粒子按剩余 liv 自然死亡；MC 型粒子恢复 play()
      // （回放中 mcStepParts 曾 stop+手动推帧，不恢复会冻在末帧）。
      // v1.113：回放中不再钳制 liv——长寿命粒子（野火核弹 balefire 60）按
      // 原生时长播放，回放后自然续播至完结（原生速度）。
      // 孤儿 vis 扫除保留（回放中自然死亡粒子的 vis 清理）。
      private function resumePartsAtEnd():void
      {
         var nR:int = 0;
         try
         {
            var PartCls:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class;
            if (PartCls != null)
            {
               var oPK:Object = world.loc.firstObj;
               var gPK:int = 0;
               while (oPK != null)
               {
                  var nxPK:Object = oPK.nobj;
                  try
                  {
                     if (oPK is PartCls && oPK.vis != null && oPK.blitData == null
                         && oPK.isAnim != null && oPK.isAnim > 0)
                     {
                        try { oPK.vis.play(); nR++; } catch (e:*) { }
                     }
                  }
                  catch (e:*) { }
                  oPK = nxPK;
                  if (++gPK > 20000) break;
               }
            }
         }
         catch (e:*) { }
         var nV:int = sweepOrphanPartVis();
         log("[DIAG] partsResumeE: resumed=" + nR + " vis=" + nV);
      }
      // ===== v1.115：敌人斯安维斯坦（Enemy Sandevistan）=====
      // 触发：敌人 AI 看到玩家进入战斗（celUnit==world.gg 上升沿——aiState 是
      // internal 读不到，celUnit 是 public 的"已锁定玩家为目标"信号）后立即
      // 开启；持续 cfgESDur 帧、冷却 cfgESCd 帧；白名单类名配置；每房间名额
      // = 候选敌人数 × esandyper%（v1.119 起默认 50=一半；esRoomCnt 计数，
      // 死亡后释放名额）。
      // 场景 A（玩家未开）：世界正常，模组在游戏步进后给活跃敌人补
      // (spd-1) 次 step() → AI/移动/攻击 N×；敌人子弹 1×（世界步进）。
      // 场景 B（玩家同时开）：stepSandy 内活跃敌人与玩家同权每帧 step 一次。
      // 调试徽标："S"（待机绿/激活黄/冷却灰）v1.119 起挂在 grafon.visual
      // 顶层专用容器（免疫 drawAllObjs 每帧换图层 Sprite 与其它模组的图层
      // 重建），非 goldstar（不设 hero，不影响精英怪判定）。
      private function stepEnemySandy():void
      {
         var locE:Object = world.loc;
         if (locE == null) return;
         // ---- v1.124：换房间即清空敌方状态 ----
         // loc=每房间一个（Land.newLoc 实证），但 grafon.visual 是全局单例：
         // 旧房间的徽标 TextField 挂在共享层上会漏进新房间显示（"绝对没有
         // 敌人存在过的房间也有 S"的根因）；esRoomCnt 跨房间残留还会吃掉
         // 新房间名额（掠夺者房无 S 的嫌疑之一）。检测到 loc 变化时清空
         // 注册表/徽标/名额并重开房间级诊断。
         if (esLastLoc != locE)
         {
            esLastLoc = locE;
            var kmA:Array = [];
            for (var kM:Object in esMarks)
            {
               try { kmA.push(kM); } catch (e:*) { }
            }
            for each (var kX:Object in kmA)
            {
               try { removeESMark(kX); } catch (e:*) { }
            }
            esEnemies = new Dictionary();
            esRoomCnt = {};
            esQuotaDiag = 0;
            esCreateDiag = 0;
            // v1.131：换房间掷一次"本房间是否出现斯安维斯坦敌人"（概率
            // esandyroomprob%）——结合总开关 cfgESEnabled；本房间不掷中则
            // 整个房间跳过生成（esandyenabled=0 时恒不生成）
            esRoomAllow = cfgESEnabled && (cfgESRoomProb >= 100 || Math.random() * 100 < cfgESRoomProb);
            if (cfgDiagLog && esDiagCnt < 24)
            {
               esDiagCnt++;
               var rIdN:String = "";
               try { if (locE.room != null && locE.room.id != null) { rIdN = String(locE.room.id); } } catch (e:*) { }
               log("[DIAG] esandy: roomChange id=" + rIdN + " allow=" + (esRoomAllow ? 1 : 0) + " prob=" + cfgESRoomProb + " en=" + (cfgESEnabled ? 1 : 0));
            }
         }
         // v1.131：总开关关闭 / 本房间未掷中 → 整个房间不生成斯安维斯坦敌人
         if (!esRoomAllow) return;
         // ---- 0. v1.119：预扫描本房间候选数 → 名额 = 候选 × esandyper%（每房间一半）----
         var quotaE:int = 0;
         try
         {
            if (cfgESPer > 0)
            {
               var candE:int = 0;
               var oC:Object = locE.firstObj;
               var gC:int = 0;
               while (oC != null)
               {
                  var nxC:Object = oC.nobj;
                  try
                  {
                     if (oC != world.gg)
                     {
                        var qnC:String = flash.utils.getQualifiedClassName(oC);
                        // v1.124：去掉 currentWeapon 条件——白名单本身就是
                        // 敌对人类（掠夺者/狮鹫/天角兽/英克雷/铁骑卫/斑马），
                        // 无需再用武器字段过滤；无武器/武器加载失败的掠夺者
                        // 此前被静默排除=掠夺者房 cand=0 无 S 的嫌疑之二
                        if (qnC.indexOf("fe.unit::") == 0
                            && esClasses.indexOf(qnC) >= 0)
                        {
                           // v1.123：排除死亡/尸体（sost>=3）——此前尸体也算
                           // 候选：名额被尸体占掉=活敌无标记、S 飘在"没有敌人
                           // 的地方"（用户实测"随机算法选中了非敌人实体"）
                           var sostC:int = 0;
                           try { sostC = int(oC["sost"]); } catch (e:*) { }
                           if (sostC >= 3)
                           {
                              oC = nxC;
                              if (++gC > 20000) break;
                              continue;
                           }
                           candE++;
                        }
                     }
                  }
                  catch (e:*) { }
                  oC = nxC;
                  if (++gC > 20000) break;
               }
               quotaE = Math.round(candE * cfgESPer / 100);
               if (candE > 0 && quotaE < 1) quotaE = 1;
               if (cfgDiagLog && esQuotaDiag < 6)
               {
                  esQuotaDiag++;
                  log("[DIAG] esandy: room cand=" + candE + " per=" + cfgESPer + " quota=" + quotaE);
               }
            }
         }
         catch (e:*) { }
         // ---- 1. 扫描登记 + 战斗触发检测 + 状态推进 ----
         try
         {
            var oE:Object = locE.firstObj;
            var gE:int = 0;
            while (oE != null)
            {
               var nxE:Object = oE.nobj;
               try
               {
                  if (oE != world.gg)
                  {
                     var qnE:String = flash.utils.getQualifiedClassName(oE);
                     if (qnE.indexOf("fe.unit::") == 0
                         && esClasses.indexOf(qnE) >= 0)
                     {
                        // v1.123：跳过死亡/尸体（sost>=3）——尸体不注册、
                        // 徽标不跟随尸体（"没有敌人的地方出现 S"的根因）
                        var sostE:int = 0;
                        try { sostE = int(oE["sost"]); } catch (e:*) { }
                        if (sostE >= 3)
                        {
                           oE = nxE;
                           if (++gE > 20000) break;
                           continue;
                        }
                        var recE:Object = esEnemies[oE];
                        if (recE == null)
                        {
                           // v1.119：每房间名额 = 候选 × esandyper%（默认一半）；
                           // 名额按登记顺序发放（esRoomCnt 计数）
                           var rIdE:String = "";
                           try { if (locE.room != null && locE.room.id != null) { rIdE = String(locE.room.id); } } catch (e:*) { }
                           var takenE:int = 0;
                           if (rIdE != "")
                           {
                              var tvE:* = esRoomCnt[rIdE];
                              if (tvE != null && tvE != undefined) { takenE = int(tvE); }
                           }
                           if (takenE >= quotaE)
                           {
                              oE = nxE;
                              if (++gE > 20000) break;
                              continue;
                           }
                           recE = { st: 0, left: 0, cd: 0, px: 0, py: 0 };
                           esEnemies[oE] = recE;
                           if (rIdE != "") { esRoomCnt[rIdE] = takenE + 1; }
                           try { recE.px = oE.X; recE.py = oE.Y; } catch (e:*) { }
                        }
                         // 战斗信号：celUnit==gg 且待机（无冷却中）→ 立即触发。
                         // v1.126：去掉 sawCel 上升沿要求——玩家持续保持在视野内时，
                         // 敌人冷却结束（st 2→0）后必须能重新触发；上升沿只在敌人
                         // 初次看见玩家的那一帧成立，之后 sawCel 恒 true，敌人
                         // 再也不会第二次开启斯安维斯坦（用户实测）。去掉门槛后，
                         // 已处于战斗中的敌人（含注册时已锁定玩家）也能正常触发。
                         var celE:* = null;
                         try { celE = oE["celUnit"]; } catch (e:*) { }
                         var inCombatE:Boolean = (celE == world.gg);
                         if (inCombatE && recE.st == 0)
                         {
                            recE.st = 1;
                            recE.left = cfgESDur;
                            if (cfgDiagLog && esDiagCnt < 12)
                            {
                               esDiagCnt++;
                               log("[DIAG] esandy: cls=" + qnE + " room=" + rIdE + " ON dur=" + cfgESDur + " spd=" + cfgESSpd);
                            }
                         }
                        esTick(oE, recE);
                        updateESMark(oE, recE.st);
                        esShineGuard(oE);   // v1.128：斑马 shine 回充（防隐形）
                        esInvScan(oE, recE);  // v1.129：敌人在隐形瞬间就地记录
                     }
                  }
               }
               catch (e:*) { }
               oE = nxE;
               if (++gE > 20000) break;
            }
         }
         catch (e:*) { }
         // ---- 2. 清理死亡/出链的注册敌人（先收集后删除）----
         try
         {
            var rmE:Array = [];
            for (var kC:Object in esEnemies)
            {
               try
               {
                  // v1.123：死亡/尸体（sost>=3）也移除——徽标不再滞留尸体上方
                  var deadC:Boolean = false;
                  try { deadC = int(kC["sost"]) >= 3; } catch (e:*) { }
                  if (kC == null || kC.in_chain != true || deadC)
                  {
                     rmE.push(kC);
                  }
               }
               catch (e:*) { }
            }
            for each (var kR:Object in rmE)
            {
               try { removeESMark(kR); } catch (e:*) { }
               try { delete esEnemies[kR]; } catch (e:*) { }
               try
               {
                  var rIdC:String = "";
                  if (locE.room != null && locE.room.id != null) { rIdC = String(locE.room.id); }
                  if (rIdC != "")
                  {
                     var cvC:* = esRoomCnt[rIdC];
                     if (cvC != null && cvC != undefined)
                     {
                        esRoomCnt[rIdC] = Math.max(0, int(cvC) - 1);
                     }
                  }
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
         // ---- 3. 场景 A：活跃敌人补步（游戏已步 1 次，再补 spd-1 次）+ 残影 ----
         try
         {
            for (var kA:Object in esEnemies)
            {
               try
               {
                  var recA:Object = esEnemies[kA];
                  if (recA == null || recA.st != 1 || kA == null || kA.in_chain != true) continue;
                  for (var iE:int = 1; iE < cfgESSpd; iE++)
                  {
                     try { kA.step(); } catch (e:*) { }
                  }
                  esGhostFor(kA, recA);
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
      }
      // 状态推进（场景 A/B 共用）
      private function esTick(oE:Object, recE:Object):void
      {
         if (recE.st == 1)
         {
            recE.left--;
            if (recE.left <= 0)
            {
               recE.st = 2;
               recE.cd = cfgESCd;
               if (cfgDiagLog && esDiagCnt < 24)
               {
                  esDiagCnt++;
                  log("[DIAG] esandy: cls=" + flash.utils.getQualifiedClassName(oE) + " OFF cd=" + cfgESCd
                      + " " + esVisState(oE));
               }
            }
         }
         else if (recE.st == 2)
         {
            recE.cd--;
            // v1.128：敌人斯安维斯坦结束后隐身——冷却前 3 帧记录敌人视觉状态
            //（visible/parent 是否在显示树/alpha/sost/disabled/invis）定位隐身点
            if (cfgDiagLog && esOffVisDiag < 12)
            {
               esOffVisDiag++;
               log("[DIAG] esandy: cdVis cls=" + flash.utils.getQualifiedClassName(oE)
                   + " cd=" + recE.cd + " " + esVisState(oE));
            }
            if (recE.cd <= 0) { recE.st = 0; }
         }
      }
      // v1.128：敌人视觉状态摘要（定位"斯安维斯坦结束后隐身"）
      private function esVisState(oE:Object):String
      {
         var s:String = "vis=-";
         try
         {
            var v:* = oE.vis;
            if (v == null) { return "vis=null"; }
            var onSt:String = "-";
            var par:String = "-";
            try { par = v.parent != null ? String(v.parent) : "null"; } catch (e:*) { }
            try
            {
               var stg:Boolean = false;
               var n:Object = v;
               while (n != null)
               {
                  if (n["stage"] != null) { stg = true; break; }
                  n = n["parent"];
               }
               onSt = stg ? "1" : "0";
            }
            catch (e:*) { }
            var al:Number = -1;
            try { al = v.alpha; } catch (e:*) { }
            s = "vis=" + (v.visible ? 1 : 0) + " onSt=" + onSt + " par=" + par + " al=" + al
                + " sost=" + (oE["sost"] != null ? oE["sost"] : "-")
                + " dis=" + (oE["disabled"] ? 1 : 0)
                + " inv=" + (oE["invis"] ? 1 : 0)
                + " lev=" + (oE["levitPoss"] ? 1 : 0)
                + " chain=" + (oE.in_chain ? 1 : 0)
                + " ms=" + (oE["massa"] != null ? oE["massa"] : "-");
         }
         catch (e:*) { }
         return s;
      }
      // ===== v1.129：敌人在隐形瞬间就地记录 =====
      // 用户澄清：所有敌人类型斯安维斯坦结束后都会隐身（不止斑马）——v1.128
      // 的斑马 shine 修复是采样偏差（日志恰逢斑马战）。本扫描不依赖状态机：
      // 每帧对每个注册敌人检查 vis 是否脱离显示树/visible=false/alpha 过低，
      // 命中即记录完整状态（可见性/挂载链/alpha/sost/disabled/invis/levitPoss/
      // chain/massa 与 recE.st 阶段），一次复现即可定位通用机制。
      private function esInvScan(oE:Object, recE:Object):void
      {
         if (!cfgDiagLog || esInvDiag >= 40) return;
         try
         {
            var v:* = oE.vis;
            if (v == null) return;
            var fixed:Boolean = false;
            if (!v.visible)
            {
               esInvDiag++;
               log("[DIAG] esInv: vis.visible=0 st=" + recE.st + " " + esVisState(oE));
               try { v.visible = true; } catch (e:*) { }
               fixed = true;
            }
            var alv:Number = -1;
            try { alv = v.alpha; } catch (e:*) { }
            if (alv >= 0 && alv < 0.25)
            {
               esInvDiag++;
               log("[DIAG] esInv: alpha=" + alv + " st=" + recE.st + " " + esVisState(oE));
               // 非斑马 alpha 极低只有显示树脱链/人为改过；斑马由 shineGuard 处理
            }
            // 显示树校验（parent 链到 stage）：脱链即按游戏 addVisual 方式
            // 重挂回敌人所在图层（自我修复——若为孤儿机制，此处直接治好，
            // 日志可确认；若 disabled=1 则重挂无效而 dis=1 会暴露）
            var onst:Boolean = false;
            var nn:Object = v;
            var hp:int = 0;
            while (nn != null && hp < 8)
            {
               if (nn["stage"] != null) { onst = true; break; }
               nn = nn["parent"];
               hp++;
            }
            if (!onst)
            {
               esInvDiag++;
               log("[DIAG] esInv: notOnStage st=" + recE.st + " " + esVisState(oE));
               // 重挂：放入敌人 vis 所在图层（与游戏 addVisual 一致）
               var gV:Object = world["grafon"];
               if (gV != null && gV.visObjs != null && oE.sloy != null)
               {
                  var layN:Object = gV.visObjs[oE.sloy];
                  if (layN != null && v.parent != layN)
                  {
                     if (v.parent != null) { try { v.parent.removeChild(v); } catch (e:*) { } }
                     layN.addChild(v);
                     fixed = true;
                  }
               }
               if (fixed) { esInvDiag++; log("[DIAG] esInv: reattached " + esVisState(oE)); }
            }
         }
         catch (e:*) { }
      }
      // ===== v1.129：念力抓取诊断 =====
      // 用户在敌人隐形后无法用念力抓敌人——很可能就是抓不到隐形敌人（onCursor/
      // celObj 对不可见目标不成立）。按使用键(E/交互)时采样当前悬停对象状态，
      // 一次复现即可确认抓取卡在哪一环（levitPoss/onCursor/距离/LOS）。
      private function teleDiag():void
      {
         if (!cfgDiagLog || world == null || world.loc == null) return;
         try
         {
            var cel:Object = world.loc["celObj"];
            if (cel == null) return;
            var cls:String = flash.utils.getQualifiedClassName(cel);
            if (cls.indexOf("fe.unit::") != 0) return;   // 只关心敌人
            var lev:int = -1; var onC:Number = -1; var ma:Number = -1; var dist:Number = -1;
            try { lev = cel["levitPoss"] ? 1 : 0; } catch (e:*) { }
            try { onC = Number(cel["onCursor"]); } catch (e:*) { }
            try { ma = Number(cel["massa"]); } catch (e:*) { }
            try { dist = Number(world.loc["celDist"]); } catch (e:*) { }
            log("[DIAG] tele: cls=" + cls + " lev=" + lev + " onC=" + onC + " ma=" + ma
                + " dist=" + dist + " maxTe=" + (world.gg["pers"] != null ? world.gg["pers"]["maxTeleMassa"] : "-")
                + " " + esVisState(cel));
         }
         catch (e:*) { }
      }
      // ===== v1.128：斑马（UnitZebra）隐形修复 =====
      // 根因：斑马每 step() 扣 1 点 shine（UnitZebra.as:74），敌人斯安维斯坦
      // 场景 A 给活跃敌人补 4 次额外 step → shine 按 5 倍速暴跌（对齐/无 LOS
      // 时无 +15 增益），vis.alpha=shine/100 → 0 = "斯安维斯坦结束后隐身"。
      // 修复：isShoot 是 public（Unit.as:346，仅 UnitZebra 消费）——斑马置
      // true 后下一次 animate() 走 `isShoot→shine=currentWeapon.shine` 回充
      // 分支（weapon.shine public 默认 500）→ 立即回亮；isShoot 被斑马自己
      // 清零，无副作用。只对已隐形/低透明度的斑马家族触发。
      private function esShineGuard(oE:Object):void
      {
         try
         {
            if (oE == null) return;
            if (flash.utils.getQualifiedClassName(oE).indexOf("Zebra") < 0) return;
            var invZ:Boolean = false;
            try { invZ = Boolean(oE.invis); } catch (e:*) { }
            var alZ:Number = -1;
            try { if (oE.vis != null) { alZ = oE.vis.alpha; } } catch (e:*) { }
            if (!invZ && !(alZ >= 0 && alZ < 0.5)) return;
            if (oE["isShoot"] == null) return;
            oE.isShoot = true;
            if (cfgDiagLog && esOffVisDiag < 20)
            {
               esOffVisDiag++;
               log("[DIAG] esandy: shineGuard cls=" + flash.utils.getQualifiedClassName(oE)
                   + " inv=" + invZ + " al=" + alZ + " isShoot=1 " + esVisState(oE));
            }
         }
         catch (e:*) { }
      }
      // 场景 B：玩家时停中活跃敌人与玩家同权（每帧 step + 计时 + 徽标 + 残影）
      // v1.126：B 分支补上战斗触发检测与全部状态推进——此前只处理 st==1：
      // 玩家开着时停进入敌人视野时，敌人 AI 在节流帧（loc.step 1/N 速）里
      // 更新 celUnit 进入战斗，但触发检测只在常规分支 stepEnemySandy 里跑、
      // 玩家时停中被整体跳过 → 敌人永远不开启斯安维斯坦（用户实测）。
      private function stepEnemySandyB():void
      {
         if (!cfgESEnabled || !esRoomAllow) return;   // v1.131：总开关/本房间未掷中则不生成
         try
         {
            for (var kE:Object in esEnemies)
            {
               try
               {
                  var recE:Object = esEnemies[kE];
                  if (recE == null || kE == null || kE.in_chain != true) continue;
                  // 战斗触发检测（与常规分支同条件：celUnit==gg 且待机）
                  var celB:* = null;
                  try { celB = kE["celUnit"]; } catch (e:*) { }
                  if (celB == world.gg && recE.st == 0)
                  {
                     recE.st = 1;
                     recE.left = cfgESDur;
                     if (cfgDiagLog && esDiagCnt < 12)
                     {
                        esDiagCnt++;
                        log("[DIAG] esandy: cls=" + flash.utils.getQualifiedClassName(kE) + " ON(during player sandy)");
                     }
                  }
                  // 全部状态推进（含冷却倒计时——与 left 同速：玩家时停中敌人
                  // 斯安维斯坦计时按显示帧走，冷却结束即可重新触发）
                  esTick(kE, recE);
                  if (recE.st == 1)
                  {
                     try { kE.step(); } catch (e:*) { }
                     esGhostFor(kE, recE);
                  }
                  updateESMark(kE, recE.st);
                  esShineGuard(kE);   // v1.128：斑马 shine 回充（防隐形，B 分支）
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
      }
      // 敌人残影（边缘行者配色，速度映射——快=绿、慢=蓝紫）
      private function esGhostFor(oE:Object, recE:Object):void
      {
         if (!cfgESGhost) return;
         try
         {
            var spdE:Number = Math.abs(oE.X - recE.px) + Math.abs(oE.Y - recE.py);
            recE.px = oE.X;
            recE.py = oE.Y;
            // v1.122：静止不生成（防同位置叠残影、省绘制）；速度映射用
            // 本显示帧的真实位移（场景 A 的 N× 补步已包含在内，不再×倍率
            // ——原先 ×spd 恒满速全绿，渐变从不体现）
            if (spdE < 2) return;
            var sIdxE:int = speedToEdgeIdx(spdE);
            spawnEnemyGhost(oE, edgePalette(sIdxE));
         }
         catch (e:*) { }
      }
      // 敌人残影快照（与 spawnGhostAt 同款绘制管线，但画的是敌人 vis 而非玩家）
      private function spawnEnemyGhost(oE:Object, ct:ColorTransform):void
      {
         try
         {
            var visE:* = oE.vis;
            if (visE == null) return;
            var wE:Number = visE.width;
            var hE:Number = visE.height;
            if (wE < 1 || hE < 1) return;
            var bmpE:BitmapData = new BitmapData(wE, hE, true, 0);
            var mE:Matrix = new Matrix();
            var bE:Rectangle = visE.getBounds(visE);
            mE.tx = -bE.left;
            mE.ty = -bE.top;
            var sE:Number = 1;
            try { sE = oE.storona; } catch (e:*) { }
            var dmE:Matrix = mE;
            if (sE < 0) { dmE = new Matrix(-1, 0, 0, 1, bE.right, mE.ty); }
            var savedParentE:Object = visE.parent;
            var savedIdxE:int = -1;
            if (savedParentE != null)
            {
               try { savedIdxE = savedParentE.getChildIndex(visE); } catch (e:*) { }
               try { savedParentE.removeChild(visE); } catch (e:*) { }
            }
            bmpE.draw(visE as IBitmapDrawable, dmE, ct, "normal", null, true);
            if (savedParentE != null)
            {
               try { savedParentE.addChildAt(visE, savedIdxE); } catch (e:*) { }
            }
            // v1.129：摘挂兜底——若重挂失败导致 vis 脱离显示树（savedIdxE==-1
            // 或父层已换新等），立即按游戏 addVisual 方式放回敌人所在图层，
            // 从根上避免"敌人斯安维斯坦后隐身"。spawnEnemyGhost 调用频次低，
            // 只在异常路径触发。
            if (visE.parent == null)
            {
               var gVO:Object = world["grafon"];
               if (gVO != null && gVO.visObjs != null && oE.sloy != null && gVO.visObjs[oE.sloy] != null)
               {
                  gVO.visObjs[oE.sloy].addChild(visE);
               }
            }
            // v1.128：摘挂后校验 vis 是否仍在显示树上——若被摘下后重挂失败
            //（savedIdxE==-1 / 图层被换新等）vis 会脱离显示树=敌人隐身。
            // 只读校验，发现问题即记录（定位"斯安维斯坦结束后隐身"）。
            if (cfgDiagLog && esOrphanDiag < 15)
            {
               try
               {
                  var onStk:Boolean = false;
                  var nk:Object = visE;
                  var hop:int = 0;
                  while (nk != null && hop < 8)
                  {
                     if (nk["stage"] != null) { onStk = true; break; }
                     nk = nk["parent"];
                     hop++;
                  }
                  if (!onStk || visE.parent == null)
                  {
                     esOrphanDiag++;
                     log("[DIAG] esGhost-orphan: cls=" + flash.utils.getQualifiedClassName(oE)
                         + " onSt=" + onStk + " idx=" + savedIdxE + " parNul=" + (visE.parent == null)
                         + " " + esVisState(oE));
                  }
               }
               catch (e:*) { }
            }
            // v1.122：残影层懒初始化/重挂——此前 ghostLayer 只在玩家开时停
            // （startSandy）时创建：只触发敌人斯安维斯坦（玩家没开过时停）
            // 时 ghostLayer==null → addChild 抛空指针被吞 = 敌人残影
            // "几乎没有"的真根因（偶尔可见=之前开过时停残留了层）。现在
            // 每次生成前确保层挂在 world.visual 上、位于敌人 vis 所在层
            // 下方（残影被本体遮挡，与玩家残影同款插层法）。
            var visW:Object = world["visual"];
            if (visW != null)
            {
               if (ghostLayer == null) { ghostLayer = new Sprite(); }
               if (ghostLayer.parent != visW)
               {
                  if (ghostLayer.parent != null)
                  {
                     try { ghostLayer.parent.removeChild(ghostLayer); } catch (e:*) { }
                  }
                  var idxE2:int = -1;
                  try { if (savedParentE != null) { idxE2 = visW.getChildIndex(savedParentE); } } catch (e:*) { }
                  if (idxE2 > 0) { visW.addChildAt(ghostLayer, idxE2); }
                  else { visW.addChild(ghostLayer); }
               }
            }
            var bitE:Bitmap = new Bitmap(bmpE, "auto", true);
            var sprE:Sprite = new Sprite();
            try { sprE.x = oE.X + bE.left; sprE.y = oE.Y + bE.top; } catch (e:*) { }
            sprE.addChild(bitE);
            bitE.blendMode = cfgGhostBlend == 0 ? "add" : "normal";
            var glifeE:int = Math.max(1, cfgESGhostLife);   // v1.122：专用寿命（默认 12 帧）
            if (ghostLayer != null) { ghostLayer.addChild(sprE); }
            ghosts.push({ s: sprE, t: glifeE, life: glifeE, b: bmpE });
         }
         catch (e:*) { }
      }
      // 调试"S"徽标：待机绿 / 激活黄 / 冷却灰（visObjs[3]，世界坐标，非精英 goldstar）
      private function updateESMark(oE:Object, st:int):void
      {
         if (!cfgESMark) { removeESMark(oE); return; }
         try
         {
            var t:TextField = esMarks[oE];
            if (t == null)
            {
               t = new TextField();
               var tf:TextFormat = new TextFormat();
               tf.font = "Consolas";
               tf.size = 14;
               tf.bold = true;
               t.defaultTextFormat = tf;
               t.selectable = false;
               t.mouseEnabled = false;
               t.autoSize = "left";
               t.text = "S";
               esMarks[oE] = t;
               // v1.124：创建事件诊断（按敌人逐个记，覆盖整局而不是只前 10 帧）
               if (cfgDiagLog && esCreateDiag < 40)
               {
                  esCreateDiag++;
                  var rIdM:String = "";
                  try { if (world.loc != null && world.loc.room != null && world.loc.room.id != null) { rIdM = String(world.loc.room.id); } } catch (e:*) { }
                  log("[DIAG] esmark: create cls=" + flash.utils.getQualifiedClassName(oE)
                      + " room=" + rIdM + " x=" + oE.X + " y=" + oE.Y);
               }
            }
            // v1.119：不再挂 visObjs[3]——drawAllObjs 每帧把图层 Sprite 整个
            // 换新，且其它模组（RealisticVision 等）在我们之后还会再重建图层
            // （v1.118 的每帧重挂仍会被随后摘掉，用户实测仍不可见）。改为把
            // 徽标挂到 grafon.visual 顶层的专用容器：visual 是全部图层的父
            // 容器，drawAllObjs 只替换子层对象、从不清空 visual 本身——任何
            // 图层重建都碰不到它，且永远渲染在最上层（世界坐标不变）。
            var gVisE:Object = world["grafon"];
            var visC:Object = gVisE != null ? gVisE["visual"] : null;
            if (visC != null)
            {
               if (esMarkLayer == null) { esMarkLayer = new Sprite(); }
               if (esMarkLayer.parent != visC)
               {
                  visC.addChild(esMarkLayer);
               }
               if (t.parent != esMarkLayer)
               {
                  if (t.parent != null)
                  {
                     try { t.parent.removeChild(t); } catch (e:*) { }
                  }
                  esMarkLayer.addChild(t);
               }
            }
            t.textColor = st == 1 ? 0xFFD040 : (st == 0 ? 0x00FF88 : 0x888888);
            try { t.x = oE.X - 8; t.y = oE.Y - 60; } catch (e:*) { }
            // v1.119 诊断：前 10 条记录挂载链，定位"不可见"的最后一手数据
            if (cfgDiagLog && esMarkDiag < 10)
            {
               esMarkDiag++;
               log("[DIAG] esmark: cls=" + flash.utils.getQualifiedClassName(oE) + " st=" + st
                   + " inLay=" + (t.parent == esMarkLayer)
                   + " layOnVis=" + (esMarkLayer != null && esMarkLayer.parent == visC)
                   + " onStage=" + (t.stage != null)
                   + " visOnStage=" + (visC != null && visC["stage"] != null)
                   + " x=" + t.x + " y=" + t.y + " vis=" + t.visible);
            }
         }
         catch (e:*) { }
      }
      private function removeESMark(oE:Object):void
      {
         try
         {
            var t:Object = esMarks[oE];
            if (t != null)
            {
               if (t.parent != null) { t.parent.removeChild(t); }
               delete esMarks[oE];
            }
         }
         catch (e:*) { }
      }
      private function stepReplay():void
      {
         try
         {
            // 锁定输入：回放期间玩家不可操控（清空键状态，control 读到全 false）
            world.ctr.clearAll();
            // 回放中弹匣无限 + 跳过换弹计时（攻击持续流畅，不被换弹打断）
            var cwR:* = world.gg.currentWeapon;
            if (cwR != null)
            {
               if (cwR.holder > 0) { cwR.hold = cwR.holder; }
               cwR.t_reload = 0;
            }
            // 消除回放中游戏武器切换冷却：取消残留切换动画流程，并钉住回放武器
            // （否则 changeWeapon 的 changeWeaponNow 会在回放中触发，把武器切走/卸掉）
            try
            {
               if (world.gg.work == "change") { world.gg.work = ""; world.gg.t_work = 0; }
               if (replayWpn != null && world.gg.currentWeapon != replayWpn) { switchToWeapon(replayWpn); }
            }
            catch (e:*) { }
         }
         catch (e:*) { }
         // 回放开始诊断（每轮回放一次，v1.75）：录像构成（按类前缀计数）+
         // loc 中敌人攻击体（类名/位置/是否已录制）——定位"实体型攻击回放
         // 中静止"的未覆盖对象
         if (!replayDiagOnce)
         {
            replayDiagOnce = true;
            // v1.105：回放阶段粒子诊断重置——parts 诊断（partDiagOnce）在
            // 时停中已用过，重置后在回放首帧有粒子时再打一次（回放爆炸
            // 粒子构成）；粒子存活计数与异常计数重置
            partDiagOnce = false;
            replayPartTick = 0;
            partErrCnt = 0;
            // v1.107：回放开始时刻的爆炸位置视觉清点（鬼影本体点名）
            ghostScan("S");
            try
            {
               var cntWp:int = 0, cntUn:int = 0, cntSc:int = 0, cntOt:int = 0;
               for each (var roX:Object in replayObjArr)
               {
                  try
                  {
                     var qnX:String = flash.utils.getQualifiedClassName(roX);
                     if (qnX.indexOf("fe.weapon::") == 0) { cntWp++; }
                     else if (qnX.indexOf("fe.unit::") == 0 || qnX.indexOf("fe.serv::") == 0) { cntUn++; }
                     else if (qnX.indexOf("fe.loc::") == 0) { cntSc++; }
                     else { cntOt++; }
                  }
                  catch (e:*) { }
               }
               log("[DIAG] rStart: recObjs=" + replayObjArr.length + " atk=" + cntWp + " unit=" + cntUn + " scene=" + cntSc + " other=" + cntOt);
               var oR2:Object = world.loc != null ? world.loc.firstObj : null;
               var gR2:int = 0;
               while (oR2 != null)
               {
                  try
                  {
                     var qnR3:String = flash.utils.getQualifiedClassName(oR2);
                     if (qnR3.indexOf("fe.weapon::") == 0 && oR2["owner"] != world.gg)
                     {
                        log("[DIAG] rStart: enemyAtk cls=" + qnR3 + " X=" + oR2.X + " Y=" + oR2.Y
                            + " rec=" + (replayObjs[oR2] != null ? 1 : 0));
                     }
                  }
                  catch (e:*) { }
                  oR2 = oR2.nobj;
                  if (++gR2 > 20000) break;
               }
            }
            catch (e:*) { }
         }
         // 回放段诊断：loc 中攻击体计数（生成/结算是否平衡）与弹夹状态（每 60 帧）
         if (++replayDiagTick % 60 == 1)
         {
            try
            {
               var locR:Object = world.loc;
               var oR:Object = locR.firstObj;
               var nR:int = 0;
               var guardR:int = 0;
               while (oR != null)
               {
                  try
                  {
                     if (flash.utils.getQualifiedClassName(oR).indexOf("fe.weapon::") == 0) { nR++; }
                  }
                  catch (e:*) { }
                  oR = oR.nobj;
                  if (++guardR > 20000) break;
               }
               var cwD:* = world.gg.currentWeapon;
               log("[DIAG] replay: locWeapons=" + nR + " hold=" + (cwD != null ? cwD.hold : -1)
                   + " holder=" + (cwD != null ? cwD.holder : -1) + " t_atk=" + (cwD != null ? cwD.t_attack : -1));
            }
            catch (e:*) { }
         }
         var n:int = Math.ceil(cfgReplaySpeed);
         var ghostIdx:int = replayIdx;
         var atkOn:Boolean = false;
         var punchOn:Boolean = false;
         var grenOn:Boolean = false;
         var magOn:Boolean = false;
         var fireCnt:int = 0;   // 窗口内真实开火次数（时停记录逐帧累加）
         var firePts:Array = [];   // 开火帧的武器位置/瞄准点（v1.86：子弹按开火帧精确复现）
         var lastAimX:Number = 0;   // 窗口末帧瞄准点（开火前武器重新瞄准用）
         var lastAimY:Number = 0;
         var prevGx:Number = 0;   // 上一历史帧位置（残影速度/配色用）
         var prevGy:Number = 0;
         var prevWid:String = replayWpn != null ? replayWpn.id : "";   // 当前回放武器 id（用于重演切换）
         for (var i:int = 0; i < n; i++)
         {
            if (replayIdx >= history.length)
            {
               endReplay();
               return;
            }
            var h:Object = history[replayIdx];
            // 武器切换重演：历史中武器变化时立即切换（无冷却，跟随时停期间的切枪）
            if (h.w != null && h.w != prevWid)
            {
               var tgtW:Object = h.w == "" ? null : world.invent.weapons[h.w];
               switchToWeapon(tgtW);
               replayWpn = tgtW;
               prevWid = h.w;
            }
            // 驱动玩家沿历史路径移动（真回放：玩家本体重演）
            try
            {
               world.gg.X = h.x;
               world.gg.Y = h.y;
               world.gg.storona = h.s;
               world.gg.setVisPos();
               // 念力投掷物复位：回放开始时（及全程）钉在历史位置——否则
               // 物品仍从时停结束位置开始移动（玩家 gg.step 的 teleObj 逻辑会
               // 跟随玩家更新其位置，覆盖场景记录）
               try
               {
                  if (world.gg.teleObj != null && h.tx != null)
                  {
                     world.gg.teleObj.X = h.tx;
                     world.gg.teleObj.Y = h.ty;
                     if (world.gg.teleObj.vis != null)
                     {
                        world.gg.teleObj.vis.x = h.tx;
                        world.gg.teleObj.vis.y = h.ty;
                     }
                  }
               }
               catch (e:*) { }
               // 喂回记录的瞄准方向（攻击指向时停期间的发射方向）
               if (h.ax != null)
               {
                  world.celX = h.ax;
                  world.celY = h.ay;
                  lastAimX = h.ax;
                  lastAimY = h.ay;
                  // 武器位置：枪械强制就位（枪口钉在角色手上，跳过渐进旋转）；
                  // 近战重现时停期间的独立位置（历史 wx/wy + 清插值 del，
                  // 否则 WClub.actions 的追赶插值追不上回放中瞬移的瞄准点，
                  // 武器会滞留在时停结束时的位置）
                  try
                  {
                     var wv:* = world.gg.currentWeapon;
                     if (wv != null)
                     {
                        var qnW:String = flash.utils.getQualifiedClassName(wv);
                        var meleeW:Boolean = qnW == "fe.weapon::WClub" || qnW == "fe.weapon::WPunch" || qnW == "fe.weapon::WKick";
                        if (meleeW)
                        {
                           wv.X = h.wx;
                           wv.Y = h.wy;
                           try { wv.del.x = 0; wv.del.y = 0; } catch (e:*) { }
                        }
                        else
                        {
                           wv.X = world.gg.weaponX;          // 枪口位置就位
                           wv.Y = world.gg.weaponY;
                           wv.rot = Math.atan2(h.ay - world.gg.Y, h.ax - world.gg.X);  // 瞄准角
                           wv.ready = true;                   // 视为已就位（可立即攻击）
                        }
                     }
                  }
                  catch (e:*) { }
               }
            }
            catch (e:*) { }
            // 攻击键 OR 合并（窗口内任一历史帧按下则本帧触发，点按不丢）
            if (h.a == true) atkOn = true;
            if (h.p == true) punchOn = true;
            if (h.g == true) grenOn = true;
            if (h.m == true) magOn = true;
            // 真实开火计数（v1.72）：直接累加时停期间逐帧记录的开火数——
            // 记录时以相邻帧弹夹下降（子弹真实生成）判定，回放不再做窗口
            // 边缘检测（旧上升沿/下降沿在窗口首帧必丢边——吞攻击根源之一）。
            // v1.86：开火帧的武器位置与瞄准点逐帧记录（子弹按开火帧精确
            // 复现——窗口末位置/瞄准会让子弹与重演的投掷物等实体产生
            // 整窗口偏差："回放中子弹离手雷偏差大"的根源）
            if (h.fc != null && h.fc > 0)
            {
               fireCnt += h.fc;
               firePts.push({ f: replayIdx, x: h.wx, y: h.wy, rot: h.wrot, ax: h.ax != null ? h.ax : 0, ay: h.ay != null ? h.ay : 0 });
            }
            prevGx = h.x;
            prevGy = h.y;
            replayIdx++;
         }
         // 回放残影（v1.73）：生成间隔 replayghost（显示帧）+ 寿命 replayghostlife
         // （显示帧）均可配置——高频率+短寿命=拖尾。颜色用**时停期间记录的颜色
         // 索引**（按回放实际速度算会因采样步长全变紫色——Sandy 记录时的真实
         // 速度映射才正确）
         try
         {
            if (replayIdx > 0)
            {
               var ghH:Object = history[Math.min(replayIdx - 1, history.length - 1)];
               if (++replayGhostDisp % Math.max(1, cfgReplayGhost) == 0)
               {
                  var gct:ColorTransform = (cfgColorMode == 1)
                     ? edgePalette(ghH.ci != null ? ghH.ci : 0)
                     : palette(rainbowIdx++);
                  spawnGhostAt(ghH.x, ghH.y, ghH.s, ghH.r, ghH.v, gct);
               }
            }
         }
         catch (e:*) { }
         // ===== 攻击重演（v1.62）：按历史记录的真实开火次数精确驱动 =====
         // 旧的 -=5 冷却加速有量化误差（周期向显示帧取整）→ 部分 rapid 值下
         // 回放攻击数 < 时停攻击数（吞攻击）。现按时停记录的 tA 上升沿精确计数，
         // 逐发手动驱动 weapon.attack()+step()，开火次数与时停完全一致。
         try
         {
            // 攻击键不再喂回 keyAttack（开火由 fireCnt 精确驱动，喂回会双发）
            world.ctr.keyAttack = false;
            world.ctr.keyPunch = punchOn;
            // v1.91：手雷不重执行——投掷物由录像按引用重演（同一对象，
            // 位置逐帧重钉）；重执行会另生成一份实时飞行体，与录像体
            // 重叠成"鬼影"且回放后出现双份（录像体保留，回放结束自然
            // 续飞爆炸）。魔法保留重执行（其伤害依赖重执行结算）。
            world.ctr.keyGrenad = false;
            world.ctr.keyMagic = magOn;
         }
         catch (e:*) { }
         // 世界冻结（onPause=true）下的手动驱动：
         // 1. 玩家手动 step（消费喂回的键 → 移动/拳击/投掷/魔法）
         // 2. 攻击逐发重演（fireCnt 驱动 attack+step——枪械/近战）
         // 3. 玩家攻击体手动 step（全速飞行+碰撞结算）
         // 4. 敌人/物品/场景/攻击体重演（位置+动画帧+生成音效）
         // 5. 粒子特效照常（枪口火焰等）
         try { world.loc.gg.step(); } catch (e:*) { }
         // 玩家动画驱动（v1.73）：回放中按键清空 → control() 置 dx=0 → 玩家
         // animate() 恒走 stay 待机帧（回放中玩家视觉僵死）。按历史轨迹量化 dx
         // 喂 animate()：|dx|>4 进入移动子分支（walk/run/trot——该子分支在
         // stay 外块内部，stay=true 不阻塞）；maxSpeed 公开可写——<5 走档、
         // 用 runForever 强开跑档；档位迟滞防抖；待机档 dx=0 回 stay 帧。
         // maxSpeed/runForever 为瞬时值（下一帧 control 重算），动画后恢复。
         try
         {
            var cP2:Object = history[Math.min(replayIdx - 1, history.length - 1)];
            var nP2:Object = history[Math.min(replayIdx, history.length - 1)];
            if (cP2 != null && nP2 != null)
            {
               var pdxR:Number = (nP2.x - cP2.x) * cfgReplaySpeed;
               var pspdR:Number = pdxR >= 0 ? pdxR : -pdxR;
               var pCatR:int = pspdR < 1.5 ? 1 : (pspdR < 8 ? 2 : 3);
               var pPrevC:int = playerAnimCat;
               if (pPrevC != 0)
               {
                  if (pPrevC == 3 && pCatR == 2 && pspdR > 5) { pCatR = 3; }
                  else if (pPrevC == 2 && pCatR == 1 && pspdR > 2.5) { pCatR = 2; }
                  else if (pPrevC == 1 && pCatR == 2 && pspdR < 3) { pCatR = 1; }
                  else if (pPrevC == 2 && pCatR == 3 && pspdR < 10) { pCatR = 2; }
               }
               playerAnimCat = pCatR;
               // v1.130：帧级忠实重演——不靠状态机重算，直接快照时停中记录的
               // 玩家身体帧（vis.osn 标签 + osn.body 帧号）。回放中 gg.step()
               // 的 control 清键 → animate() 只会放 stay 待机纸偶；直接
               // gotoAndStop 到录像帧即可逐帧复现玩家当时姿势（跑/跳/翻滚/
               // 趴下/起身/挥击任意组合），起始姿势=时停起始帧，结束姿势=
               // 时停结束帧，彻底消除"起始/结束姿势不一致时的动画错乱"。
               var hasBF:Boolean = nP2["bf"] != null && nP2["bf"] != undefined;
               if (hasBF)
               {
                  try
                  {
                     var vg4:* = world.gg.vis;
                     if (vg4 != null && vg4["osn"] != null)
                     {
                        var osn4:* = vg4["osn"];
                        var bl4:String = nP2["bl"] != null ? String(nP2["bl"]) : "";
                        if (bl4.length > 0)
                        {
                           try { if (osn4.currentFrameLabel != bl4) { osn4.gotoAndStop(bl4); } } catch (e:*) { }
                        }
                        if (osn4["body"] != null && int(nP2["bf"]) > 0)
                        {
                           try { osn4["body"].gotoAndStop(int(nP2["bf"])); } catch (e:*) { }
                        }
                        var an4:String = nP2["an"] != null ? String(nP2["an"]) : "";
                        if (an4.length > 0)
                        {
                           try { world.gg.animState = an4; } catch (e:*) { }
                        }
                     }
                  }
                  catch (e:*) { }
               }
               else
               {
                  // 旧录像无帧数据时的兜底：v1.120 状态机喂入（isSit+dx/…）
                  // v1.120：时停中趴下/翻滚在回放中重现——dx 量化只覆盖
                  // 走/跑/小跑（"roll" 是 isSit 移动分支的动画，dx 驱动永远
                  // 进不了）。按录像的 si（isSit）/an（animState）喂同样的
                  // 状态机输入（isSit + dx/maxSpeed/runForever），让游戏自身
                  // animate() 走出 roll→polz→down→up 的真实过渡。
                  var siR:Boolean = false;
                  var anR:String = "";
                  try
                  {
                     siR = nP2["si"] != null && nP2["si"] != undefined ? Boolean(nP2["si"]) : false;
                     anR = nP2["an"] != null ? String(nP2["an"]) : "";
                  }
                  catch (e:*) { }
                  var savedMS:Number = 0;
                  var savedRF:int = 0;
                  var savedSit:Boolean = false;
                  try
                  {
                     savedMS = world.gg.maxSpeed;
                     savedRF = world.gg.runForever;
                     savedSit = world.gg.isSit;
                     if (siR)
                     {
                        // 趴下/翻滚分支：方向取 storona（游戏要求 dx*storona>0
                        // 才走 roll/run；storona 由主循环按录像恢复）
                        var sgnS:Number = 1;
                        try { sgnS = world.gg.storona < 0 ? -1 : 1; } catch (e:*) { }
                        if (sgnS == 0) { sgnS = 1; }
                        world.gg.isSit = true;
                        if (anR == "roll" || pCatR == 3)
                        {
                           // 翻滚：dx 大 + maxSpeed 超 walkSpeed*1.6 + runForever
                           //（anR=="roll" 兜底贴墙翻滚等位移小的情形）
                           world.gg.dx = sgnS * 14;
                           world.gg.maxSpeed = world.gg.walkSpeed * 1.6 + 10;
                           world.gg.runForever = 1;
                        }
                        else if (pCatR == 2)
                        {
                           // 趴地移动（polz）：maxSpeed 低于 walkSpeed*1.6
                           world.gg.dx = sgnS * 6;
                           world.gg.maxSpeed = 4;
                        }
                        else
                        {
                           // 趴下静止：dx=0 走待机分支 → down 姿态/起身 up 过渡
                           world.gg.dx = 0;
                        }
                        world.gg.animate();
                     }
                     else if (pCatR == 1)
                     {
                        world.gg.dx = 0;
                        world.gg.animate();
                     }
                     else
                     {
                        world.gg.dx = (pdxR >= 0 ? 1 : -1) * (pCatR == 2 ? 6 : 14);
                        world.gg.maxSpeed = pCatR == 2 ? 4 : 20;
                        if (pCatR == 3) { world.gg.runForever = 1; }
                        world.gg.animate();
                     }
                     world.gg.maxSpeed = savedMS;
                     world.gg.runForever = savedRF;
                     world.gg.isSit = savedSit;
                  }
                  catch (e:*) { }
               }
            }
         }
         catch (e:*) { }
         var cwNow:* = world.gg.currentWeapon;
         var execCnt:int = 0;   // 实际执行的开火数（attack() 返回 true）
         if (cwNow != null && fireCnt > 0)
         {
            // 回放不重掷损坏/卡壳骰子（v1.72）：weaponAttack 按 hp 推算 breaking，
            // 半耐久武器在回放中会随机卡壳/哑火吞攻击（时停中已打出的子弹
            // 回放必须同样打出）；hp<=0 时 attack() 直接拒开。逐发把 hp 抬满
            // （breaking=0）+清卡壳标记；耐久 endReplay 由快照恢复，循环后
            // 恢复原状态。
            var savedHpF:* = cwNow.hp;
            var savedJamF:* = cwNow.jammed;
            var qnNow:String = flash.utils.getQualifiedClassName(cwNow);
            var meleeNow:Boolean = qnNow == "fe.weapon::WClub" || qnNow == "fe.weapon::WPunch" || qnNow == "fe.weapon::WKick";
            for (var fi:int = 0; fi < fireCnt; fi++)
            {
               try
               {
                  // 开火前武器重新瞄准/就位（枪械）：v1.86 按**开火帧**记录的
                  // 武器位置与瞄准点精确复现（firePts）——跳跃/窗口偏移不再
                  // 使子弹偏离；无记录时退回窗口末瞄准。近战不需要。
                  if (!meleeNow)
                  {
                     try
                     {
                        var fp:Object = firePts.length > 0 ? firePts.shift() : null;
                        if (fp != null)
                        {
                           cwNow.X = fp.x;
                           cwNow.Y = fp.y;
                           world.celX = fp.ax;
                           world.celY = fp.ay;
                        }
                        else
                        {
                           cwNow.X = world.gg.weaponX;
                           cwNow.Y = world.gg.weaponY;
                           world.celX = lastAimX;
                           world.celY = lastAimY;
                        }
                        // v1.99：按开火帧记录的实际武器 rot 复现——shoot() 的子弹
                        // 方向取 `this.rot`（Weapon.as:1495，含 drot 渐转中的实际
                        // 角度），旧实现强制 rot=瞄准角：武器旋转中开火时，时停中
                        // 子弹沿实际角度（如 2 点）飞行、回放沿瞄准角（4 点）飞行
                        // 的偏移根因。无记录退回瞄准角。
                        try
                        {
                           if (fp != null && fp.rot != null) { cwNow.rot = fp.rot; }
                           else { cwNow.rot = Math.atan2(world.celY - cwNow.Y, world.celX - cwNow.X); }
                        }
                        catch (e:*) { }
                        cwNow.ready = true;
                        // v1.90：v1.88 预推进移除——与 stepPlayerBullets + 世界重钉
                        // 双重计入，子弹超前最多 1 个世界步（~200px，用户实测
                        // "手雷飞行状态提前/玩家射击延后"）。正确对齐：子弹生成于
                        // 显示帧 m（世界时间 m），随后 stepPlayerBullets 步 1 次、
                        // replayObjects 把世界重钉到 m+1——子弹与世界天然同步，
                        // 无需修正（时停中两者同按世界节流步进，映射严格一致）。
                     }
                     catch (e:*) { }
                  }
                  cwNow.t_attack = 0;
                  cwNow.t_auto = 0;
                  cwNow.t_reload = 0;
                  try
                  {
                     cwNow.hp = cwNow.maxhp;      // breaking=0（weaponAttack 按 hp 推算）
                     cwNow.jammed = false;        // 卡壳标记不清会阻断开火
                  }
                  catch (e:*) { }
                  // 蓄力武器（prep>0）：强制充满蓄力——单次 attack() 只加 2 点
                  // t_prep，不满 prep 不会开火（跳跃时蓄力武器吞攻击的来源之一）
                  try
                  {
                     if (cwNow.prep > 0) { cwNow.t_prep = cwNow.prep; }
                  }
                  catch (e:*) { }
                  if (cwNow.attack() == true) { execCnt++; }
                  cwNow.step();       // 武器步进（shoot 在 t_attack==rapid 触发）
                  // v1.94：爆弹体孪生发现——重执行生成的爆弹（核弹/榴弹/
                  // 火箭）与录像原体配对：回放中把重执行体钉到录像轨迹
                  // （重演子弹与重执行体按原几何相遇→命中引爆，窗口量化
                  // 误差消除）。孪生=玩家方、时停中生成（补帧 vv=false）、
                  // 首个 vv=true 索引==本开火帧 fp.f。
                  try
                  {
                     if (!meleeNow && fp != null && fp.f != null)
                     {
                        var nb2:* = cwNow.b;
                        if (nb2 != null && nb2.explRadius != null && nb2.explRadius > 0 && reExecPin[nb2] == null)
                        {
                           for (var kT2:Object in seenAtk)
                           {
                              try
                              {
                                 if (kT2 == null || kT2 == nb2) continue;
                                 if (kT2["owner"] != world.gg) continue;
                                 var arrT2:Array = replayObjs[kT2];
                                 if (arrT2 == null || arrT2.length <= 1) continue;
                                 if (arrT2[0].vv != false) continue;
                                 var spawnF:int = -1;
                                 for (var fi2:int = 1; fi2 < arrT2.length; fi2++)
                                 {
                                    if (arrT2[fi2].vv == true) { spawnF = fi2; break; }
                                 }
                                 if (spawnF >= fp.f - 1 && spawnF <= fp.f + 1 && recPaired[kT2] == null)
                                 {
                                    // v1.99：±1 容差——节流帧第二遍步开火时注册帧与
                                    // 开火帧相差 1（日志实证 spawnF=80 vs fp.f=81），
                                    // 严格相等导致配对失败→孪生体不钉不终止→导弹
                                    // 飞过爆炸点继续飞/回放后再爆。已配对的录像体
                                    // 不再参与配对（连发时防同一录像体被多次配对）。
                                    recPaired[kT2] = true;
                                    reExecPin[nb2] = kT2;
                                    try
                                    {
                                       if (twinDiagCnt < 12)
                                       {
                                          twinDiagCnt++;
                                          log("[DIAG] pairOk: spawnF=" + spawnF + " fpF=" + fp.f
                                              + " cls=" + flash.utils.getQualifiedClassName(nb2));
                                       }
                                    }
                                    catch (e:*) { }
                                    break;
                                 }
                              }
                              catch (e:*) { }
                           }
                        }
                     }
                  }
                  catch (e:*) { }
                  // 连发武器（dkol>0）：初始化后持续步进完成整个连发
                  try
                  {
                     if (cwNow.dkol != null && cwNow.dkol > 0 && cwNow.t_attack > 0)
                     {
                        while (cwNow.t_attack > 0) { cwNow.step(); }
                     }
                  }
                  catch (e:*) { }
               }
               catch (e:*) { }
               if (meleeNow)
               {
                  // 近战直接结算（bindMove 窗口被跳过——逐发结算命中）
                  try
                  {
                     if (cwNow.b != null && cwNow.b.off == false)
                     {
                        var angB:Number = Math.atan2(world.celY - world.gg.Y, world.celX - world.gg.X);
                        cwNow.b.X = world.gg.X + Math.cos(angB) * 60;
                        cwNow.b.Y = world.gg.Y + Math.sin(angB) * 60 - 10;
                        var unitsArr:Object = world.loc.units;
                        for each (var uu:Object in unitsArr)
                        {
                           if (cwNow.b.off) break;
                           if (uu == world.gg) continue;
                           if (uu.sost == 4 || uu.disabled || uu.trigDis) continue;
                           if (uu.loc != world.loc) continue;
                           try { if (uu.fraction == world.gg.fraction) continue; } catch (e:*) { }
                           var ddxB:Number = uu.X - cwNow.b.X;
                           var ddyB:Number = uu.Y - cwNow.b.Y;
                           if (ddxB * ddxB + ddyB * ddyB < 80 * 80)
                           {
                              var hitResB:int = uu.udarBullet(cwNow.b);
                              if (hitResB >= 0) { cwNow.b.popadalo(hitResB); }
                              cwNow.b.off = true;
                              break;
                           }
                        }
                     }
                  }
                  catch (e:*) { }
               }
            }
            // 恢复武器耐久/卡壳状态（endReplay 另有快照恢复兜底）
            try
            {
               cwNow.hp = savedHpF;
               cwNow.jammed = savedJamF;
            }
            catch (e:*) { }
         }
         // 开火诊断（每 15 帧）：fireCnt=检测到应开火数 exec=实际执行数
         // 玩家 stay（跳跃状态）——定位跳跃相关吞攻击
         if (++replayFireTick % 15 == 0)
         {
            try
            {
               log("[DIAG] rFire: cnt=" + fireCnt + " exec=" + execCnt
                   + " pStay=" + world.gg.stay + " pJump=" + world.gg.isJump
                   + " cw=" + (cwNow != null ? flash.utils.getQualifiedClassName(cwNow) : "none")
                   + " tA=" + (cwNow != null ? cwNow.t_attack : -1));
            }
            catch (e:*) { }
         }
         stepPlayerBullets();
         stepUnrecordedAtk();
         replayObjects();
         // v1.94：重执行爆弹体钉到录像轨迹——消除窗口量化误差，
         // 重演子弹与重执行体按时停原几何相遇命中引爆
         try
         {
            for (var kRP:Object in reExecPin)
            {
               try
               {
                  if (kRP == null) { delete reExecPin[kRP]; continue; }
                  try { if (kRP.in_chain != true || kRP.isExpl == true) { delete reExecPin[kRP]; continue; } } catch (e:*) { }
                  var twinRP:Object = reExecPin[kRP];
                  var arrRP:Array = replayObjs[twinRP];
                  if (arrRP == null || arrRP.length == 0) { delete reExecPin[kRP]; continue; }
                  var stRP:Object = arrRP[Math.min(replayIdx, arrRP.length - 1)];
                  if (stRP == null) continue;
                  // v1.96：录像孪生体已爆炸（vv=false 死亡标记）→ 终止重执行体
                  // （隐藏 + 禁爆 + 杀）——爆炸由 boom 按录像帧如实重演，
                  // 不再由孪生体后续自然爆炸产生"晚于时停"的第二爆/定格残影
                  if (stRP.vv == false)
                  {
                     try { kRP.isExpl = true; } catch (e:*) { }
                     try { kRP.liv = 0; } catch (e:*) { }
                     try { if (kRP.vis != null) { kRP.vis.visible = false; } } catch (e:*) { }
                     // v1.98：已由 boom 替代演出——不得在 endReplay 恢复爆炸能力
                     // （否则 liv=0 的终止体回放结束后再爆一次）
                     try { delete twinSavExpl[kRP]; } catch (e:*) { }
                     delete reExecPin[kRP];
                     continue;
                  }
                  kRP.X = stRP.x;
                  kRP.Y = stRP.y;
                  try { if (kRP.vis != null) { kRP.vis.x = stRP.x; kRP.vis.y = stRP.y; } } catch (e:*) { }
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
         // 投掷物可击落检测（v1.83）：回放中重演的子弹命中重演的
         // 投掷物 → 真实爆炸结算（时停中的引爆只是视觉预告）
         stepProjHits(world.loc, false);
         // 被投掷单位撞击伤害结算（v1.74）：时停中记录的首次撞击——回放推进
         // 到撞击帧时按游戏 damageWall 公式结算（时停中已跳过伤害）。单位
         // 位置由 replayObjects 重钉在撞击位置，伤害与视觉同步。
         // v1.76：补撞击反馈（游戏 damageWall 的撞击音效 hit_flesh + 尘土 bum）
         try
         {
            for (var kTI:Object in thrownImpacts)
            {
               try
               {
                  var impTI:Object = thrownImpacts[kTI];
                  if (replayIdx >= impTI.frame)
                  {
                     if (impTI.dam > 0 && kTI.damage != null)
                     {
                        kTI.damage(impTI.dam, 2);   // D_PHIS=2（物理撞击）
                        try
                        {
                           if (sndClass != null) { sndClass["ps"]("hit_flesh", kTI.X, kTI.Y); }
                           var EmClass:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Emitter") as Class;
                           if (EmClass != null) { EmClass["emit"]("bum", world.loc, kTI.X, kTI.Y); }
                        }
                        catch (e:*) { }
                     }
                     delete thrownImpacts[kTI];
                  }
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
         if (cfgFxRun) { try { stepParticles(world.loc); } catch (e:*) { } }
         // v1.102：回放中同样对 MC 型爆炸粒子 stop+逐帧推进——boom 生成的
         // 爆炸 MC 按舞台帧率播放，动画短于粒子寿命时循环重播（回放中
         // "两个冲击波"候选根因；时停中 v1.98 同款修复已确认有效）。
         // 推进速率 1 帧/显示帧=正常速度不变，仅防循环。
         try { mcStepParts(world.loc, true); } catch (e:*) { }
         // v1.105：回放粒子存活诊断（每 10 显示帧）——验证爆炸粒子在
         // 20 帧钳制内自然完结（粒子冻结=火光滞留=鬼影候选；若 n 恒定
         // 不降说明有粒子没被步进）
         if (++replayPartTick % 10 == 0)
         {
            try
            {
               var PartC5:Class = ApplicationDomain.currentDomain.getDefinition("fe.graph.Part") as Class;
               if (PartC5 != null)
               {
                  var oP5:Object = world.loc.firstObj;
                  var nP5:int = 0;
                  var mxP5:int = 0;
                  var gP5:int = 0;
                  while (oP5 != null)
                  {
                     try
                     {
                        if (oP5 is PartC5) { nP5++; if (oP5.liv > mxP5) { mxP5 = oP5.liv; } }
                     }
                     catch (e:*) { }
                     oP5 = oP5.nobj;
                     if (++gP5 > 20000) break;
                  }
                  log("[DIAG] partsAlive: n=" + nP5 + " maxliv=" + mxP5 + " idx=" + replayIdx);
               }
            }
            catch (e:*) { }
            // v1.107：每 10 显示帧同扫爆炸位置视觉（跟踪鬼影何时出现/消失）
            if (replayIdx % 50 == 0) { ghostScan("R" + replayIdx); }
         }
         // 回放动画诊断（每 30 帧）：采样前 2 个重演单位的视觉像素哈希——
         // 哈希随帧变化=动画在播放；恒不变=渲染冻结（僵死根因判定）
         if (++replayAnimTick % 30 == 0)
         {
            try
            {
               var nA:int = 0;
               for each (var oA:Object in replayObjArr)
               {
                  try
                  {
                     if (oA == null || oA["setPos"] == null || oA.vis == null) continue;
                     var hsh:String = "-";
                     try
                     {
                        var bdA:* = oA.vis.bitmapData;
                        if (bdA != null)
                        {
                           hsh = bdA.getPixel32(int(bdA.width / 2), int(bdA.height / 2)).toString(16)
                               + "/" + bdA.getPixel32(int(bdA.width / 3), int(bdA.height / 3)).toString(16);
                        }
                        else if (oA.vis.currentFrame != null)
                        {
                           // MovieClip 视觉：动画在嵌套剪辑或子 Bitmap 中——
                           // 采样嵌套帧号与子 Bitmap 像素（顶层帧恒 0 无意义）
                           hsh = "f" + oA.vis.currentFrame;
                           try
                           {
                              if (oA.vis.osn != null && oA.vis.osn.body != null)
                              {
                                 hsh += "/o" + oA.vis.osn.body.currentFrame;
                              }
                              else if (oA.vis.body != null)
                              {
                                 hsh += "/b" + oA.vis.body.currentFrame;
                              }
                           }
                           catch (e:*) { }
                           try
                           {
                              var nc:int = oA.vis.numChildren;
                              for (var ci:int = 0; ci < nc && ci < 3; ci++)
                              {
                                 var ch:* = oA.vis.getChildAt(ci);
                                 if (ch != null && ch.bitmapData != null)
                                 {
                                    hsh += "/c" + ch.bitmapData.getPixel32(int(ch.bitmapData.width / 2), int(ch.bitmapData.height / 2)).toString(16);
                                    break;
                                 }
                              }
                           }
                           catch (e:*) { }
                        }
                     }
                     catch (e:*) { }
                     log("[DIAG] rAnim: cls=" + flash.utils.getQualifiedClassName(oA)
                         + " sost=" + oA.sost + " stay=" + oA.stay + " dx=" + oA.dx
                         + " hp=" + oA.hp + " hash=" + hsh);
                     if (++nA >= 2) break;
                  }
                  catch (e:*) { }
               }
            }
            catch (e:*) { }
         }
         // 回放攻击体状态诊断（每 3 帧）：攻击体位置/伤害/off 状态（定位近战结算问题）
         if (++replayBodyTick % 3 == 0)
         {
            try
            {
               var cwB:* = world.gg.currentWeapon;
               if (cwB != null && cwB.b != null)
               {
                  log("[DIAG] rBody: bX=" + cwB.b.X + " bY=" + cwB.b.Y + " dmg=" + cwB.b.damage
                      + " off=" + cwB.b.off + " liv=" + cwB.b.liv + " vel=" + cwB.b.vel
                      + " ggX=" + world.gg.X + " ggY=" + world.gg.Y
                      + " cwX=" + cwB.X + " cwY=" + cwB.Y + " tA=" + cwB.t_attack);
               }
            }
            catch (e:*) { }
         }
         // 回放攻击链路诊断（每 10 帧）：确认喂回与游戏攻击条件
         if (++replayAtkTick % 10 == 0)
         {
            try
            {
               var cwA:* = world.gg.currentWeapon;
               log("[DIAG] rAtk: atkOn=" + atkOn + " kA=" + world.ctr.keyAttack
                   + " tA=" + (cwA != null ? cwA.t_attack : -1)
                   + " atkPos=" + (cwA != null ? cwA.attackPos() : false)
                   + " cw=" + (cwA != null ? flash.utils.getQualifiedClassName(cwA) : "none"));
            }
            catch (e:*) { }
         }
         if (replayIdx >= history.length)
         {
            endReplay();
         }
      }

      private function endReplay():void
      {
         replaying = false;
         history = new Array();
         try
         {
            // 回放结束：恢复世界运行（敌人/场景恢复自由行动）
            world.onPause = savedOnPause;
            world.godMode = savedGod;    // 恢复无敌状态
            world.ctr.keyAttack = false;
            world.ctr.keyPunch = false;
            world.ctr.keyGrenad = false;
            world.ctr.keyMagic = false;
         }
         catch (e:*) { }
         // v1.80：预判死亡隐藏（vis.visible=false）的炮塔类若回放中未被真实
         // 击杀（预测偏松/子弹未命中），回放结束后恢复可见——否则以隐身状态
         // 存活并继续攻击。正常钻地的尸鬼由 AI 状态（aiState=5）自行控制
         // 可见性，不受影响。
         try
         {
            for each (var oV:Object in replayObjArr)
            {
               try
               {
                  if (oV != null && oV["setPos"] != null && oV.vis != null)
                  {
                     var qnV:String = flash.utils.getQualifiedClassName(oV);
                     if (qnV.indexOf("Turret") >= 0 || qnV.indexOf("Bloat") >= 0
                         || qnV.indexOf("Robot") >= 0 || qnV.indexOf("Msp") >= 0)
                     {
                        oV.vis.visible = true;
                     }
                  }
               }
               catch (e:*) { }
            }
         }
         catch (e:*) { }
         // v1.87：摘除回放中重挂过的 vis（时停中已死亡对象的视觉——
         // 不摘除会在回放结束后残留成静止画面）
         try
         {
            for (var kRA:Object in reattached)
            {
               try { if (kRA.vis != null && kRA.vis.parent != null) { kRA.vis.parent.removeChild(kRA.vis); } } catch (e:*) { }
            }
            reattached = new Dictionary();
         }
         catch (e:*) { }
         // v1.106：回放结束时清空全部残留粒子——回放末段爆炸的粒子寿命
         // 尚未耗尽（v1.105 日志实证：idx=200 时仍有 22 个粒子存活，回放
         // 210 结束），火光尾焰溢出到回放结束之后（"火光一直留着，回放
         // 结束后才消失"=鬼影）。清空后火光随回放一起结束；回放结束后的
         // 世界正常运行时环境粒子自然重生。
         // v1.108：改走 killPartsDeep（remVisual+setNull+孤儿 vis 扫除——与
         // endSandy 同款，防回放爆炸粒子死亡后 vis 遗留在爆炸位置）。
         // v1.111：改为 resumePartsAtEnd——不再瞬间清空（用户实测"未播完的
         // 爆炸动画回放结束后直接被清除"）：世界恢复步进后粒子按剩余 liv
         // 自然播完死亡；MC 型恢复 play() 防冻帧；孤儿 vis 扫除保留。
         // v1.113：回放中 liv 钳制已移除——爆炸按原生速度/原生时长播完
         // （野火核弹 balefire 60 帧不再被压成 20 帧 3 倍速）。
         resumePartsAtEnd();
         // v1.98：恢复回放中惰性化的重执行爆炸体——仍存活在飞的（录像原体
         // 时停末未爆/未配对孪生体）回放结束后继续自然飞行/爆炸；已被 boom
         // 终止或已 babah/出链的不恢复（防第二次爆炸）。
         try
         {
            for (var kTE:Object in twinSavExpl)
            {
               try
               {
                  if (kTE != null && kTE.in_chain == true && kTE.liv > 0 && kTE.babah != true)
                  {
                     kTE.isExpl = false;
                     kTE.damageExpl = twinSavExpl[kTE];
                  }
               }
               catch (e:*) { }
               try { delete twinSavExpl[kTE]; } catch (e:*) { }
            }
         }
         catch (e:*) { }
         // 清空场景重演记录
         replayObjs = new Dictionary();
         replayAnimCat = new Dictionary();
         replayBlit.reset();
         replayObjArr = [];
         seenPos = new Dictionary();
         // 回放结束：切回时停结束时手上的武器，恢复弹夹/背包（弹夹剩余=时停结束时）
         try
         {
            // 取消残留切换动画（回放结束的切换同样立即生效）
            try { world.gg.work = ""; world.gg.t_work = 0; } catch (e:*) { }
            // 恢复回放中改过的武器攻速（rapid）
            for (var rid:String in savedRapids)
            {
               try
               {
                  var wR:* = world.invent.weapons[rid];
                  if (wR != null) { wR.rapid = savedRapids[rid]; }
               }
               catch (e:*) { }
            }
            savedRapids = {};
            // v1.100：弹药防泄漏绳——回放结束后的数帧内，若游戏侧弹药返还
            // （换弹型 reloadWeapon / unloadWeapon 把弹匣倒回背包）发生在
            // 快照恢复**之后**，武器A的弹药仍会增加（用户实测：时停中用A
            // 开火再切到B→回放后A弹药增加）。恢复后 4 秒内每帧对背包弹药
            // 超过快照值的部分按快照钳制（只钳"多出来的"——正常开火/换弹
            // 是减少，不受影响），非当前武器的弹匣同样钳制（已收起武器
            // 不可能被玩家操作）。restoreSandyEndSnap 末尾会置空
            // sandyEndSnap，故先保存引用。
            try
            {
               if (sandyEndSnap != null)
               {
                  leashSnap = sandyEndSnap;
                  leashLeft = 120;
                  leashDiagCnt = 0;
               }
            }
            catch (e:*) { }
            switchToWeapon(endWeapon);
            restoreSandyEndSnap();
            // 恢复武器耐久/魔法值（回放重演不应二次消耗）
            try
            {
               if (endSnapWpnHp >= 0 && world.gg.currentWeapon != null)
               {
                  world.gg.currentWeapon.hp = endSnapWpnHp;
               }
               if (endSnapMana >= 0 && world.gg["mana"] != null)
               {
                  world.gg["mana"] = endSnapMana;
               }
            }
            catch (e:*) { }
            endSnapWpnHp = -1;
            endSnapMana = -1;
            // 手雷库存恢复（v1.81：回放重演抛掷不应二次消耗——恢复至时停结束
            // 时数量，同步修正负重）
            try
            {
               if (gSnapKol >= 0)
               {
                  var twG2:* = world.gg["throwWeapon"];
                  if (twG2 != null && twG2.ammo != null && world.invent != null
                      && world.invent.items != null && world.invent.items[twG2.ammo] != null)
                  {
                     var itG:* = world.invent.items[twG2.ammo];
                     var dKol:Number = gSnapKol - itG.kol;
                     if (dKol != 0)
                     {
                        try
                        {
                           if (world.invent.mass != null && world.invent.mass[2] != null && itG.mass != null)
                           {
                              world.invent.mass[2] += dKol * itG.mass;
                           }
                        }
                        catch (e:*) { }
                        itG.kol = gSnapKol;
                     }
                  }
                  gSnapKol = -1;
               }
            }
            catch (e:*) { }
            // 恢复被投掷单位的 damWall（时停中清零延后撞墙伤害——伤害已在
            // 回放撞击帧结算；恢复后世界正常运行）+ 清空撞击记录
            try
            {
               for (var kT:Object in thrownDamWall)
               {
                  try { kT.damWall = thrownDamWall[kT]; } catch (e:*) { }
               }
               // v1.86：被投掷敌人的惯性恢复——用节流步前速度快照的
               // 末次值（时停末仍在飞行的单位），回放结束后继续沿投掷方向飞行
               try
               {
                  for (var kPV:Object in thrownPreV)
                  {
                     try
                     {
                        kPV.dx = thrownPreV[kPV].dx;
                        kPV.dy = thrownPreV[kPV].dy;
                     }
                     catch (e:*) { }
                  }
               }
               catch (e:*) { }
               thrownDamWall = new Dictionary();
               thrownImpacts = new Dictionary();
               thrownPreV = new Dictionary();
               thrownUnits = new Dictionary();
            }
            catch (e:*) { }
            replayWpn = null;
         }
         catch (e:*) { log("[SandyMod] endReplay restore error: " + e); }


         if (debugTest)
         {
            try
            {
               var c:Object = world.ctr;
               log("[DIAG] endReplay: keyLeft=" + c.keyLeft + " keyRight=" + c.keyRight + " keyJump=" + c.keyJump
                   + " keyAttack=" + c.keyAttack + " keyTele=" + c.keyTele + " ggControl=" + world.gg.ggControl
                   + " onPause=" + world.onPause + " allStat=" + world.allStat
                   + " focus=" + world.swfStage.focus);
            }
            catch (e:*) { log("[DIAG] endReplay state err: " + e); }
         }
      }

      // ==================== 残影 ====================
      // 位图不透明像素质心 x（网格采样，用于翻转对照诊断判定镜像是否生效）
      private function ghostCenterX(bd:BitmapData):Number
      {
         var s:Number = 0;
         var wSum:Number = 0;
         try
         {
            for (var yy:int = 40; yy < bd.height - 40; yy += 8)
            {
               for (var xx:int = 20; xx < bd.width - 20; xx += 8)
               {
                  var al:int = bd.getPixel32(xx, yy) >>> 24;
                  if (al > 0)
                  {
                     s += xx * al;
                     wSum += al;
                  }
               }
            }
         }
         catch (e:*) { }
         return wSum > 0 ? s / wSum : -1;
      }

      private function spawnGhost(gg:Object, ct:ColorTransform):void
      {
         try
         {
            // 叠加防护：位移不足不生成（静止时大量残影堆叠在同一位置会破坏
            // 房间图层显示）；总数上限（无限寿命残影，超限移除最旧的）
            var dgx:Number = gg.X - lastGhostX;
            var dgy:Number = gg.Y - lastGhostY;
            if (dgx * dgx + dgy * dgy < 64) { return; }
            lastGhostX = gg.X;
            lastGhostY = gg.Y;
            if (ghosts.length >= 50)
            {
               var go:Object = ghosts.shift();
               try { if (go.s.parent != null) go.s.parent.removeChild(go.s); } catch (e:*) { }
               try { go.b.dispose(); } catch (e:*) { }
            }
            var vis:* = gg.vis;
            if (vis == null || !vis.visible) { log("[DIAG] spawnGhost skip: vis null/not visible"); return; }
            var w:Number = vis.width;
            var h:Number = vis.height;
            if (w < 1 || h < 1) { log("[DIAG] spawnGhost skip: w=" + w + " h=" + h); return; }
            var bmp:BitmapData = new BitmapData(w, h, true, 0);
            var m:Matrix = new Matrix();
            var b:Rectangle = vis.getBounds(vis);
            m.tx = -b.left;
            m.ty = -b.top;
            var savedHp:Boolean = false;
            if (gg.hpbar != null && gg.hpbar.visible) { savedHp = true; gg.hpbar.visible = false; }
            // 消除双重缩放：draw 会应用父级链变换（world.visual 相机缩放 0.667），
            // 临时脱离父容器绘制（同帧加回，无渲染间隙），残影尺寸与玩家本体一致
            var savedParent:Object = vis.parent;
            var savedIdx:int = -1;
            if (savedParent != null)
            {
               try { savedIdx = savedParent.getChildIndex(vis); } catch (e:*) { }
               try { savedParent.removeChild(vis); } catch (e:*) { }
            }
            // 朝向镜像（根因修复）：draw 的 matrix 参数替换源显示变换（忽略 vis.scaleX），
            // 动画帧是朝右绘制的——朝左（storona<0）时用水平翻转矩阵画出镜像内容
            var dm:Matrix = m;
            if (gg.storona < 0) { dm = new Matrix(-1, 0, 0, 1, b.right, m.ty); }
            bmp.draw(vis as IBitmapDrawable, dm, ct, "normal", null, true);
            if (savedParent != null)
            {
               try { savedParent.addChildAt(vis, savedIdx); } catch (e:*) { }
            }
            if (savedHp) gg.hpbar.visible = true;
            if (debugTest || cfgDiagLog)
            {
               // 质心诊断：cxA<mid=内容偏左（朝左），cxA>mid=内容偏右（朝右）
               var cxA:Number = ghostCenterX(bmp);
               log("[DIAG] mirror: cxA=" + cxA + " mid=" + (w / 2)
                   + " storona=" + gg.storona + " visScaleX=" + vis.scaleX);
            }
            var bit:Bitmap = new Bitmap(bmp, "auto", true);
            var spr:Sprite = new Sprite();
            spr.x = vis.x + b.left;
            spr.y = vis.y + b.top;
            log("[DIAG] spawnGhost: gg.X=" + gg.X + " gg.Y=" + gg.Y + " vis.x=" + vis.x + " vis.y=" + vis.y
                + " b.left=" + b.left + " b.top=" + b.top + " b.w=" + b.width + " b.h=" + b.height
                + " storona=" + gg.storona + " vis.scaleX=" + vis.scaleX + " spr.x=" + spr.x + " spr.y=" + spr.y
                + " ghostParent=" + (ghostLayer.parent == world.visual));
            spr.addChild(bit);
            bit.blendMode = cfgGhostBlend == 0 ? "add" : "normal";
            ghostLayer.addChild(spr);
            ghosts.push({ s: spr, t: -1, life: 0, b: bmp });   // 无限残影（时停结束才清除）
         }
         catch (e:*) { log("[DIAG] spawnGhost ERROR: " + e + " vis=" + (world != null && world.gg != null ? world.gg.vis : "n/a")); }
      }

      private function spawnGhostAt(x:Number, y:Number, s:Number, rot:Number, sc:Number, ct:ColorTransform):void
      {
         try
         {
            var gg:Object = world.gg;
            if (gg == null || gg.vis == null) return;
            var vis:* = gg.vis;
            var w:Number = vis.width;
            var h:Number = vis.height;
            if (w < 1 || h < 1) return;
            var bmp:BitmapData = new BitmapData(w, h, true, 0);
            var m:Matrix = new Matrix();
            var b:Rectangle = vis.getBounds(vis);
            m.tx = -b.left;
            m.ty = -b.top;
            // 朝向镜像（根因修复）：draw 的 matrix 替换源显示变换（忽略 vis.scaleX），
            // 动画帧是朝右绘制的——历史朝向 s<0 时用水平翻转矩阵画出镜像内容
            var dm:Matrix = m;
            if (s < 0) { dm = new Matrix(-1, 0, 0, 1, b.right, m.ty); }
            // 消除双重缩放（同 spawnGhost：临时脱离父容器绘制）
            var savedParent:Object = vis.parent;
            var savedIdx:int = -1;
            if (savedParent != null)
            {
               try { savedIdx = savedParent.getChildIndex(vis); } catch (e:*) { }
               try { savedParent.removeChild(vis); } catch (e:*) { }
            }
            bmp.draw(vis as IBitmapDrawable, dm, ct, "normal", null, true);
            if (savedParent != null)
            {
               try { savedParent.addChildAt(vis, savedIdx); } catch (e:*) { }
            }
            if (debugTest || cfgDiagLog)
            {
               // 质心诊断：cxA<mid=内容偏左（朝左），cxA>mid=内容偏右（朝右）
               var cxA:Number = ghostCenterX(bmp);
               log("[DIAG] ghostAt-f: s=" + s + " storona=" + gg.storona + " visScaleX=" + vis.scaleX
                   + " cxA=" + cxA + " mid=" + (w / 2));
            }
            var bit:Bitmap = new Bitmap(bmp, "auto", true);
            var spr:Sprite = new Sprite();
            spr.x = x + b.left;
            spr.y = y + b.top;
            log("[DIAG] spawnGhostAt: x=" + x + " y=" + y + " b.left=" + b.left + " b.top=" + b.top
                + " spr.x=" + spr.x + " spr.y=" + spr.y + " vis.w=" + vis.width + " vis.h=" + vis.height
                + " gg.vis.x=" + gg.vis.x + " gg.vis.y=" + gg.vis.y + " gg.X=" + gg.X + " gg.Y=" + gg.Y);
            spr.rotation = rot;
            spr.addChild(bit);
            bit.blendMode = cfgGhostBlend == 0 ? "add" : "normal";
            ghostLayer.addChild(spr);
            ghosts.push({ s: spr, t: Math.max(1, cfgReplayGhostLife), life: Math.max(1, cfgReplayGhostLife), b: bmp });  // 回放残影：寿命可配置（replayghostlife）
         }
         catch (e:*) { log("[DIAG] spawnGhostAt ERROR: " + e); }
      }

      // ===== 清除全部残影（时停结束/新时停开始时调用——时停残影无限寿命）=====
      private function clearAllGhosts():void
      {
         for each (var g:Object in ghosts)
         {
            try { if (g.s.parent != null) g.s.parent.removeChild(g.s); } catch (e:*) { }
            try { g.b.dispose(); } catch (e:*) { }
         }
         ghosts = [];
      }

      private function updateGhosts():void
      {
         if (ghosts.length == 0) return;
         var i:int = ghosts.length - 1;
         while (i >= 0)
         {
            var g:Object = ghosts[i];
            if (g.t < 0)
            {
               // 无限残影（时停期间）：恒定低透明度，只在时停结束统一清除
               g.s.alpha = Math.max(0.05, Math.min(1, cfgGhostAlpha / 100));
            }
            else
            {
               g.t--;
               // 回放残影淡出：基准透明度 = ghostalpha（默认 60%），随寿命线性衰减
               g.s.alpha = (g.t / (g.life != null && g.life > 0 ? g.life : 30)) * Math.max(0.05, Math.min(1, cfgGhostAlpha / 100));
               if (g.t <= 0)
               {
                  if (g.s.parent != null) g.s.parent.removeChild(g.s);
                  g.b.dispose();
                  ghosts.splice(i, 1);
               }
            }
            i--;
         }
      }

      // 窗口失焦：Flash 会丢失按键 UP 事件导致卡键（游戏自身 bug），模组兜底清理
      private function onDeactivateClear(e:Event):void
      {
         if (keybinds != null) keybinds.releaseAll();
         if (authority != null && authority.attached) { authority.release(); return; }
         try
         {
            if (world != null && world.ctr != null)
            {
               world.ctr.clearAll();
               var kd:* = world.ctr["keyDowns"];
               if (kd != null)
               {
                  for (var i:int = 0; i < kd.length; i++) { kd[i] = false; }
               }
            }
            keyPressTime = new Array();
         }
         catch (err:*) { }
      }

      // 鼠标按住/按下脉冲状态（快速连点同帧 DOWN+UP 时按住状态会被立即清除，
      // 用脉冲记录"本帧发生过按下"，供历史记录真实攻击意图）
      private function onMouseDown(e:MouseEvent):void
      {
         try { mouseAtkDown = true; mouseAtkPulse = true; } catch (err:*) { }
      }

      private function onMouseUp(e:MouseEvent):void
      {
         try { mouseAtkDown = false; } catch (err:*) { }
      }

      private function onKeyUp(e:KeyboardEvent):void
      {
         if (keybinds != null) keybinds.releaseKey(e.keyCode);
         if (authority != null && authority.attached) { authority.key(e.keyCode, false); return; }
         // 输入法真卡键判定：UP 无对应 DOWN（2 秒内 >=2 次才算真卡键；
         // 输入法切换瞬间会出现 1 次，属正常不警告）
         if (e.keyCode > 0 && e.keyCode < 256)
         {
            var dt:* = keyDownSeen[e.keyCode];
            if (dt == null)
            {
               var nowM:int = getTimer();
               if (nowM - imeMissTime > 2000) { imeMissCount = 1; imeMissTime = nowM; }
               else { imeMissCount++; }
               if (imeMissCount >= 2)
               {
                  // v1.125：输入法警告 UI 已移除（用户要求），保留诊断日志
                  if (cfgDiagLog) { try { log("[IME] miss x" + imeMissCount + " kc=" + e.keyCode); } catch (err:*) { } }
               }
               else if (cfgDiagLog)
               {
                  try { log("[IME] miss x1 kc=" + e.keyCode + " (switch transient, no warn)"); } catch (err:*) { }
               }
            }
            keyDownSeen[e.keyCode] = null;
         }
         if (cfgDiagLog)
         {
            try { log("[KEY] U " + e.keyCode); } catch (err:*) { }
         }
         try
         {
            if (keyPressTime[e.keyCode] != null)
            {
               keyPressTime[e.keyCode] = null;
            }
         }
         catch (err:*) { }
      }

      // ==================== 输入 ====================
      private function onKey(e:KeyboardEvent):void
      {
         if (keybinds != null && keybinds.isCapturingKey()) return;
         if (authority != null && authority.attached) {
            if (keybinds != null && keybinds.press(e)) authority.key(e.keyCode, true);
            return;
         }
         // ===== 中文输入法（IME）检测 =====
         // 真卡键特征：字母键的 KEY_DOWN 被输入法在系统层截获（只发 229 或直接丢失），
         // 随后只有 KEY_UP 到达。判定：
         //   1) 收到 KEY_UP 但之前没有对应 KEY_DOWN → 该键 DOWN 被吃 → 真卡键 → 警告
         //   2) 短时间内连续出现 229 事件（>=2 次/3秒）→ 输入法活跃 → 警告
         // 单个 229 不警告（输入法切换瞬间/英文模式 Shift 等也会产生，属正常）
         if (e.keyCode == 229)
         {
            var nowT:int = getTimer();
            if (nowT - ime229Time > 3000) { ime229Count = 1; ime229Time = nowT; }
            else { ime229Count++; }
            if (ime229Count >= 2)
            {
               // v1.125：输入法警告 UI 已移除（用户要求），保留诊断日志
               if (cfgDiagLog) { try { log("[IME] 229 x" + ime229Count); } catch (err:*) { } }
            }
         }
         else if (e.keyCode > 0 && e.keyCode < 256)
         {
            keyDownSeen[e.keyCode] = getTimer();
         }

         // v1.104：疾跑中切枪（swaprun）——事件层拦截。游戏 World.step 挂在
         // MainMenu.mainStep 的 ENTER_FRAME 上（先于模组注册，MainMenu 在模组
         // 加载前创建）——v1.100 的 onFrame 拦截永远晚于游戏按键处理（游戏
         // control() 先按第二组快捷槽消费按键，实测无 swapRun 日志）；而模组
         // 的 KEY_DOWN 先于游戏 Ctr 注册（Ctr 在 World 构造时才注册）。此处
         // 直接消费按键+useFav 第一组槽位，并 stopImmediatePropagation 阻止
         // 游戏 Ctr 收到该键（防第二组槽重复处理）。
         // v1.127：技能已迁移 mods/MoreSkills&Weapons（MSWSwaprun.as）——
         // cfgSwapRun 恒 false（默认关、config 键移除、面板行移除），
         // 本拦截不再触发，代码保留作备份（完整源码见 state/migration-backup-v1.126/）。
         try
         {
            if (cfgSwapRun && !replaying && world != null && world.ctr != null
                && world.ctr.keyRun && e.keyCode > 0 && e.keyCode < 256)
            {
               var kbS:* = keyMap[e.keyCode];
               if (kbS != null && String(kbS).indexOf("keyWeapon") == 0 && inGameplay())
               {
                  var wnS:int = parseInt(String(kbS).substr(9));
                  if (wnS >= 1 && wnS <= 10)
                  {
                     e.stopImmediatePropagation();
                     try { world.invent.useFav(wnS); } catch (e2:*) { }
                     try { if (world.gg.visSel) { world.gui.unshowSelector(0); } } catch (e2:*) { }
                     try { if (world.gg.currentSpell != null) { world.gg.currentSpell.active = false; } } catch (e2:*) { }
                     try { world.ctr.keyDef = false; world.ctr.keyAttack = false; } catch (e2:*) { }
                     if (cfgDiagLog && swapRunDiagCnt < 6)
                     {
                        swapRunDiagCnt++;
                        log("[DIAG] swapRun: key=" + wnS + " run=" + world.ctr.keyRun);
                     }
                     return;
                  }
               }
            }
         }
         catch (e2:*) { }

         // ===== 按键诊断（diaglog=1 时记录按键事件与游戏状态，用于定位卡键）=====
         if (cfgDiagLog)
         {
            try
            {
               log("[KEY] D " + e.keyCode + "->" + keyMap[e.keyCode]
                   + " pip=" + (world != null && world.pip != null ? world.pip.active : -1)
                   + " stand=" + (world != null && world.stand != null ? world.stand.active : -1)
                   + " consol=" + (world != null ? world.onConsol : -1)
                   + " setkey=" + (world != null && world.ctr != null ? world.ctr.setkeyOn : -1)
                   + " guiPause=" + (world != null && world.gui != null ? world.gui.guiPause : -1)
                   + " ctrActive=" + (world != null && world.ctr != null ? world.ctr.active : -1)
                   + " focus=" + (world != null ? world.swfStage.focus : -1));
            }
            catch (err:*) { }
         }

         // ===== 卡键自愈（游戏本体 bug：clearAll 不清 keyDowns + 失焦丢 UP）=====
         // keyDowns 是 internal 无法访问；改为：KEY_DOWN 时按 keyXML 键位表
         // 强制设置键布尔（public），无论游戏是否因 keyDowns 残留而忽略本次按键，
         // 按键都立即生效。UI 占用输入时（键位重绑/菜单/商店）跳过。
         try
         {
            if (world != null && world.ctr != null)
            {
               var cc:Object = world.ctr;
               if (!cc.setkeyOn && !(world.pip != null && world.pip.active) && !(world.stand != null && world.stand.active))
               {
                  var kb2:* = keyMap[e.keyCode];
                  if (kb2 != null)
                  {
                     cc[kb2] = true;
                  }
               }
            }
         }
         catch (err:*) { }

         if (keyPressTime[e.keyCode] == null)
         {
            keyPressTime[e.keyCode] = getTimer();
         }
         if (keybinds != null && keybinds.press(e))
         {
            if (sandyActive)
            {
               endSandy();
               e.stopPropagation();
            }
            else if (replaying)
            {
               // 回放中忽略
            }
            else if (cooldownLeft <= 0)
            {
               startSandy();
               e.stopPropagation();
            }
         }
         else if (sandyActive)
         {
            // 时停期间屏蔽 SATS / PipBuck / 交互键（E），避免触发对话锁死控制
            try
            {
               var ctr:Object = world.ctr;
               if (ctr == null) return;
               if (e.keyCode == ctr.keyIds["keySats"].a1 || (ctr.keyIds["keySats"].a2 != null && e.keyCode == ctr.keyIds["keySats"].a2))
               {
                  ctr.keySats = false;
               }
               if (e.keyCode == ctr.keyIds["keyPip"].a1)
               {
                  ctr.keyPip = false;
               }
               if (e.keyCode == ctr.keyIds["keyAction"].a1)
               {
                  ctr.keyAction = false;
               }
            }
            catch (err:*) { }
         }
         // v1.129：按交互键(E)时采样念力抓取目标状态（诊断"无法抓敌人"）
         try
         {
            var ctrT:Object = world != null ? world.ctr : null;
            if (ctrT != null && ctrT.keyIds != null && ctrT.keyIds["keyAction"] != null)
            {
               var ka1:int = 0;
               var ka2:int = -1;
               try { ka1 = int(ctrT.keyIds["keyAction"].a1); } catch (e2:*) { }
               try { ka2 = ctrT.keyIds["keyAction"].a2 != null ? int(ctrT.keyIds["keyAction"].a2) : -1; } catch (e2:*) { }
               if (e.keyCode == ka1 || (ka2 > 0 && e.keyCode == ka2))
               {
                  teleDiag();
               }
            }
         }
         catch (e:*) { }
      }

      // ==================== HUD ====================
      private function authoritySettings():Object
      {
         return {hotkey:cfgHotkey,duration:cfgDuration,cooldown:cfgCooldown,
            slowFactor:cfgSlowFactor,replaySpeed:cfgReplaySpeed,ghostEvery:cfgGhostEvery};
      }
      private function presentAuthority(state:Object):void
      {
         var busy:Boolean = authorityState != null && authorityState.phase != "idle";
         var nextBusy:Boolean = state != null && state.phase != "idle";
         authorityState = state;
         if (!busy && nextBusy) playTheme();
         if (busy && !nextBusy) fadeTheme();
         updateHud();
      }
      private function updateHud():void
      {
         if (world == null || world.main == null) return;
         // v1.125：顶部状态 UI 开关（showhud）——关闭时全部隐藏
         if (!cfgHud)
         {
            if (hud != null) { hud.visible = false; }
            if (hudBg != null) { hudBg.visible = false; }
            return;
         }
         if (hud == null)
         {
            hud = new TextField();
            var tf:TextFormat = new TextFormat();
            tf.font = "Consolas";           // PipBuck 终端等宽风
            tf.size = 15;
            tf.bold = false;
            tf.color = 0x00FF99;            // 荧光绿
            tf.letterSpacing = 1;
            hud.defaultTextFormat = tf;
            hud.selectable = false;
            hud.mouseEnabled = false;
            hudBg = new Sprite();
            world.main.addChild(hudBg);
            world.main.addChild(hud);
         }
         var txt:String = "";
         if (authorityState != null)
         {
            if (authorityState.phase == "record") txt = "⚡ 斯安维斯坦 " + (Number(authorityState.left) / 30).toFixed(1) + "s";
            else if (authorityState.phase == "replay") txt = "⟲ 回放中…";
            else if (authorityState.cooldown > 0) txt = "斯安维斯坦 充能中 " + (Number(authorityState.cooldown) / 30).toFixed(1) + "s";
         }
         else if (sandyActive)
         {
            txt = "⚡ 斯安维斯坦 " + (sandyLeft / 30).toFixed(1) + "s";
         }
         else if (replaying)
         {
            txt = "⟲ 回放中…";
         }
         else if (cooldownLeft > 0)
         {
            txt = "斯安维斯坦 充能中 " + (cooldownLeft / 30).toFixed(1) + "s";
         }
         if (txt != "")
         {
            SandyLocale.bind(hud,txt);
            var st:Object = world.swfStage != null ? world.swfStage : world.main.stage;
            var sw:Number = 1280;
            try { sw = st.stageWidth; } catch (e:*) { }
            hud.x = (sw - hud.textWidth) / 2 - 6;
            hud.y = 12;
            hud.width = hud.textWidth + 12;
            hud.height = 28;
            hud.visible = true;
            var fg:uint = 0x00FF99;
            if (sandyActive) fg = 0x00FFFF;   // 激活: 青色
            else if (replaying) fg = 0xFFFF00; // 回放: 黄色
            if (authorityState != null && authorityState.phase == "record") fg = 0x00FFFF;
            else if (authorityState != null && authorityState.phase == "replay") fg = 0xFFFF00;
            hud.textColor = fg;
            hudBg.graphics.clear();
            hudBg.graphics.lineStyle(1, fg, 0.9);              // 荧光边框
            hudBg.graphics.beginFill(0x002211, 0.7);           // 深绿黑底
            hudBg.graphics.drawRect(hud.x - 8, hud.y - 4, hud.width + 16, hud.height + 8);
            hudBg.graphics.endFill();
            hudBg.visible = true;
         }
         else
         {
            hud.visible = false;
            hudBg.visible = false;
         }
      }
   }
}
