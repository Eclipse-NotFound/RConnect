package rconnect.game
{
   import flash.display.Stage;
   import flash.events.Event;
   import flash.geom.ColorTransform;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.text.TextFormat;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;

   /**
    * 游戏本体桥接。
    *
    * 约束（shared-knowledge/knowledge-validation/facts/modding-interop.md）：
    * - 只能访问 public 成员 + 反射；internal/private 不可访问。
    * - 密封类对不存在成员做 bracket 访问会抛 ReferenceError #1069 且吞掉外层
    *   try —— 所以每个字段访问都必须独立 try 探测，不用大 try 包一坨。
    *
    * 入口链路（反编译 1.02/1.03/1.04 确认）：
    *   fe.World.w  (public static)  →  World 实例
    *   World.gg    (public)        →  玩家 UnitPlayer
    *   World.loc   (public)        →  当前 Location
    * 注意：单位坐标字段是大写 X/Y（fe.Pt），不是 x/y。
    *
    * 幽灵单位（M2/M9/M10）：
    * - 用 UnitPonPon（被动 NPC 小马，自带 visualStabPon 视觉，无武器逻辑）；
    * - 入世界顺序与游戏建敌一致：putLoc → loc.addObj(挂视觉) → loc.units.push；
    * - 惰性化（ghostCombat=false）：doop=true（无碰撞、AI 不会选为 priorUnit）、
    *   unres=true（无伤）、fraction=100、warn=0；addVisual 之后再 disabled=true。
    * - 战斗化身（ghostCombat=true，M10a）：doop/unres/invulner=false 且
    *   **disabled=false**——isMeet 要求 !disabled，活体才能被敌人 findCel 锁定
    *   （priorUnit 粘滞）并被打；UnitPonPon.control() 只有气泡台词，
    *   id_replic=""（public）禁言后启用安全。
    * - M10b：宿主化身与客户端生命状态协调（死亡被动化/复活重建/跨土地隐藏）。
    * - 驱动：setPos + setVisPos（含 storona 翻转）+ dx/dy/stay 镜像。
    * - 销毁：loc.remObj（摘视觉）+ units.splice，与游戏移除单位方式一致。
    */
   public class GameBridge
   {
      public var main:Object;
      public var world:Object;       // fe.World 实例（未进游戏时为 null）
      public var gg:Object;          // 玩家 UnitPlayer（探测缓存）
      public var loc:Object;         // 当前 Location
      /** M5a：客户端冻结被同步单位 AI（由 Session 按配置注入）。 */
      public var freezeAI:Boolean = false;
      /** M9：宿主侧客户端幽灵作为可攻击化身（可被打、可被敌人瞄准）。 */
      public var ghostCombat:Boolean = true;
      /** M10b 测试钩子：ghostDamageTest 单次伤害量（联测可设大值触发死亡流程）。 */
      public var testGhostDmg:Number = 50;

      private var _remotes:Object = {};
      private var _snapLogged:Boolean = false;
      private var _ghostErrLogged:Boolean = false;
      private var _autoStage:int = 0;
      private var _autoStageT:int = 0;
      private var _autoTries:int = 0;

      public function GameBridge(main:Object)
      {
         this.main = main;
         // M12：拦截 Stage DEACTIVATE——游戏在 World 构造时用默认优先级注册
         // onDeactivate（失焦 → pip.onoff(11) 打开 PipBuck 且永不自动关闭，
         // 导致 allStat=2、旅行/场景冻结、"两侧房间不同"）。用更高优先级
         // 抢先 stopImmediatePropagation，让游戏的失焦开 pip 永久不触发。
         try
         {
            var st:Stage = main["stage"] as Stage;
            if(st != null)
            {
               st.addEventListener(Event.DEACTIVATE, onStageDeactivate,
                  false, 1000, true);
            }
         }
         catch(err:*)
         {
         }
         refreshWorld();
      }

      /** M12：抢在游戏 onDeactivate 前拦住失焦事件（失焦开 pip 是游戏 bug）。 */
      private function onStageDeactivate(e:Event):void
      {
         try
         {
            e.stopImmediatePropagation();
         }
         catch(err:*)
         {
         }
      }

      /** 定时重探 world（进游戏/切换场景后 World.w/loc 变化）。 */
      public function refreshWorld():void
      {
         world = null;
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var worldCls:Object = ad["getDefinition"]("fe.World");
            if(worldCls != null)
            {
               var w:Object = worldCls["w"];
               if(w != null)
               {
                  world = w;
               }
            }
         }
         catch(err:*)
         {
            world = null;
         }
         gg = world != null ? probe(world, "gg") : null;
         loc = world != null ? probe(world, "loc") : null;
      }

      /** 程序化开新游戏（公开入口 World.newGame）。主菜单时调用。 */
      public function startGame():void
      {
         try
         {
            if(world == null)
            {
               refreshWorld();
            }
            if(world == null)
            {
               Log.d("RConnectGame: startGame: no world yet");
               return;
            }
            if(gg != null)
            {
               Log.d("RConnectGame: startGame: already in game");
               _autoStage = 0;
               return;
            }
            var g0:Object = probe(world, "game");
            if(g0 != null)
            {
               // newGame 已调用过，等待后续流程，不要重置
               return;
            }
            if(_autoTries >= 3)
            {
               return;
            }
            _autoTries++;
            Log.d("RConnectGame: startGame: calling newGame (try "
               + _autoTries + ")");
            world["newGame"](0, "LP", null);
            _autoStage = 1;
            _autoStageT = flash.utils.getTimer();
         }
         catch(err:*)
         {
            Log.d("RConnectGame: startGame failed: " + err);
         }
      }

      /**
       * autoGame 推进（由 Session.onTick 周期调用）。
       * 关键机制：主菜单打开时（MainMenu.active=true）World.step 不运行，
       * newGame 的 ng_wait 流程不会前进；需把 mm.active 置 false 让游戏
       * 主循环接管（等价于程序化关闭菜单）。
       */
      public function tickAutoGame():void
      {
         if(_autoStage <= 0 || world == null)
         {
            return;
         }
         var t:int = flash.utils.getTimer();
         if(_autoStage == 1 && t - _autoStageT > 1500)
         {
            // 关闭主菜单，游戏循环开始驱动 ng_wait（newGame1→newGame2→进游戏）
            var mm:Object = probe(world, "mm");
            if(mm != null)
            {
               try
               {
                  mm["active"] = false;
                  Log.d("RConnectGame: autoGame: menu closed, world.step "
                     + "should take over");
               }
               catch(err:*)
               {
                  Log.d("RConnectGame: autoGame: close menu failed: " + err);
               }
            }
            _autoStage = 2;
            _autoStageT = t;
         }
         else if(_autoStage == 2 && t - _autoStageT > 15000)
         {
            // 超时仍未进游戏：重置，允许重试（最多 _autoTries 次）
            if(gg == null)
            {
               Log.d("RConnectGame: autoGame: timeout waiting for gg");
            }
            _autoStage = 0;
         }
      }

      /** 安全探测成员；成员不存在/不可访问时返回 null。 */
      public static function probe(o:Object, name:String):*
      {
         if(o == null)
         {
            return null;
         }
         try
         {
            var v:* = o[name];
            return (v === undefined) ? null : v;
         }
         catch(err:*)
         {
            return null;
         }
      }

      /** 数值型字段探测（外部类用）：缺失/不可读/非有限 → def。 */
      public static function probeNum(o:Object, name:String, def:Number):Number
      {
         var v:* = probe(o, name);
         return (v != null && isFinite(Number(v))) ? Number(v) : def;
      }

      /** 采集本机玩家状态快照（联机发送用）。无世界/无玩家时返回 null。 */
      public function readSnapshot():Object
      {
         if(world == null || gg == null)
         {
            refreshWorld();
         }
         if(world == null || gg == null)
         {
            return null;
         }
         var s:Object = {};
         s.x = numOr(probe(gg, "X"), 0);
         s.y = numOr(probe(gg, "Y"), 0);
         s.storona = numOr(probe(gg, "storona"), 1);
         s.dx = numOr(probe(gg, "dx"), 0);
         s.dy = numOr(probe(gg, "dy"), 0);
         s.stay = numOr(probe(gg, "stay"), 0);
         s.hp = numOr(probe(gg, "hp"), -1);
         s.maxhp = numOr(probe(gg, "maxhp"), 100);
         s.sost = numOr(probe(gg, "sost"), -1);
         // M10b：带土地/房间身份，宿主据此隐藏"在别的土地"的客户端化身
         var g0:Object = probe(world, "game");
         s.landId = g0 != null ? String(probe(g0, "curLandId")) : "";
         s.locId = loc != null ? String(probe(loc, "id")) : "";
         // M14b：当前武器 id/变体（远端据此在幽灵手上镜像同款武器）
         var cw:Object = probe(gg, "currentWeapon");
         s.wi = cw != null ? String(probe(cw, "id")) : "";
         s.wv = cw != null ? int(numOr(probe(cw, "variant"), 0)) : 0;
         // M16：本机当前姿态标签（vis.osn.currentLabel）——让远端幽灵直接
         // 播放对方真实姿态（站/走/跑/蹲/趴都由对方游戏决定，不再本地猜测）
         s.pose = localPoseLabel();
         // M18：外观镜像——远端据此给幽灵穿上对方的外观（护甲/毛色/眼/魔法）
         s.ap = readAppearance();
         s.aimX = numOr(probe(world, "celX"), 0);
         s.aimY = numOr(probe(world, "celY"), 0);
         if(!_snapLogged)
         {
            _snapLogged = true;
            Log.d("RConnectGame: first snapshot x=" + s.x + " y=" + s.y
               + " storona=" + s.storona + " hp=" + s.hp);
         }
         return s;
      }

      /**
       * 应用远程玩家状态：创建/驱动幽灵单位。
       * @param id    远程玩家 id
       * @param snap  对方快照（readSnapshot 的产物）
       * @param name  远程玩家昵称（M6b：幽灵头顶标签）
       */
      public function updateRemote(id:int, snap:Object, name:String = ""):void
      {
         if(world == null || loc == null)
         {
            refreshWorld();
         }
         if(world == null || loc == null || snap == null)
         {
            return;
         }
         var rec:Object = _remotes[id];
         if(rec == null)
         {
            rec = _remotes[id] = {ghost: null, snap: null};
         }
         rec.snap = snap;
         rec.name = name;
         // M10b：客户端在别的土地（死亡回城/换图途中）→ 化身隐藏不驱动
         var myLand:String = currentLandId();
         var snapLand:String = snap.landId != null ? String(snap.landId) : "";
         if(myLand != "" && snapLand != "" && myLand != snapLand)
         {
            if(rec.ghost != null)
            {
               despawnGhost(rec.ghost, id);
               rec.ghost = null;
            }
            return;
         }
         var ghost:Object = rec.ghost;
         if(ghost != null)
         {
            // 化身被游戏移除（坠出地图/焚毁等）→ 重建
            var gone:Boolean = true;
            var unitsArr:Object = probe(loc, "units");
            if(unitsArr is Array)
            {
               gone = (unitsArr as Array).indexOf(ghost) < 0;
            }
            if(gone)
            {
               Log.d("RConnectGame: ghost #" + id + " lost from world, respawning");
               try
               {
                  despawnGhost(ghost, id);
               }
               catch(err:*)
               {
               }
               rec.ghost = null;
               ghost = null;
            }
            else
            {
               syncGhostLife(rec, id, snap);
            }
         }
         if(ghost == null)
         {
            ghost = spawnGhost(id, snap, name);
            rec.ghost = ghost;
            _ghostHp[id] = Math.max(1, numOr(snap.hp, 100));
            _ghostPassive[id] = false;
            removeWeaponVis(id);        // 新化身重建武器
            _weaponId[id] = null;
            var arec:Object = _animState[id];
            if(arec != null)
            {
               arec.label = "";   // 新化身重新驱动姿态
            }
         }
         if(ghost != null)
         {
            driveGhost(ghost, snap, id);
            syncRemoteWeapon(ghost, snap, id);
         }
      }

      /** M14b：在幽灵手上镜像远程玩家的当前武器。
       *  用公开构造 `new Weapon(owner, id, variant)`（Weapon 从游戏数据按 id
       *  取参数/视觉），把武器显示对象挂到幽灵 visualPlayer 上；武器变化时
       *  重建。视觉位置/朝向由 driveGhost 里的 weaponDrive 每帧校正。 */
      private function syncRemoteWeapon(ghost:Object, snap:Object, id:int):void
      {
         var wi:String = snap.wi != null ? String(snap.wi) : "";
         if(_weaponId[id] != null && _weaponId[id] == wi)
         {
            return;
         }
         // 移除旧武器
         removeWeaponVis(id);
         _weaponId[id] = wi;
         if(wi == "")
         {
            return;
         }
         if(_weaponSkip[wi])
         {
            return;
         }
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var wcl:Object = ad["getDefinition"]("fe.weapon.Weapon");
            var wv:int = int(numOr(snap.wv, 0));
            var w:Object = new (wcl as Class)(ghost, wi, wv);
            ghost["currentWeapon"] = w;
            var wvis:Object = probe(w, "vis");
            if(wvis != null)
            {
               var gvis:Object = probe(ghost, "vis");
               if(gvis != null)
               {
                  gvis["addChild"](wvis);
                  _weaponVis[id] = wvis;
                  Log.d("RConnectGame: weapon #" + id + " -> " + wi);
               }
            }
         }
         catch(err:*)
         {
            _weaponSkip[wi] = true;
            Log.d("RConnectGame: weapon #" + id + " '" + wi
               + "' failed: " + err);
         }
      }

      /** M14b：按快照瞄向驱动已挂载的武器（位置/旋转/翻转）。 */
      private function driveWeaponVis(ghost:Object, snap:Object, id:int):void
      {
         var wvis:Object = _weaponVis[id];
         if(wvis == null)
         {
            return;
         }
         try
         {
            var storona:Number = numOr(snap.storona, 1) >= 0 ? 1 : -1;
            var scX:Number = numOr(probe(ghost, "scX"), 30);
            var scY:Number = numOr(probe(ghost, "scY"), 60);
            wvis["x"] = scX * storona;
            wvis["y"] = -scY * 0.7;
            wvis["scaleX"] = storona;
            var ax:Number = numOr(snap.aimX, 0);
            var ay:Number = numOr(snap.aimY, 0);
            var gx:Number = numOr(probe(ghost, "X"), 0);
            var gy:Number = numOr(probe(ghost, "Y"), 0);
            wvis["rotation"] = Math.atan2(ay - gy, (ax - gx) * storona)
               * 180 / Math.PI;
         }
         catch(err:*)
         {
         }
      }

      private function removeWeaponVis(id:int):void
      {
         var wvis:Object = _weaponVis[id];
         if(wvis != null)
         {
            try
            {
               var parent:Object = wvis["parent"];
               if(parent != null)
               {
                  parent["removeChild"](wvis);
               }
            }
            catch(err:*)
            {
            }
         }
         delete _weaponVis[id];
      }

      private var _weaponVis:Object = {};
      private var _weaponId:Object = {};
      private var _weaponSkip:Object = {};

      /**
       * M10b：宿主化身与客户端生命状态协调（每次收到快照时调用）。
       * - 客户端存活：无未上报伤害时把化身血量镜像为客户端血量（嗑药/复活），
       *   并保持战斗姿态（doop/unres/invulner/disabled=false）。
       * - 客户端死亡：化身被动化（不可被锁、无伤），等复活后再恢复。
       */
      private function syncGhostLife(rec:Object, id:int, snap:Object):void
      {
         if(!ghostCombat)
         {
            return;
         }
         var ghost:Object = rec.ghost;
         if(ghost == null)
         {
            return;
         }
         var clientAlive:Boolean = numOr(snap.sost, 1) < 3
            && numOr(snap.hp, 1) > 0;
         var curHp:Number = numOr(probe(ghost, "hp"), -1);
         var gsost:Number = numOr(probe(ghost, "sost"), 1);
         if(clientAlive)
         {
            if(gsost == 1 && curHp > 0)
            {
               // 只在无未上报伤害时镜像血量（否则会吞掉待中继的最后一击）
               var base:* = _ghostHp[id];
               var baseN:Number = (base == undefined) ? curHp : Number(base);
               if(curHp >= baseN - 0.5)
               {
                  var sh:Number = numOr(snap.hp, -1);
                  if(sh >= 0 && Math.abs(sh - curHp) > 0.5)
                  {
                     ghost["hp"] = sh;
                     _ghostHp[id] = sh;
                  }
               }
               if(_ghostPassive[id])
               {
                  _ghostPassive[id] = false;
                  setGhostCombatFlags(ghost, false);
                  Log.d("RConnectGame: ghost #" + id
                     + " combat restored (client alive)");
               }
            }
            // sost>=2（宿主侧死亡/击倒）交给 scanGhostHp 整体重建：
            // 先上报最后一击，再按最新快照重建，顺序不能反。
         }
         else if(gsost == 1 && curHp > 0 && !_ghostPassive[id])
         {
            _ghostPassive[id] = true;
            setGhostCombatFlags(ghost, true);
            Log.d("RConnectGame: ghost #" + id + " passive (client dead)");
         }
      }

      /** 切换化身战斗/被动姿态（passive=true 时不可被锁、无伤、停 step）。 */
      private function setGhostCombatFlags(ghost:Object, passive:Boolean):void
      {
         try
         {
            ghost["doop"] = passive;
            ghost["unres"] = passive;
            ghost["invulner"] = passive;
            ghost["disabled"] = passive;
            ghost["fraction"] = 100;
         }
         catch(err:*)
         {
         }
      }

      /** 当前土地 id（"" = 菜单/未知）。 */
      private function currentLandId():String
      {
         if(world == null)
         {
            return "";
         }
         var game:Object = probe(world, "game");
         return game != null ? String(probe(game, "curLandId")) : "";
      }

      /** M10b：本地玩家是否处于死亡流程（t_die>0 或 sost>=3）。
       *  期间暂停自动跟随/自动移动/自动伤害，避免干扰游戏自身复活回城。 */
      public function isPlayerDead():Boolean
      {
         if(world == null || gg == null)
         {
            return false;
         }
         if(numOr(probe(gg, "sost"), 1) >= 3)
         {
            return true;
         }
         return numOr(probe(world, "t_die"), 0) > 0;
      }

      /** M11：世界过渡中（退出/死亡/读档流程）——此时外部不应改位置/
       *  旅行/跟随。读档（comLoad）、退出（t_exit）、死亡（t_die）任一
       *  进行中即视为过渡。实测：过渡期跟随/传送会把房间重置回存档出生点，
       *  造成"场景无法正常加载"的反复重进循环。 */
      public function isTransitioning():Boolean
      {
         if(world == null)
         {
            return false;
         }
         if(numOr(probe(world, "t_exit"), 0) > 0)
         {
            return true;
         }
         if(numOr(probe(world, "t_die"), 0) > 0)
         {
            return true;
         }
         if(numOr(probe(world, "comLoad"), -1) >= 0)
         {
            return true;
         }
         return false;
      }

      /** 取某远程玩家的宿主侧幽灵（M9 拉仇恨用）。 */
      public function getRemoteGhost(id:int):Object
      {
         var rec:Object = _remotes[id];
         return rec != null ? rec.ghost : null;
      }

      /** M9：宿主监测客户端幽灵受击（hp 下降量，一次性上报）。
       *  M10b：
       *  - 客户端已死 → 不上报（死亡流程由客户端本地处理），推进基线防止
       *    复活后误报；化身保底 1 血并被动化。
       *  - 化身已死/击倒而客户端存活 → 先上报最后一击，再按最新快照整体重建。
       */
      public function scanGhostHp(id:int):Number
      {
         var rec:Object = _remotes[id];
         if(rec == null)
         {
            return 0;
         }
         var ghost:Object = rec.ghost;
         if(ghost == null)
         {
            return 0;
         }
         var snap:Object = rec.snap;
         // 注意：hp 可能为负（致死一击打穿血条），不能用 cur<0 当探测失败
         var hpRaw:* = probe(ghost, "hp");
         if(hpRaw == null)
         {
            return 0;
         }
         var cur:Number = Number(hpRaw);
         if(!isFinite(cur))
         {
            return 0;
         }
         var gsost:Number = numOr(probe(ghost, "sost"), 1);
         var base:* = _ghostHp[id];
         if(base == undefined)
         {
            return 0;
         }
         var dmg:Number = 0;
         if(cur < Number(base) - 0.5)
         {
            // 上报原始命中量（base-cur 即敌人真实一击；hp 可被打成负数）。
            // 不要钳制为剩余血量——客户端 gg.damage 自带护甲减伤，
            // 钳制会造成"每击中继≈当前血量→减伤后永不致死"的收敛陷阱。
            dmg = Number(base) - cur;
            _ghostHp[id] = cur;
         }
         var clientAlive:Boolean = snap != null
            && numOr(snap.sost, 1) < 3 && numOr(snap.hp, 1) > 0;
         if(clientAlive && (cur <= 0 || gsost >= 2))
         {
            // 化身已死/击倒但客户端存活：按最新快照整体重建（位置/血量）
            var name:String = rec.name != null ? String(rec.name) : "";
            try
            {
               despawnGhost(ghost, id);
            }
            catch(err:*)
            {
            }
            ghost = spawnGhost(id, snap, name);
            rec.ghost = ghost;
            _ghostHp[id] = Math.max(1, numOr(snap.hp, 100));
            _ghostPassive[id] = false;
            var arec:Object = _animState[id];
            if(arec != null)
            {
               arec.label = "";
            }
            Log.d("RConnectGame: ghost #" + id
               + " respawned (dead avatar, client alive, last hit " + dmg + ")");
         }
         else if(!clientAlive)
         {
            // 客户端已死：推进基线 + 保底 1 血，防宿主侧被清走
            _ghostHp[id] = cur;
            if(cur <= 0)
            {
               try
               {
                  ghost["hp"] = 1;
               }
               catch(err:*)
               {
               }
               _ghostHp[id] = 1;
               if(!_ghostPassive[id] && ghostCombat && gsost == 1)
               {
                  _ghostPassive[id] = true;
                  setGhostCombatFlags(ghost, true);
                  Log.d("RConnectGame: ghost #" + id + " passive (client dead)");
               }
            }
            return 0;
         }
         return dmg;
      }

      private var _ghostHp:Object = {};
      private var _ghostPassive:Object = {};
      private var _appearanceLogged:Object = {};

      public function removeRemote(id:int):void
      {
         var rec:Object = _remotes[id];
         if(rec != null && rec.ghost != null)
         {
            despawnGhost(rec.ghost, id);
         }
         delete _remotes[id];
         delete _animState[id];
         removeWeaponVis(id);
         delete _weaponId[id];
      }

      public function remoteCount():int
      {
         var n:int = 0;
         for(var k:String in _remotes)
         {
            n++;
         }
         return n;
      }

      // ---- 幽灵单位生命周期 ---------------------------------------------

      private function spawnGhost(id:int, snap:Object, name:String = ""):Object
      {
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var cls:Object = ad["getDefinition"]("fe.unit.UnitPonPon");
            var tr:int = 5 + (id % 10);   // 不同远程玩家用不同配色
            var ghost:Object = new (cls as Class)("stab", 100, null, {tr: tr});
            // M9：宿主侧幽灵化身（可被敌人瞄准/命中，血量按客户端快照）
            // 注意：UnitPonPon 构造自带 invulner=true，必须显式关掉
            ghost["doop"] = !ghostCombat;
            ghost["unres"] = !ghostCombat;
            ghost["invulner"] = !ghostCombat;
            ghost["fraction"] = 100;   // Unit.F_PLAYER
            ghost["warn"] = 0;
            ghost["npc"] = true;
            ghost["id"] = "rconnect_ghost_" + id;   // 标记幽灵，供单位同步过滤
            ghost["id_replic"] = "";   // M10a：禁言气泡（战斗化身会跑 control()）
            ghost["hp"] = Math.max(1, numOr(snap.hp, 100));
            ghost["maxhp"] = numOr(snap.maxhp, 100);
            // 换用玩家视觉（visualPlayer，带完整姿态标签），并做与
            // UnitPlayer 构造一致的初始化（停 osn、隐藏不相关子剪辑）
            installPlayerVis(ghost, snap.ap);
            if(snap.ap != null && snap.ap.cFur != undefined
               && !_appearanceLogged[id])
            {
               _appearanceLogged[id] = true;
               Log.d("RConnectGame: ghost #" + id + " styled armor="
                  + String(snap.ap.armor) + " cFur="
                  + String(snap.ap.cFur) + " cEye=" + String(snap.ap.cEye));
            }
            applyGhostMarking(ghost, name);
            var x:Number = numOr(snap.x, 0);
            var y:Number = numOr(snap.y, 0);
            // 与 Location 建敌顺序一致：putLoc → addObj → units.push
            ghost["putLoc"](loc, x, y);
            loc["addObj"](ghost);
            var units:Object = loc["units"];
            units["push"](ghost);
            // 视觉挂上之后再改 disabled（addVisual 对 disabled 早退）
            // M10a：战斗化身必须活体（isMeet 要求 !disabled），否则敌人无法锁定
            ghost["disabled"] = !ghostCombat;
            ghost["setVisPos"]();
            Log.d("RConnectGame: ghost #" + id + " spawned at " + x + "," + y
               + " qname=" + getQualifiedClassName(ghost));
            _ghostErrLogged = false;
            return ghost;
         }
         catch(err:*)
         {
            if(!_ghostErrLogged)
            {
               _ghostErrLogged = true;
               Log.d("RConnectGame: spawnGhost failed: " + err);
            }
            return null;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return null;
      }

      /** M6b：幽灵视觉区分——半透明 + 头顶名字标签。 */
      private function applyGhostMarking(ghost:Object, name:String):void
      {
         var vis:Object = probe(ghost, "vis");
         if(vis == null)
         {
            return;
         }
         try
         {
            vis["alpha"] = 0.75;
            var tf:TextField = new TextField();
            var fmt:TextFormat = new TextFormat("_sans",
               12, 0xFFE066, true);
            tf.defaultTextFormat = fmt;
            tf.text = name.length > 0 ? name : "player";
            tf.selectable = false;
            tf.mouseEnabled = false;
            tf.autoSize = TextFieldAutoSize.CENTER;
            tf.y = -110;
            tf.x = -tf.width / 2;
            vis.addChild(tf);
            // 标签引用存到动态类 vis 上（visualPlayer 是 MovieClip=动态；
            // 存到幽灵本体是密封类会 #1069，导致 driveGhost 后续全被中断——
            // M14a：这曾让幽灵动画自 M6b 起全部失效）
            vis["_rconnect_label"] = tf;
         }
         catch(err:*)
         {
         }
      }

      /** 给幽灵安装 visualPlayer 视觉并按玩家初始化方式整理。
       *  M18：ap 非空时用对方外观构造（临时换全局 Appear 再还原）。 */
      private function installPlayerVis(ghost:Object, ap:Object = null):void
      {
         var ad:Object = main["loaderInfo"]["applicationDomain"];
         var visCls:Object = ad["getDefinition"]("visualPlayer");
         var vis:Object = null;
         if(ap != null && ap.cFur != undefined)
         {
            vis = buildPlayerVisStyled(ap);
         }
         if(vis == null)
         {
            try
            {
               vis = new (visCls as Class)();
            }
            catch(err:*)
            {
            }
         }
         if(vis == null)
         {
            return;
         }
         var osn:Object = probe(vis, "osn");
         if(osn != null)
         {
            try
            {
               osn["stop"]();
               var body:Object = probe(osn, "body");
               if(body != null)
               {
                  var pip2:Object = probe(body, "pip2");
                  if(pip2 != null)
                  {
                     pip2["visible"] = false;
                  }
               }
            }
            catch(err:*)
            {
            }
            // 与 UnitPlayer 构造一致：隐藏吸气/水晶/镣铐/老鼠/屎/光晕子剪辑
            hideChild(vis, "inh");
            hideChild(vis, "cryst");
            hideChild(vis, "fetter");
            hideChild(vis, "rat");
            hideChild(vis, "shit");
            hideChild(vis, "svet");
         }
         ghost["vis"] = vis;
      }

      private function hideChild(mc:Object, name:String):void
      {
         var c:Object = probe(mc, name);
         if(c != null)
         {
            try
            {
               c["visible"] = false;
            }
            catch(err:*)
            {
            }
         }
      }

      private function driveGhost(ghost:Object, snap:Object, id:int):void
      {
         try
         {
            if(snap.storona != undefined)
            {
               ghost["storona"] = Number(snap.storona) >= 0 ? 1 : -1;
            }
            if(snap.x != undefined && snap.y != undefined)
            {
               ghost["setPos"](Number(snap.x), Number(snap.y));
            }
            if(snap.dx != undefined)
            {
               ghost["dx"] = Number(snap.dx);
            }
            if(snap.dy != undefined)
            {
               ghost["dy"] = Number(snap.dy);
            }
            if(snap.stay != undefined)
            {
               ghost["stay"] = Number(snap.stay);
            }
            // M15b：化身是"镜象"，本体状态在客户端——强制 sost=1 防止
            // 幽灵在宿主世界被击倒/击杀后显示尸体/倒地姿态（“固定趴姿”），
            // 姿态一律由快照标签驱动；血量死亡流程由 scanGhostHp 重建处理
            try
            {
               ghost["sost"] = 1;
               // M18b：强制不悬浮——幽灵垂直位置只由快照 setPos 决定，
               // 防止游戏自身飞行/悬浮物理把幽灵带起来（“飞行药水效果”）
               ghost["isFly"] = false;
            }
            catch(err:*)
            {
            }
            ghost["setVisPos"]();
            // 名字标签抵消 setVisPos 的整体翻转（vis.scaleX = storona）
            var v:Object = probe(ghost, "vis");
            var label:Object = v != null ? probe(v, "_rconnect_label") : null;
            if(label != null)
            {
               if(v != null)
               {
                  var sx:Number = numOr(probe(v, "scaleX"), 1);
                  label["scaleX"] = sx < 0 ? -1 : 1;
               }
            }
            driveVisAnim(ghost, snap, id);
            if(snap.wi != undefined)
            {
               driveWeaponVis(ghost, snap, id);
            }
         }
         catch(err:*)
         {
            // 幽灵驱动失败不影响联机主流程；M14：首错记录定位
            if(!_driveErrLogged[id])
            {
               _driveErrLogged[id] = true;
               Log.d("RConnectGame: driveGhost #" + id + " err: " + err);
            }
         }
      }

      private var _driveErrLogged:Object = {};

      /**
       * 驱动幽灵姿态动画（与 UnitPlayer.control 同款模式）：
       *   vis.osn.gotoAndStop(标签); vis.osn.body.play();
       * 状态映射：dy!=0 → jump；位移大 → run；位移小 → walk；静止 → stay。
       */
      private function driveVisAnim(ghost:Object, snap:Object, id:int):void
      {
         var rec:Object = _animState[id];
         if(rec == null)
         {
            rec = _animState[id] = {lx: 0, ly: 0, label: ""};
         }
         var x:Number = Number(snap.x);
         var y:Number = Number(snap.y);
         var delta:Number = Math.abs(x - rec.lx) + Math.abs(y - rec.ly);
         rec.lx = x;
         rec.ly = y;

         var label:String;
         // M16：优先镜像对方真实姿态标签（站/走/跑/蹲/趴都由对方游戏决定）
         if(snap.pose != null && String(snap.pose) != "")
         {
            label = String(snap.pose);
         }
         else if(Number(snap.dy) != 0)
         {
            label = "jump";
         }
         else if(delta >= 6)
         {
            label = "run";
         }
         else if(delta >= 1)
         {
            label = "walk";
         }
         else
         {
            label = "stay";
         }
         if(label == rec.label)
         {
            return;
         }
         Log.d("RConnectGame: ghost #" + id + " anim: " + rec.label
            + " -> " + label);
         rec.label = label;
         try
         {
            var vis:Object = probe(ghost, "vis");
            var osn:Object = probe(vis, "osn");
            if(osn == null)
            {
               return;
            }
            osn["gotoAndStop"](label);
            var body:Object = probe(osn, "body");
            if(body != null)
            {
               body["play"]();
            }
         }
         catch(err:*)
         {
            // 某些标签在个别版本可能不存在
         }
      }

      private var _animState:Object = {};

      private function despawnGhost(ghost:Object, id:int):void
      {
         try
         {
            // 用化身自己所在的 loc（跨房后 this.loc 可能已不是它的 loc）
            var gloc:Object = probe(ghost, "loc");
            var g:Object = gloc != null ? gloc : loc;
            if(g != null)
            {
               g["remObj"](ghost);
               var units:Object = probe(g, "units");
               if(units is Array)
               {
                  var i:int = (units as Array).indexOf(ghost);
                  if(i >= 0)
                  {
                     (units as Array).splice(i, 1);
                  }
               }
            }
            Log.d("RConnectGame: ghost #" + id + " despawned");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: despawnGhost failed: " + err);
         }
      }

      /** 自动化联测：把本地玩家挪到最近敌人旁边（触发敌人近战/反击）。 */
      public function moveTest():void
      {
         if(world == null || gg == null)
         {
            return;
         }
         try
         {
            // 找最近敌对单位，站在它旁边
            var units:Object = probe(loc, "units");
            var tx:Number = 0;
            var ty:Number = 0;
            if(units is Array)
            {
               var px:Number = numOr(probe(gg, "X"), 0);
               var py:Number = numOr(probe(gg, "Y"), 0);
               var bestD:Number = Number.MAX_VALUE;
               for each(var u:Object in units as Array)
               {
                  if(u == gg)
                  {
                     continue;
                  }
                  var frac:Number = numOr(probe(u, "fraction"), 0);
                  if(frac < 1 || frac >= 100
                     || numOr(probe(u, "sost"), 1) >= 3)
                  {
                     continue;
                  }
                  var dx:Number = numOr(probe(u, "X"), 0) - px;
                  var dy:Number = numOr(probe(u, "Y"), 0) - py;
                  var d:Number = dx * dx + dy * dy;
                  if(d < bestD)
                  {
                     bestD = d;
                     tx = numOr(probe(u, "X"), 0) - 150;
                     ty = numOr(probe(u, "Y"), 0);
                  }
               }
            }
            if(bestD == Number.MAX_VALUE)
            {
               // 无敌人时回退固定点
               var pts:Array = [
                  {x: 966, y: 800}, {x: 966, y: 900},
                  {x: 1066, y: 900}, {x: 1066, y: 800}
               ];
               _travelTestStep = (_travelTestStep + 1) % pts.length;
               tx = pts[_travelTestStep].x;
               ty = pts[_travelTestStep].y;
            }
            gg["setPos"](tx, ty);
            gg["setVisPos"]();
            Log.d("RConnectGame: moveTest -> " + Math.round(tx) + ","
               + Math.round(ty));
         }
         catch(err:*)
         {
            Log.d("RConnectGame: moveTest failed: " + err);
         }
      }

      /** 采集世界身份（M4/M5：判断双方是否在同一房间，供传送跟随）。 */
      public function readWorldInfo():Object
      {
         if(world == null || gg == null)
         {
            refreshWorld();
         }
         if(world == null || gg == null)
         {
            return null;
         }
         var w:Object = {};
         var game:Object = probe(world, "game");
         w.curLandId = game != null ? String(probe(game, "curLandId")) : "";
         w.curCoord = game != null ? String(probe(game, "curCoord")) : "";
         w.locId = loc != null ? String(probe(loc, "id")) : "";
         var land:Object = probe(world, "land");
         w.landX = land != null ? int(probe(land, "locX")) : 0;
         w.landY = land != null ? int(probe(land, "locY")) : 0;
         w.landZ = land != null ? int(probe(land, "locZ")) : 0;
         var room:Object = loc != null ? probe(loc, "room") : null;
         w.roomId = room != null ? String(probe(room, "id")) : "";
         // M15：rnd 生成参数（landStage 随存档持久化，决定房间池）——
         // 加入方据此采纳宿主参数，保证同种子同布局
         var larr:Object = game != null ? probe(game, "lands") : null;
         var la:Object = larr != null && game != null
            ? larr[String(probe(game, "curLandId"))] : null;
         w.landStage = la != null ? numOr(probe(la, "landStage"), -1) : -1;
         w.hostVisited = la != null ? (probe(la, "visited") == true) : false;
         w.x = numOr(probe(gg, "X"), 0);
         w.y = numOr(probe(gg, "Y"), 0);
         return w;
      }

      /**
       * 跟随宿主换房（M5c）：同 land 且房间不同时，用游戏公开旅行入口
       * Land.gotoXY(x,y)（设置 locX/locY → ativateLoc → 玩家进房）跟随，
       * 再把本地玩家摆到宿主的精确坐标。
       * @return 描述字符串（followed / skip-* / failed-*）
       */
      public function followHostWorld(info:Object):String
      {
         // 无条件刷新缓存：gotoXY 后 loc 已变，旧缓存会导致重复跟随
         refreshWorld();
         if(world == null || gg == null)
         {
            return "not-in-game";
         }
         var mine:Object = readWorldInfo();
         if(mine == null)
         {
            return "not-in-game";
         }
         // M10b：冷却期内不重复触发（exit 换图流程约 5s，留 8s 裕量），
         // 否则死亡复活后的跟随会每 200ms 刷一次 travelToLand
         var now:int = flash.utils.getTimer();
         if(now - _lastFollowT < 8000)
         {
            return "skip-cooldown";
         }
         if(String(mine.curLandId) != String(info.curLandId))
         {
            // M11：过渡期不旅行（读档/退出流程中，房间会被重置回出生点）
            if(isTransitioning())
            {
               return "skip-transition";
            }
            // 身体部件伤重时 gotoLand 只会弹 nocont 不执行（Pers.dopusk），
            // 提前探测避免无效重试刷屏（等身体恢复后冷却重试）
            var pers:Object = probe(gg, "pers");
            if(pers != null)
            {
               try
               {
                  if(!(pers["dopusk"]() as Boolean))
                  {
                     _lastFollowT = now;
                     return "blocked-body";
                  }
               }
               catch(err:*)
               {
               }
            }
            _lastFollowT = now;
            // 跨地图：进入宿主的土地（随机地图内容可能不一致，见实验记录）
            // M15：先采纳宿主的 rnd 生成参数（landStage/visited）+ 清 Land
            // 强制重建——否则双方存档 landStage 不同会选不同房间池
            adoptHostLandParams(info);
            Log.d("RConnectWorld: travel " + String(mine.curLandId)
               + " -> " + String(info.curLandId) + " (host at "
               + Math.round(Number(info.x)) + "," + Math.round(Number(info.y))
               + ")");
            travelToLand(String(info.curLandId));
            try
            {
               gg["setPos"](Number(info.x), Number(info.y));
               gg["setVisPos"]();
            }
            catch(err:*)
            {
            }
            return "followed-land(" + info.curLandId + ")";
         }
         if(String(mine.locId) == String(info.locId))
         {
            // M15：同土地 rnd 且 landStage 与宿主不一致 → 采纳参数重建
            var raKey:String = String(mine.curLandId);
            if(!_adoptedSame[raKey]
               && numOr(info.landStage, -1) >= 0
               && Math.abs(numOr(info.landStage, -1)
                  - currentLandStage()) > 0.01
               && isRndLand(raKey))
            {
               _adoptedSame[raKey] = true;
               adoptHostLandParams(info);
               regenCurrentLand();
               return "regen(" + raKey + ")";
            }
            // M13：确定性布局下双方可能落在同房不同出生点（存档 checkpoint
            // 差异）—— 首次同房且相距过大时一次性对齐到宿主坐标
            var akey:String = String(mine.curLandId) + "/" + String(mine.locId);
            if(_alignedKey != akey)
            {
               var adx:Number = numOr(mine.x, 0) - Number(info.x);
               var ady:Number = numOr(mine.y, 0) - Number(info.y);
               if(adx * adx + ady * ady > 300 * 300)
               {
                  _alignedKey = akey;
                  try
                  {
                     gg["setPos"](Number(info.x), Number(info.y));
                     gg["setVisPos"]();
                     Log.d("RConnectWorld: aligned to host in " + mine.locId);
                  }
                  catch(err:*)
                  {
                  }
               }
            }
            return "skip-same-room";
         }
         // M11：过渡期不跟随（同土地换房；实测过渡期 gotoXY 会被
         // 入场逻辑重置回出生点，导致反复重进循环）
         if(isTransitioning())
         {
            return "skip-transition";
         }
         // M12：覆盖层卡住（allStat!=1）→ 先关，本轮跳过（下轮重试）
         if(probeNum(world, "allStat", 1) != 1)
         {
            forceCloseOverlays();
            return "skip-overlay";
         }
         try
         {
            var land:Object = probe(world, "land");
            if(land == null)
            {
               return "failed-no-land";
            }
            _lastFollowT = now;
            land["gotoXY"](int(info.landX), int(info.landY));
            gg["setPos"](Number(info.x), Number(info.y));
            gg["setVisPos"]();
            Log.d("RConnectWorld: followed host to loc " + info.locId
               + " (gotoXY " + info.landX + "," + info.landY + ")"
               + " pos " + Math.round(Number(info.x)) + ","
               + Math.round(Number(info.y)));
            return "followed(" + info.locId + ")";
         }
         catch(err:*)
         {
            return "failed(" + err + ")";
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return "failed";
      }

      /** 自动化联测（M5c）：宿主周期换房（在 (0,0) 与 (1,0) 之间循环）。 */
      public function travelTest():void
      {
         if(world == null || gg == null)
         {
            return;
         }
         try
         {
            var land:Object = probe(world, "land");
            if(land == null)
            {
               return;
            }
            _travelTestStep = (_travelTestStep + 1) % 2;
            var tx:int = _travelTestStep == 0 ? 0 : 1;
            var ty:int = 0;
            Log.d("RConnectGame: travelTest -> gotoXY(" + tx + "," + ty + ")");
            land["gotoXY"](tx, ty);
         }
         catch(err:*)
         {
            Log.d("RConnectGame: travelTest failed: " + err);
         }
      }

      /**
       * 跨地图传送（M6.5）：走游戏标准旅行入口 Game.beginMission/gotoLand
       * （内部含 exitLand 完整退出流程）。教训：直接设 curLandId +
       * enterToCurLand 会跳过退出序列导致游戏挂死。
       * M8 防护：新游戏加载流程中（curLandId 未就绪）或目标=当前土地时
       * 不发起旅行（实测重入当前土地会挂死游戏）。
       * @return 是否实际发起了旅行（false=跳过，调用方可稍后重试）
       */
      public function travelToLand(landId:String):Boolean
      {
         if(world == null || gg == null)
         {
            refreshWorld();
         }
         if(world == null || gg == null)
         {
            Log.d("RConnectGame: travelToLand: not in game");
            return false;
         }
         // M11：过渡期（读档/退出/死亡流程中）不旅行——实测会挂死或
         // 把房间重置回出生点
         if(isTransitioning())
         {
            Log.d("RConnectGame: travelToLand: world transitioning, skip");
            return false;
         }
         // M12：世界被覆盖层卡住（allStat!=1：失焦打开的 pip 等）——先关掉，
         // 本轮跳过，下一轮世界恢复后重试（避免把过渡发进冻结的世界）
         if(probeNum(world, "allStat", 1) != 1)
         {
            forceCloseOverlays();
            Log.d("RConnectGame: travelToLand: overlay blocked, closing");
            return false;
         }
         try
         {
            var game:Object = probe(world, "game");
            if(game == null)
            {
               return false;
            }
            var cur:String = game != null
               ? String(probe(game, "curLandId")) : "";
            if(cur == "")
            {
               // 世界仍在加载（newGame/换图过渡中），此时旅行会挂死游戏
               Log.d("RConnectGame: travelToLand: not ready, skip");
               return false;
            }
            if(cur == landId)
            {
               Log.d("RConnectGame: travelToLand: already in " + landId
                  + ", skip");
               return false;
            }
            Log.d("RConnectGame: travelToLand -> " + landId);
            try
            {
               game["beginMission"](landId);
            }
            catch(err:*)
            {
               game["gotoLand"](landId);
            }
            return true;
         }
         catch(err:*)
         {
            Log.d("RConnectGame: travelToLand failed: " + err);
            return false;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return false;
      }

      /** M12：强制关闭游戏覆盖层（pip/sats/stand/guiPause）。
       *  背景：窗口失焦会触发 World.onDeactivate → pip.onoff(11) 打开
       *  PipBuck 且无 ACTIVATE 处理器复位；覆盖层开 → World.allStat=2 →
       *  World.step 的 gameplay 块（含 t_exit/exitStep 过渡）被跳过 →
       *  旅行冻结、"两侧房间不同/场景无法正常加载"。
       *  pip 用游戏原生 onoff(0)（active 时=关闭，避免残留页码状态）；
       *  其余直接置 active=false（公开字段）。@return 是否关掉了什么 */
      public function forceCloseOverlays():Boolean
      {
         if(world == null)
         {
            return false;
         }
         var closed:Boolean = false;
         var pip:Object = probe(world, "pip");
         if(pip != null)
         {
            try
            {
               if(probe(pip, "active"))
               {
                  pip["onoff"](0);
                  closed = true;
               }
            }
            catch(err:*)
            {
            }
         }
         var sats:Object = probe(world, "sats");
         if(sats != null)
         {
            try
            {
               if(probe(sats, "active"))
               {
                  sats["active"] = false;
                  closed = true;
               }
            }
            catch(err:*)
            {
            }
         }
         var stand:Object = probe(world, "stand");
         if(stand != null)
         {
            try
            {
               if(probe(stand, "active"))
               {
                  stand["active"] = false;
                  closed = true;
               }
            }
            catch(err:*)
            {
            }
         }
         var gui:Object = probe(world, "gui");
         if(gui != null)
         {
            try
            {
               if(probe(gui, "guiPause"))
               {
                  gui["guiPause"] = false;
                  closed = true;
               }
            }
            catch(err:*)
            {
            }
         }
         if(closed)
         {
            Log.d("RConnectGame: forceCloseOverlays closed overlay(s)");
         }
         return closed;
      }

      /** M12 复现钩子（autoDeactivate）：模拟窗口失焦
       *  （World.onDeactivate → pip.onoff(11)），确定性验证覆盖层卡死路径。 */
      public function deactivateTest():void
      {
         try
         {
            main["stage"]["dispatchEvent"](new Event(Event.DEACTIVATE));
            Log.d("RConnectGame: deactivateTest dispatched");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: deactivateTest failed: " + err);
         }
      }

      /** M13 诊断：本地玩家脚下瓦片的公开字段采样（visi）。
       *  用于量化"同坐标是否同房间内容"（随机图布局指纹）。 */
      public function debugTileV():Number
      {
         if(gg == null || loc == null)
         {
            return -999;
         }
         try
         {
            var t:Object = loc["getAbsTile"](
               numOr(probe(gg, "X"), 0), numOr(probe(gg, "Y"), 0));
            return t != null ? numOr(probe(t, "visi"), -1) : -999;
         }
         catch(err:*)
         {
            return -999;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return -999;
      }

      /** M13 诊断：本地玩家周围 8 点瓦片布局指纹（phis/zForm/stair/water）。
       *  两侧同坐标处指纹一致 = 房间布局一致（验证 Land 确定性补丁）。 */
      public function debugTileGrid():String
      {
         if(gg == null || loc == null)
         {
            return "?";
         }
         var px:Number = numOr(probe(gg, "X"), 0);
         var py:Number = numOr(probe(gg, "Y"), 0);
         var offs:Array = [
            [0, 0], [150, 0], [-150, 0], [0, -150],
            [300, 150], [-300, -150], [0, 300], [150, -300]
         ];
         var out:String = "";
         try
         {
            for each(var o:Array in offs)
            {
               var t:Object = loc["getAbsTile"](px + Number(o[0]),
                  py + Number(o[1]));
               if(t != null)
               {
                  out += String(probe(t, "phis")) + "/"
                     + String(probe(t, "zForm")) + "/"
                     + String(probe(t, "stair")) + "/"
                     + String(probe(t, "water")) + " ";
               }
               else
               {
                  out += "? ";
               }
            }
         }
         catch(err:*)
         {
            return "err";
         }
         return out;
      }

      /** M14 复现钩子（autoWalk）：避墙漫游——每步探测 4 方向瓦片
       *  phis==0（可走）的方向挪 +40px，确保持续真实位移，用于验证
       *  远端幽灵随移动切换 walk/run 动画。 */
      public function walkStepTest():void
      {
         if(world == null || gg == null || loc == null)
         {
            return;
         }
         try
         {
            var x:Number = numOr(probe(gg, "X"), 0);
            var y:Number = numOr(probe(gg, "Y"), 0);
            var dirs:Array = [[1, 0], [-1, 0], [0, -1], [0, 1]];
            for each(var d:Array in dirs)
            {
               var tx:Number = x + Number(d[0]) * 40;
               var ty:Number = y + Number(d[1]) * 40;
               var tl:Object = loc["getAbsTile"](tx, ty);
               if(tl == null || numOr(probe(tl, "phis"), 1) != 0)
               {
                  continue;
               }
               gg["setPos"](tx, ty);
               gg["setVisPos"]();
               gg["dx"] = Number(d[0]);
               gg["dy"] = Number(d[1]);
               gg["stay"] = 0;
               return;
            }
         }
         catch(err:*)
         {
            Log.d("RConnectGame: walkStepTest failed: " + err);
         }
      }

      /** M14 诊断：直接驱动远端幽灵在 stay/walk/run/jump 间循环切换，
       *  并采样 osn.body.currentFrame——验证标签切换后动画帧是否真的推进。 */
      public function ghostAnimTest():void
      {
         for(var k:String in _remotes)
         {
            var ghost:Object = _remotes[k].ghost;
            if(ghost == null)
            {
               continue;
            }
            try
            {
               var labels:Array = ["stay", "walk", "run", "jump"];
               _ghostAnimIdx = (_ghostAnimIdx + 1) % labels.length;
               var lbl:String = String(labels[_ghostAnimIdx]);
               var vis:Object = probe(ghost, "vis");
               var osn:Object = probe(vis, "osn");
               var body:Object = osn != null ? probe(osn, "body") : null;
               var frLbl:int = 0;
               var frBody:int = 0;
               if(osn != null)
               {
                  osn["gotoAndStop"](lbl);
                  if(body != null)
                  {
                     body["play"]();
                     frBody = int(probe(body, "currentFrame"));
                  }
                  frLbl = int(probe(osn, "currentFrame"));
               }
               Log.d("RConnectGame: ghostAnimTest #" + k + " label=" + lbl
                  + " osn.frame=" + frLbl + " body.frame=" + frBody);
            }
            catch(err:*)
            {
               Log.d("RConnectGame: ghostAnimTest failed: " + err);
            }
            return;
         }
      }

      private var _ghostAnimIdx:int = 0;

      /** M14c：宿主已探索瓦片掩码（按 loc 引用缓存，换房重建）。
       *  格式：每行 spaceX 个 '1'/'0'（visi>=0.5=已见），行间 '|' 分隔。
       *  loc.space（public）探索雾由玩家点亮，联机双方探索半径不同 → 房间
       *  亮暗不同（“地图不同”）→ 宿主广播给加入方统一。 */
      public function readSeenMask():String
      {
         if(loc == null)
         {
            return "";
         }
         if(_seenKey === loc)
         {
            return _seenCache;
         }
         _seenKey = loc;
         _seenCache = buildSeenMask();
         if(_seenCache != "" && !_seenBuiltLogged)
         {
            _seenBuiltLogged = true;
            Log.d("RConnectGame: seen mask built "
               + numOr(probe(loc, "spaceX"), 0) + "x"
               + numOr(probe(loc, "spaceY"), 0)
               + " (" + _seenCache.length + " chars)");
         }
         return _seenCache;
      }

      private function buildSeenMask():String
      {
         try
         {
            var sx:int = numOr(probe(loc, "spaceX"), 0);
            var sy:int = numOr(probe(loc, "spaceY"), 0);
            if(sx <= 0 || sy <= 0 || sx > 200 || sy > 200)
            {
               return "";
            }
            var space:Object = probe(loc, "space");
            if(space == null || !(space is Array))
            {
               return "";
            }
            var rows:Array = [];
            for(var y:int = 0; y < sy; y++)
            {
               var row:String = "";
               var ry:Object = (space as Array)[y];
               if(ry is Array)
               {
                  for(var x:int = 0; x < sx; x++)
                  {
                     var t:Object = (ry as Array)[x];
                     var v:Number = t != null ? numOr(probe(t, "visi"), 0) : 0;
                     row += (v >= 0.5) ? "1" : "0";
                  }
               }
               rows.push(row);
            }
            return rows.join("|");
         }
         catch(err:*)
         {
            return "";
         }
         // mxmlc 控制流怪癖
         return "";
      }

      /** M14c：应用宿主的已探索掩码（仅当同 loc；visi 取最大=点亮）。 */
      public function applySeenMask(locId:String, cols:int, data:String):void
      {
         if(loc == null || data == null || data.length == 0)
         {
            return;
         }
         if(String(probe(loc, "id")) != locId)
         {
            return;
         }
         try
         {
            var rows:Array = data.split("|");
            if(!_seenAppliedLogged[locId])
            {
               _seenAppliedLogged[locId] = true;
               Log.d("RConnectGame: applied seen mask " + locId
                  + " rows=" + rows.length);
            }
            var space:Object = probe(loc, "space");
            if(space == null || !(space is Array))
            {
               return;
            }
            for(var y:int = 0; y < rows.length; y++)
            {
               var row:String = String(rows[y]);
               var ry:Object = (space as Array)[y];
               if(!(ry is Array))
               {
                  continue;
               }
               for(var x:int = 0; x < row.length && x < cols; x++)
               {
                  if(row.charAt(x) == "1")
                  {
                     var t:Object = (ry as Array)[x];
                     if(t != null)
                     {
                        t["visi"] = 1;
                     }
                  }
               }
            }
         }
         catch(err:*)
         {
         }
      }

      private var _seenKey:Object = null;
      private var _seenCache:String = "";
      private var _seenBuiltLogged:Boolean = false;
      private var _seenAppliedLogged:Object = {};

      /** M14 诊断：第一个远端幽灵的实际姿态（osn 标签/帧 + sost），
       *  定位"固定趴姿"问题。 */
      public function debugGhostPose():String
      {
         for(var k:String in _remotes)
         {
            var ghost:Object = _remotes[k].ghost;
            if(ghost == null)
            {
               return "no-ghost";
            }
            try
            {
               var vis:Object = probe(ghost, "vis");
               var osn:Object = probe(vis, "osn");
               var body:Object = osn != null ? probe(osn, "body") : null;
               var lbl:String = osn != null
                  ? String(probe(osn, "currentLabel")) : "?";
               var fr:int = osn != null ? int(probe(osn, "currentFrame")) : -1;
               var bodyFr:int = body != null
                  ? int(probe(body, "currentFrame")) : -1;
               return "ghost#" + k + " sost="
                  + String(numOr(probe(ghost, "sost"), -1))
                  + " lbl=" + lbl + " fr=" + fr + " bodyFr=" + bodyFr
                  + " visK=" + (vis != null
                     ? String(int(probe(vis, "numChildren"))) : "?");
            }
            catch(err:*)
            {
               return "err";
            }
            return "";
         }
         return "none";
      }

      /** M18：读取本机外观（Appear 全局静态 + World.app 颜色 + 变换）。
       *  visualPlayer 在构造时从这些全局取样式——所以幽灵必须用对方的
       *  值构造，否则所有幽灵都长得像本地玩家。 */
      public function readAppearance():Object
      {
         var ap:Object = {};
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var ac:Object = ad["getDefinition"]("fe.inter.Appear");
            if(ac != null)
            {
               ap.armor = String(ac["ggArmorId"]);
               ap.hideMane = int(numOr(ac["hideMane"], 0));
               ap.visHair1 = (ac["visHair1"] == true);
               ap.fEye = int(numOr(ac["fEye"], 1));
               ap.fHair = int(numOr(ac["fHair"], 1));
               ap.tf = readCT(ac["trFur"]);
               ap.tH = readCT(ac["trHair"]);
               ap.tH1 = readCT(ac["trHair1"]);
               ap.tE = readCT(ac["trEye"]);
               ap.tM = readCT(ac["trMagic"]);
            }
            var app:Object = probe(world, "app");
            if(app != null)
            {
               ap.cFur = numOr(probe(app, "cFur"), 0);
               ap.cHair = numOr(probe(app, "cHair"), 0);
               ap.cHair1 = numOr(probe(app, "cHair1"), 0);
               ap.cEye = numOr(probe(app, "cEye"), 0);
               ap.cMagic = numOr(probe(app, "cMagic"), 0);
            }
         }
         catch(err:*)
         {
         }
         return ap;
      }

      /** ColorTransform → 6 数数组（rm,gm,bm,ro,go,bo）。 */
      private function readCT(ct:Object):Array
      {
         try
         {
            return [Number(ct["redMultiplier"]), Number(ct["greenMultiplier"]),
               Number(ct["blueMultiplier"]), Number(ct["redOffset"]),
               Number(ct["greenOffset"]), Number(ct["blueOffset"])];
         }
         catch(err:*)
         {
            return null;
         }
         return null;
      }

      /** M18：把对方外观套到新的 visualPlayer 上（临时换全局再还原）。 */
      private function buildPlayerVisStyled(ap:Object):Object
      {
         var ad:Object = main["loaderInfo"]["applicationDomain"];
         var ac:Object = ad["getDefinition"]("fe.inter.Appear");
         var app:Object = probe(world, "app");
         // 保存本地外观
         var save:Object = {};
         if(ac != null)
         {
            save.armor = ac["ggArmorId"];
            save.hideMane = ac["hideMane"];
            save.visHair1 = ac["visHair1"];
            save.fEye = ac["fEye"];
            save.fHair = ac["fHair"];
            save.tf = ac["trFur"];
            save.tH = ac["trHair"];
            save.tH1 = ac["trHair1"];
            save.tE = ac["trEye"];
            save.tM = ac["trMagic"];
         }
         var saveC:Object = {};
         if(app != null)
         {
            saveC.cFur = app["cFur"];
            saveC.cHair = app["cHair"];
            saveC.cHair1 = app["cHair1"];
            saveC.cEye = app["cEye"];
            saveC.cMagic = app["cMagic"];
         }
         var vis:Object = null;
         try
         {
            if(ac != null && ap != null)
            {
               ac["ggArmorId"] = String(ap.armor != null ? ap.armor : "");
               ac["hideMane"] = int(numOr(ap.hideMane, 0));
               ac["visHair1"] = (ap.visHair1 == true);
               ac["fEye"] = int(numOr(ap.fEye, 1));
               ac["fHair"] = int(numOr(ap.fHair, 1));
               if(ap.tf is Array)
               {
                  ac["trFur"] = new ColorTransform(Number(ap.tf[0]),
                     Number(ap.tf[1]), Number(ap.tf[2]), 1,
                     Number(ap.tf[3]), Number(ap.tf[4]), Number(ap.tf[5]));
                  ac["trHair"] = new ColorTransform(Number(ap.tH[0]),
                     Number(ap.tH[1]), Number(ap.tH[2]), 1,
                     Number(ap.tH[3]), Number(ap.tH[4]), Number(ap.tH[5]));
                  ac["trHair1"] = new ColorTransform(Number(ap.tH1[0]),
                     Number(ap.tH1[1]), Number(ap.tH1[2]), 1,
                     Number(ap.tH1[3]), Number(ap.tH1[4]), Number(ap.tH1[5]));
                  ac["trEye"] = new ColorTransform(Number(ap.tE[0]),
                     Number(ap.tE[1]), Number(ap.tE[2]), 1,
                     Number(ap.tE[3]), Number(ap.tE[4]), Number(ap.tE[5]));
                  ac["trMagic"] = new ColorTransform(Number(ap.tM[0]),
                     Number(ap.tM[1]), Number(ap.tM[2]), 1,
                     Number(ap.tM[3]), Number(ap.tM[4]), Number(ap.tM[5]));
               }
            }
            if(app != null && ap != null)
            {
               app["cFur"] = numOr(ap.cFur, saveC.cFur);
               app["cHair"] = numOr(ap.cHair, saveC.cHair);
               app["cHair1"] = numOr(ap.cHair1, saveC.cHair1);
               app["cEye"] = numOr(ap.cEye, saveC.cEye);
               app["cMagic"] = numOr(ap.cMagic, saveC.cMagic);
            }
            var visCls:Object = ad["getDefinition"]("visualPlayer");
            vis = new (visCls as Class)();
         }
         catch(err:*)
         {
            vis = null;
         }
         // 还原本地外观
         try
         {
            if(ac != null)
            {
               ac["ggArmorId"] = save.armor;
               ac["hideMane"] = save.hideMane;
               ac["visHair1"] = save.visHair1;
               ac["fEye"] = save.fEye;
               ac["fHair"] = save.fHair;
               ac["trFur"] = save.tf;
               ac["trHair"] = save.tH;
               ac["trHair1"] = save.tH1;
               ac["trEye"] = save.tE;
               ac["trMagic"] = save.tM;
            }
            if(app != null)
            {
               app["cFur"] = saveC.cFur;
               app["cHair"] = saveC.cHair;
               app["cHair1"] = saveC.cHair1;
               app["cEye"] = saveC.cEye;
               app["cMagic"] = saveC.cMagic;
            }
         }
         catch(err:*)
         {
         }
         return vis;
      }

      /** M15 诊断：本地玩家视觉的 osn 标签/帧（对照幽灵姿态用）。 */
      public function debugLocalPose():String
      {
         if(gg == null)
         {
            return "no-gg";
         }
         try
         {
            var vis:Object = probe(gg, "vis");
            var osn:Object = probe(vis, "osn");
            if(osn == null)
            {
               return "no-osn";
            }
            return "lbl=" + String(probe(osn, "currentLabel"))
               + " fr=" + String(int(probe(osn, "currentFrame")))
               + " stay=" + String(numOr(probe(gg, "stay"), -1))
               + " work=" + String(probe(gg, "work"));
         }
         catch(err:*)
         {
            return "err";
         }
         return "?";
      }

      /** M16：本机当前姿态标签（供快照携带、幽灵镜像）。 */
      private function localPoseLabel():String
      {
         if(gg == null)
         {
            return "";
         }
         try
         {
            var vis:Object = probe(gg, "vis");
            var osn:Object = probe(vis, "osn");
            return osn != null ? String(probe(osn, "currentLabel")) : "";
         }
         catch(err:*)
         {
            return "";
         }
         return "";
      }

      /** M15：加入方在进入宿主所在土地前，采纳宿主的 rnd 生成参数
       *  （landStage/visited）并清空已缓存 Land 强制重新生成——
       *  否则双方存档 landStage 不同 → 同一种子选出不同房间池 → 布局不同。 */
      public function adoptHostLandParams(info:Object):void
      {
         if(world == null)
         {
            return;
         }
         try
         {
            var game:Object = probe(world, "game");
            if(game == null)
            {
               return;
            }
            var target:String = info.curLandId != null
               ? String(info.curLandId) : "";
            if(target == "")
            {
               return;
            }
            var act:Object = probe(game, "lands");
            if(act == null)
            {
               return;
            }
            var la:Object = act[target];
            if(la == null)
            {
               return;
            }
            if(!(probe(la, "rnd") as Boolean))
            {
               return;   // 只处理随机土地
            }
            var hs:Number = info.landStage != null
               ? Number(info.landStage) : -1;
            var ls:Number = numOr(probe(la, "landStage"), -1);
            if(hs >= 0 && Math.abs(hs - ls) > 0.01)
            {
               la["landStage"] = hs;
               la["land"] = null;   // 强制下次进入重建
               Log.d("RConnectWorld: adopt host landStage " + target
                  + " " + ls + " -> " + hs);
            }
            if(info.hostVisited != null && info.hostVisited != undefined)
            {
               var hv:Boolean = (info.hostVisited == true);
               if(probe(la, "visited") != hv)
               {
                  la["visited"] = hv;
               }
            }
         }
         catch(err:*)
         {
            Log.d("RConnectWorld: adoptHostLandParams failed: " + err);
         }
      }

      /** M15：当前土地是否 rnd（随机土地）。 */
      private function isRndLand(landId:String):Boolean
      {
         try
         {
            var game:Object = probe(world, "game");
            if(game == null)
            {
               return false;
            }
            var la:Object = probe(game, "lands");
            if(la == null)
            {
               return false;
            }
            var act:Object = la[landId];
            return act != null && (probe(act, "rnd") as Boolean);
         }
         catch(err:*)
         {
            return false;
         }
         // mxmlc 控制流怪癖
         return false;
      }

      /** M15：当前土地 landStage（-1=未知）。 */
      private function currentLandStage():Number
      {
         var mine:Object = readWorldInfo();
         return mine != null ? numOr(mine.landStage, -1) : -1;
      }

      /** M15：重入当前土地（清 Land 后 gotoLand 同土地），强制用新参数重建。 */
      private function regenCurrentLand():void
      {
         if(world == null)
         {
            return;
         }
         try
         {
            var game:Object = probe(world, "game");
            if(game == null)
            {
               return;
            }
            var cur:String = String(probe(game, "curLandId"));
            if(cur == "")
            {
               return;
            }
            var la:Object = probe(game, "lands");
            if(la != null && la[cur] != null)
            {
               la[cur]["land"] = null;
            }
            game["gotoLand"](cur);
            Log.d("RConnectWorld: regen land " + cur);
         }
         catch(err:*)
         {
            Log.d("RConnectWorld: regen failed: " + err);
         }
      }

      private var _adoptedSame:Object = {};

      /** M16：读取当前房间的物品（Box/标志物）状态快照，宿主广播。
       *  确定性布局下双方同模板同 id，只需同步状态（死/门/血量等）。 */
      public function readObjsSnapshot():Array
      {
         if(loc == null)
         {
            return null;
         }
         var objs:Object = probe(loc, "objs");
         if(objs == null || !(objs is Array))
         {
            return null;
         }
         var out:Array = [];
         try
         {
            for each(var b:Object in objs as Array)
            {
               var id:String = String(probe(b, "id"));
               if(id == null || id.length == 0)
               {
                  continue;
               }
               out.push({
                  id: id,
                  cls: getQualifiedClassName(b),
                  x: numOr(probe(b, "X"), -1),
                  y: numOr(probe(b, "Y"), -1),
                  dead: probe(b, "dead") == true,
                  door: numOr(probe(b, "door"), -1),
                  door_opac: numOr(probe(b, "door_opac"), -1),
                  shelf: probe(b, "shelf") == true
               });
            }
         }
         catch(err:*)
         {
         }
         return out;
      }

      /** M16：把宿主的物品状态镜像到本房间（按 id 匹配；缺失/多余跳过，
       *  破坏/门等状态由字段驱动视觉自动更新）。 */
      public function reconcileObjs(list:Array):void
      {
         if(loc == null || list == null)
         {
            return;
         }
         var objs:Object = probe(loc, "objs");
         if(objs == null || !(objs is Array))
         {
            return;
         }
         var byId:Object = {};
         try
         {
            for each(var b:Object in objs as Array)
            {
               var id:String = String(probe(b, "id"));
               if(id != null && id.length > 0 && byId[id] == undefined)
               {
                  byId[id] = b;
               }
            }
         }
         catch(err:*)
         {
         }
         var synced:int = 0;
         for each(var h:Object in list)
         {
            var lb:Object = byId[String(h.id)];
            if(lb == null)
            {
               continue;
            }
            try
            {
               if(h.dead != undefined)
               {
                  var wasDead:Boolean = (probe(lb, "dead") == true);
                  if(!wasDead && h.dead == true && !_boxDeadLogged[String(h.id)])
                  {
                     _boxDeadLogged[String(h.id)] = true;
                     Log.d("RConnectGame: box destroyed synced '" + String(h.id)
                        + "'");
                  }
                  lb["dead"] = (h.dead == true);
               }
               if(h.hp is Number || h.hp != undefined)
               {
                  var hpR:* = probe(h, "hp");
                  if(hpR != undefined && hpR != null)
                  {
                     lb["hp"] = Number(hpR);
                  }
               }
               if(numOr(h.door, -1) >= 0)
               {
                  lb["door"] = int(h.door);
               }
               if(numOr(h.door_opac, -1) >= 0)
               {
                  lb["door_opac"] = Number(h.door_opac);
               }
               synced++;
            }
            catch(err:*)
            {
            }
         }
         if(synced > 0 && !_objsLogged2)
         {
            _objsLogged2 = true;
            Log.d("RConnectGame: objs synced " + synced + " (host " + list.length + ")");
         }
      }

      private var _objsLogged2:Boolean = false;
      private var _boxDeadLogged:Object = {};

      /** M16 复现钩子：宿主把第一个未被破坏的物品标记为破坏（验证 join 端
       *  同步 dead）。放宽到任意带 id 的 Box（含装饰性箱子）。 */
      public function boxKillTest():void
      {
         if(loc == null)
         {
            return;
         }
         var objs:Object = probe(loc, "objs");
         if(!(objs is Array))
         {
            return;
         }
         try
         {
            var n:int = 0;
            for each(var b:Object in objs as Array)
            {
               n++;
               if(String(probe(b, "id")) == "" || (probe(b, "dead") == true))
               {
                  continue;
               }
               b["dead"] = true;
               b["hp"] = 0;
               Log.d("RConnectGame: boxKillTest destroyed '" + String(probe(b, "id"))
                  + "' (inspected " + n + " objs)");
               return;
            }
            Log.d("RConnectGame: boxKillTest no destructible obj (inspected " + n + ")");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: boxKillTest failed: " + err);
         }
      }

      /** M17：宿主瓦片破坏差分——与基线比对返回变化瓦片（墙洞/地形破坏）。
       *  附带 key 状态字段；基线随 loc 缓存，换房重建。 */
      public function readTilePatch():Array
      {
         if(loc == null)
         {
            return null;
         }
         if(_tileBaseLoc !== loc)
         {
            _tileBaseLoc = loc;
            _tileBase = null;   // 进入新房间：以当前状态为基线
            buildTileBase();
            return null;
         }
         if(_tileBase == null)
         {
            buildTileBase();
            return null;
         }
         var out:Array = [];
         try
         {
            var sx:int = numOr(probe(loc, "spaceX"), 0);
            var sy:int = numOr(probe(loc, "spaceY"), 0);
            var space:Object = probe(loc, "space");
            for(var y:int = 0; y < sy && out.length < 60; y++)
            {
               var ry:Object = (space as Array)[y];
               if(!(ry is Array))
               {
                  continue;
               }
               for(var x:int = 0; x < sx; x++)
               {
                  var t:Object = (ry as Array)[x];
                  if(t == null)
                  {
                     continue;
                  }
                  var k:String = x + "," + y;
                  var b:Object = _tileBase[k];
                  if(b == null)
                  {
                     continue;
                  }
                  var phis:Number = numOr(probe(t, "phis"), 0);
                  var front:String = String(probe(t, "front"));
                  var back:String = String(probe(t, "back"));
                  var zad:String = String(probe(t, "zad"));
                  var zForm:int = numOr(probe(t, "zForm"), 0);
                  var water:int = numOr(probe(t, "water"), 0);
                  var stair:int = numOr(probe(t, "stair"), 0);
                  var hp:Number = numOr(probe(t, "hp"), 0);
                  if(phis != b.p || front != b.f || back != b.b || zad != b.z
                     || zForm != b.zf || water != b.w || stair != b.st
                     || Math.abs(hp - b.h) > 0.5)
                  {
                     out.push({x: x, y: y, p: phis, f: front, b: back, z: zad,
                        zf: zForm, w: water, st: stair, h: hp});
                     // M17：不推进基线——非默认瓦片作为"持久状态"持续广播，
                     // 保证晚到的加入方也能收敛（应用侧幂等）
                  }
               }
            }
         }
         catch(err:*)
         {
         }
         return out.length > 0 ? out : null;
      }

      private function buildTileBase():void
      {
         _tileBase = {};
         try
         {
            var sx:int = numOr(probe(loc, "spaceX"), 0);
            var sy:int = numOr(probe(loc, "spaceY"), 0);
            var space:Object = probe(loc, "space");
            for(var y:int = 0; y < sy; y++)
            {
               var ry:Object = (space as Array)[y];
               if(!(ry is Array))
               {
                  continue;
               }
               for(var x:int = 0; x < sx; x++)
               {
                  var t:Object = (ry as Array)[x];
                  if(t == null)
                  {
                     continue;
                  }
                  _tileBase[x + "," + y] = {
                     p: numOr(probe(t, "phis"), 0),
                     f: String(probe(t, "front")),
                     b: String(probe(t, "back")),
                     z: String(probe(t, "zad")),
                     zf: numOr(probe(t, "zForm"), 0),
                     w: numOr(probe(t, "water"), 0),
                     st: numOr(probe(t, "stair"), 0),
                     h: numOr(probe(t, "hp"), 0)
                  };
               }
            }
         }
         catch(err:*)
         {
         }
      }

      private var _tileBase:Object = null;
      private var _tileBaseLoc:Object = null;

      /** M17：应用宿主瓦片破坏；置脏，由 tick 触发整房重绘。 */
      public function applyTilePatch(list:Array):void
      {
         if(loc == null || list == null)
         {
            return;
         }
         try
         {
            var space:Object = probe(loc, "space");
            var applied:int = 0;
            for each(var p:Object in list)
            {
               var t:Object = null;
               try
               {
                  t = (space as Array)[int(p.y)][int(p.x)];
               }
               catch(err:*)
               {
                  t = null;
               }
               if(t == null)
               {
                  continue;
               }
               var changed:Boolean = false;
               if(p.p != undefined && Number(t["phis"]) != Number(p.p))
               {
                  t["phis"] = Number(p.p);
                  changed = true;
               }
               if(p.f != undefined && String(t["front"]) != String(p.f))
               {
                  t["front"] = String(p.f);
                  changed = true;
               }
               if(p.b != undefined && String(t["back"]) != String(p.b))
               {
                  t["back"] = String(p.b);
                  changed = true;
               }
               if(p.z != undefined && String(t["zad"]) != String(p.z))
               {
                  t["zad"] = String(p.z);
                  changed = true;
               }
               if(p.zf != undefined && int(t["zForm"]) != int(p.zf))
               {
                  t["zForm"] = int(p.zf);
                  changed = true;
               }
               if(p.w != undefined && int(t["water"]) != int(p.w))
               {
                  t["water"] = int(p.w);
                  changed = true;
               }
               if(p.st != undefined && int(t["stair"]) != int(p.st))
               {
                  t["stair"] = int(p.st);
                  changed = true;
               }
               if(p.h != undefined && Math.abs(Number(t["hp"]) - Number(p.h)) > 0.01)
               {
                  t["hp"] = Number(p.h);
                  changed = true;
               }
               if(changed)
               {
                  applied++;
               }
            }
            if(applied > 0)
            {
               _tileDirty = true;
               if(!_tilePatchLogged)
               {
                  _tilePatchLogged = true;
                  Log.d("RConnectGame: tile patch applied " + applied);
               }
            }
         }
         catch(err:*)
         {
         }
      }

      private var _tileDirty:Boolean = false;
      private var _tilePatchLogged:Boolean = false;

      /** M17：瓦片变化后整房重绘（World.redrawLoc 公开）。 */
      public function tileRedrawIfDirty():void
      {
         if(!_tileDirty || world == null)
         {
            return;
         }
         _tileDirty = false;
         try
         {
            world["redrawLoc"]();
            Log.d("RConnectGame: tile redraw ran");
         }
         catch(err:*)
         {
         }
      }

      /** M17：宿主检测"非模板"物品（现场生成/掉落）→ 持续广播给加入方。
       *  模板 id 集 = 进房时 loc.objs 的 id；之后沿 Pt 链（firstObj→nobj）
       *  收集非单位 Obj：Loot 恒定上报（位置+物品作键），非 Loot 且非模板
       *  id 的对象也上报（脚本生成的箱等）。加入方按键幂等去重。 */
      public function readNewObjs():Array
      {
         if(loc == null)
         {
            return null;
         }
         if(_objBaseLoc !== loc)
         {
            _objBaseLoc = loc;
            _objTpl = {};
            _objTplInit = false;
         }
         if(!_objTplInit)
         {
            try
            {
               var to:Object = probe(loc, "objs");
               if(to is Array)
               {
                  for each(var tb:Object in to as Array)
                  {
                     var tid:String = String(probe(tb, "id"));
                     if(tid != null && tid.length > 0)
                     {
                        _objTpl[tid] = true;
                     }
                  }
               }
            }
            catch(err:*)
            {
            }
            _objTplInit = true;
            return null;
         }
         var out:Array = [];
         try
         {
            var cur:Object = probe(loc, "firstObj");
            var guard:int = 0;
            while(cur != null && guard++ < 800)
            {
               var clsS:String = getQualifiedClassName(cur);
               // 只关心 fe.loc 里的 Obj 系（Box/Loot）；单位（fe.unit）、粒子
               // （fe.graph）、地图标记（CheckPoint/BackObj）等在别处处理。
               // 注意：getQualifiedClassName 用 '::'（如 fe.loc::Loot）
               if(clsS.indexOf("fe.loc") == 0
                  && clsS.indexOf("CheckPoint") < 0
                  && clsS.indexOf("BackObj") < 0)
               {
                  var id:String = String(probe(cur, "id"));
                  var isLoot:Boolean = (clsS.indexOf("Loot") >= 0);
                  if(isLoot || (id != null && id.length > 0
                     && _objTpl[id] !== true))
                  {
                     if(isLoot)
                     {
                        id = "loot@" + lootItemBase(cur) + "@"
                           + Math.round(numOr(probe(cur, "X"), 0)) + ","
                           + Math.round(numOr(probe(cur, "Y"), 0));
                     }
                     out.push({id: id, cls: clsS,
                        x: numOr(probe(cur, "X"), 0),
                        y: numOr(probe(cur, "Y"), 0),
                        isLoot: isLoot,
                        itemBase: lootItemBase(cur),
                        dead: probe(cur, "dead") == true,
                        door: numOr(probe(cur, "door"), -1),
                        hp: numOr(probe(cur, "hp"), -1),
                        shelf: probe(cur, "shelf") == true});
                  }
               }
               cur = probe(cur, "nobj");
            }
         }
         catch(err:*)
         {
         }
         return out.length > 0 ? out : null;
      }

      private var _objTpl:Object = {};
      private var _objTplInit:Boolean = false;
      private var _objBaseLoc:Object = null;

      private function lootItemBase(o:Object):String
      {
         try
         {
            var it:Object = probe(o, "item");
            return it != null ? String(probe(it, "base")) : "";
         }
         catch(err:*)
         {
            return "";
         }
         return "";
      }

      /** M17：加入方按宿主广播生成新物品（Loot 按 item base 构造；其他 Obj
       *  尽力构造）。幂等（按 id 去重，避免持续广播重复生成）。 */
      public function applyObjSpawn(list:Array):void
      {
         if(loc == null || list == null)
         {
            return;
         }
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var spawned:int = 0;
            var skipped:int = 0;
            for each(var s:Object in list)
            {
               var key:String = String(s.id);
               if(_objSpawnedIds[key])
               {
                  continue;   // 幂等：持续广播下去重
               }
               _objSpawnedIds[key] = true;
               var clsName:String = String(s.cls);
               var cls:Object = ad["getDefinition"](clsName);
               if(cls == null)
               {
                  skipped++;
                  continue;
               }
               if(s.isLoot == true)
               {
                  if(spawnLoot(ad, cls, s))
                  {
                     spawned++;
                  }
                  else
                  {
                     skipped++;
                     Log.d("RConnectGame: obj spawn loot failed '" + key + "'");
                  }
               }
               else
               {
                  try
                  {
                     var obj:Object = new (cls as Class)(loc, String(s.id),
                        Number(s.x), Number(s.y), null, null);
                     spawned++;
                  }
                  catch(err:*)
                  {
                     skipped++;
                     Log.d("RConnectGame: obj spawn '" + key
                        + "' failed: " + err);
                  }
               }
            }
            if(spawned > 0 || skipped > 0)
            {
               Log.d("RConnectGame: obj spawn recv spawned=" + spawned
                  + " skipped=" + skipped);
            }
         }
         catch(err:*)
         {
         }
      }

      private var _objSpawnedIds:Object = {};

      /** M17：按宿主广播生成 Loot（Item 按 base 构造）。@return 是否成功。 */
      private function spawnLoot(ad:Object, lootCls:Object, s:Object):Boolean
      {
         try
         {
            var itCls:Object = ad["getDefinition"]("fe.serv.Item");
            var base:String = s.itemBase != undefined ? String(s.itemBase) : "";
            if(base == "")
            {
               return false;
            }
            var item:Object = new (itCls as Class)(null, base, 1);
            var lo:Object = new (lootCls as Class)(loc, item, Number(s.x),
               Number(s.y), false, false, false);
            return lo != null;
         }
         catch(err:*)
         {
            Log.d("RConnectGame: spawnLoot failed: " + err);
            return false;
         }
         // mxmlc 控制流怪癖
         return false;
      }

      /** M17 复现钩子：宿主破一面墙（模拟爆炸轰洞）——整房扫描第一块实心
       *  瓦片（phis>0），不依赖玩家附近。验证瓦片差分同步。 */
      public function tileBreakTest():void
      {
         if(loc == null)
         {
            return;
         }
         try
         {
            var space:Object = probe(loc, "space");
            var sx:int = numOr(probe(loc, "spaceX"), 0);
            var sy:int = numOr(probe(loc, "spaceY"), 0);
            for(var y:int = 1; y < sy; y++)
            {
               var ry:Object = (space as Array)[y];
               if(!(ry is Array))
               {
                  continue;
               }
               for(var x:int = 1; x < sx; x++)
               {
                  var t:Object = (ry as Array)[x];
                  if(t != null && numOr(probe(t, "phis"), 0) > 0
                     && (x + y) % 3 == 0)
                  {
                     t["phis"] = 0;
                     t["front"] = "";
                     t["back"] = "";
                     t["zad"] = "";
                     Log.d("RConnectGame: tileBreakTest opened " + x + "," + y);
                     world["redrawLoc"]();
                     return;
                  }
               }
            }
            Log.d("RConnectGame: tileBreakTest: no solid tile");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: tileBreakTest failed: " + err);
         }
      }

      /** M17 复现钩子：宿主在玩家面前生成一个 Loot 掉落（验证加入方镜像）。 */
      public function objSpawnTest():void
      {
         if(gg == null || loc == null)
         {
            return;
         }
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var itCls:Object = ad["getDefinition"]("fe.serv.Item");
            var loCls:Object = ad["getDefinition"]("fe.loc.Loot");
            var item:Object = new (itCls as Class)(null, "kofe", 1);
            new (loCls as Class)(loc, item,
               numOr(probe(gg, "X"), 0) + 40,
               numOr(probe(gg, "Y"), 0), false, false, false);
            Log.d("RConnectGame: objSpawnTest spawned loot 'kofe'");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: objSpawnTest failed: " + err);
         }
      }

      private var _travelTestStep:int = 0;
      private var _lastFollowT:int = -100000;
      private var _alignedKey:String = "";

      /** M11 复现钩子（autoHostKill）：宿主自毁，触发死亡回城→基地，
       *  验证加入方跨土地跟随到基地的路径。 */
      public function hostKillTest():void
      {
         if(world == null || gg == null)
         {
            return;
         }
         try
         {
            gg["damage"](99999, 0, null, false);
            Log.d("RConnectGame: hostKillTest applied");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: hostKillTest failed: " + err);
         }
      }

      /** M8 诊断：游戏错误对话框（showError→verror.txt.text）可见时抓文本。
       *  M11：只要可见就记录一次（不依赖文本变化——空文本对话框也要看到）。 */
      public function dumpGameError():void
      {
         if(world == null)
         {
            return;
         }
         var verr:Object = probe(world, "verror");
         if(verr == null || !(probe(verr, "visible") as Boolean))
         {
            return;
         }
         try
         {
            var txt:Object = probe(verr, "txt");
            var s:String = txt != null ? String(probe(txt, "text")) : "";
            if(s != _lastErr)
            {
               _lastErr = s;
               Log.d("RConnectGame: game error dialog: " + s.substr(0, 400));
            }
            else if(!_errVisibleLogged)
            {
               _errVisibleLogged = true;
               Log.d("RConnectGame: game error dialog visible (text unchanged)");
            }
         }
         catch(err:*)
         {
         }
      }

      private var _lastErr:String = "";
      private var _errVisibleLogged:Boolean = false;

      /** M10b 测试钩子（autoHeal）：完全治疗（身体部件+主血量）。
       *  死亡回城后身体部件伤重会挡旅行（Pers.dopusk），联测用此恢复。 */
      public function healTest():void
      {
         if(world == null || gg == null)
         {
            return;
         }
         try
         {
            var pers:Object = probe(gg, "pers");
            if(pers != null)
            {
               pers["healAll"]();
            }
            gg["heal"](numOr(probe(gg, "maxhp"), 100), 0, false);
            Log.d("RConnectGame: healTest applied (body+hp)");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: healTest failed: " + err);
         }
      }

      /** M8 测试钩子（autoLoadSave）：程序化加载存档槽位（等价菜单 Continue）。
       *  关键：gui/sats 只在 newGame() 里创建（World.as:859/863），从未建过
       *  世界就 loadGame 会 #1009（this.sats.gg 空引用，实测错误对话框）。
       *  流程：先 newGame 初始化世界骨架 → gg 出现后走原版 comLoad 通道
       *  （PipPageOpt.as:707 设 World.w.comLoad，World.step 两帧流程完成读档）。
       *  @return 是否已完成发起（false=流程进行中/未就绪，调用方可稍后重试）
       */
      public function loadSaveTest(slot:int):Boolean
      {
         if(world == null)
         {
            refreshWorld();
         }
         if(world == null)
         {
            Log.d("RConnectGame: loadSaveTest: no world yet");
            return false;
         }
         try
         {
            var g:Object = probe(world, "gg");
            var sats:Object = probe(world, "sats");
            if(g == null && sats == null)
            {
               // 从未建过世界：先 newGame 初始化 gui/sats/stand 骨架
               var mm0:Object = probe(world, "mm");
               if(mm0 != null)
               {
                  try
                  {
                     mm0["active"] = false;
                  }
                  catch(err:*)
                  {
                  }
               }
               world["newGame"](0, "LP", null);
               Log.d("RConnectGame: loadSaveTest: newGame bootstrap");
               return false;
            }
            if(g == null)
            {
               return false;   // 新游戏流程进行中，等 gg 出现
            }
            var mm:Object = probe(world, "mm");
            if(mm != null)
            {
               try
               {
                  mm["active"] = false;   // 关菜单让 World.step 接管加载
               }
               catch(err:*)
               {
               }
            }
            world["comLoad"] = slot;   // 原版 Continue 通道（公开字段）
            Log.d("RConnectGame: loadSaveTest -> slot " + slot
               + " (comLoad queued)");
            return true;
         }
         catch(err:*)
         {
            Log.d("RConnectGame: loadSaveTest failed: " + err);
            return false;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return false;
      }

      /** 采集本世界单位快照（M4：宿主广播，客户端镜像）。 */
      public function readUnitsSnapshot():Array
      {
         if(world == null || loc == null)
         {
            refreshWorld();
         }
         if(world == null || loc == null)
         {
            return null;
         }
         var units:Object = probe(loc, "units");
         if(units == null || !(units is Array))
         {
            return null;
         }
         var out:Array = [];
         try
         {
            for each(var u:Object in units as Array)
            {
               if(u == gg)
               {
                  continue;   // 本机玩家自己不同步
               }
               var uid:String = String(probe(u, "id"));
               if(uid.indexOf("rconnect_ghost") == 0)
               {
                  continue;   // 幽灵单位不同步
               }
               out.push({
                  id: uid,
                  cls: getQualifiedClassName(u),
                  x: numOr(probe(u, "X"), 0),
                  y: numOr(probe(u, "Y"), 0),
                  storona: numOr(probe(u, "storona"), 1),
                  sost: numOr(probe(u, "sost"), 1),
                  hp: numOr(probe(u, "hp"), -1),
                  fraction: numOr(probe(u, "fraction"), 0),
                  anim: String(probe(u, "animState"))
               });
            }
         }
         catch(err:*)
         {
         }
         return out;
      }

      /**
       * 把宿主的单位快照镜像到本世界（按 id 匹配，M4 MVP：位置/姿态/血量）。
       * @return {matched, total} 供日志统计
       */
      public function applyUnitsSync(list:Array):Object
      {
         var res:Object = {matched: 0, total: 0};
         if(world == null || loc == null || list == null)
         {
            return res;
         }
         // M8：本地世界被替换（读档/换房/换图）→ 清空同步基线，
         // 否则旧世界血量基线会产生幻影伤害上报（实测宿主被打了几百点）
         resetBaselinesIfWorldChanged();
         var units:Object = probe(loc, "units");
         if(units == null || !(units is Array))
         {
            return res;
         }
         res.total = list.length;
         // 建立 id → 单位 索引（客户端世界）
         var byId:Object = {};
         try
         {
            for each(var u:Object in units as Array)
            {
               var uid:String = String(probe(u, "id"));
               if(uid != null && uid.length > 0 && byId[uid] == undefined)
               {
                  byId[uid] = u;
               }
            }
         }
         catch(err:*)
         {
         }
         for each(var e:Object in list)
         {
            var eid:String = String(e.id);
            var target:Object = byId[eid];
            if(target == null)
            {
               continue;
            }
            try
            {
               target["storona"] = Number(e.storona) >= 0 ? 1 : -1;
               target["setPos"](Number(e.x), Number(e.y));
               if(e.sost != undefined && Number(e.sost) != -1)
               {
                  target["sost"] = int(e.sost);
               }
               if(e.hp != undefined && Number(e.hp) != -1)
               {
                  target["hp"] = Number(e.hp);
                  _baseHp[eid] = Number(e.hp);   // M5b：同步值作为命中检测基线
                  // M8 诊断：hp 写入是否被游戏侧拒绝（幻影伤害排查）
                  var back:* = probe(target, "hp");
                  if(back != null
                     && Math.abs(Number(back) - Number(e.hp)) > 0.5
                     && !_hpRejectLogged[eid])
                  {
                     _hpRejectLogged[eid] = true;
                     Log.d("RConnectGame: hp write rejected '" + eid
                        + "' set=" + Number(e.hp) + " back=" + back);
                  }
               }
               target["setVisPos"]();
               // M5a：冻结被同步单位的本地 AI（视觉已挂，disabled 只停 step）
               // M8：每轮同步都重写——UnitNPC 会自我解除 disabled（实测 vendor
               // disabled=false 后 hp 漂移产生幻影伤害上报）
               if(freezeAI && target != gg)
               {
                  target["disabled"] = true;
                  if(_frozen[eid] == undefined)
                  {
                     _frozen[eid] = target;
                  }
               }
               // M6a：应用宿主姿态状态（公开 animState 字段）
               if(e.anim != undefined && e.anim != null)
               {
                  var wantAnim:String = String(e.anim);
                  var curAnim:String = String(probe(target, "animState"));
                  if(curAnim != wantAnim)
                  {
                     target["animState"] = wantAnim;
                     if(!_animLogged[eid])
                     {
                        _animLogged[eid] = true;
                        Log.d("RConnectGame: puppet anim '" + eid
                           + "' -> " + wantAnim);
                     }
                  }
               }
               res.matched++;
            }
            catch(err:*)
            {
            }
         }
         return res;
      }

      /**
       * M5b：检测本地玩家对单位造成的伤害（hp 低于宿主同步基线 = 本地命中）。
       * 返回 [{id, dmg}] 供客户端上报宿主结算；同时把基线推进到当前值。
       */
      public function scanAndReportDamage():Array
      {
         if(world == null || loc == null)
         {
            return null;
         }
         // M8：世界替换后旧基线会误报幻影伤害（与 applyUnitsSync 同防护）
         resetBaselinesIfWorldChanged();
         var units:Object = probe(loc, "units");
         if(units == null || !(units is Array))
         {
            return null;
         }
         var out:Array = [];
         try
         {
            for each(var u:Object in units as Array)
            {
               if(u == gg)
               {
                  continue;
               }
               var uid:String = String(probe(u, "id"));
               if(uid == null || uid.length == 0
                  || uid.indexOf("rconnect_ghost") == 0
                  || isTrigger(u))
               {
                  continue;
               }
               // M8：只上报敌人（fraction 1..99）——中立单位（NPC/装饰）的
               // 自身逻辑会改 hp（实测 vendor 解冻后 hp 漂移），不是玩家伤害
               var frac:Number = numOr(probe(u, "fraction"), 0);
               if(frac < 1 || frac >= 100)
               {
                  continue;
               }
               var cur:Number = numOr(probe(u, "hp"), -1);
               if(cur < 0)
               {
                  continue;
               }
               var base:* = _baseHp[uid];
               if(base != undefined && cur < Number(base) - 0.5)
               {
                  var dmg:Number = Number(base) - cur;
                  out.push({id: uid, dmg: dmg});
                  _baseHp[uid] = cur;
                  // M8 诊断：幻影伤害排查（记录 cur/base 一次）
                  if(!_phantomLogged[uid])
                  {
                     _phantomLogged[uid] = true;
                     Log.d("RConnectGame: dmg detect '" + uid
                        + "' cur=" + cur + " base=" + base);
                  }
               }
            }
         }
         catch(err:*)
         {
         }
         return out;
      }

      /** M5b（宿主侧）：对指定单位施加伤害（公开 Unit.damage，类型 D_BUL=0）。
       *  M9：attacker 传入客户端幽灵时，把敌人仇恨拉到幽灵上。 */
      public function applyDamage(id:String, dmg:Number, attacker:Object = null):Boolean
      {
         if(world == null || loc == null || dmg <= 0)
         {
            return false;
         }
         var units:Object = probe(loc, "units");
         if(units == null || !(units is Array))
         {
            return false;
         }
         try
         {
            for each(var u:Object in units as Array)
            {
               if(String(probe(u, "id")) == id)
               {
                  u["damage"](dmg, 0, null, false);
                  if(attacker != null)
                  {
                     // 拉仇恨：敌人转向客户端幽灵（priorUnit 满足 findCel 条件）
                     u["priorUnit"] = attacker;
                     u["celUnit"] = attacker;
                  }
                  return true;
               }
            }
         }
         catch(err:*)
         {
            Log.d("RConnectGame: applyDamage failed: " + err);
         }
         return false;
      }

      /**
       * 世界注入（宿主权威）：把本房间的单位集合镜像成宿主快照——
       * 宿主有而本地没有的按类名+游戏数据生成傀儡；本地多出的移除。
       * M8：范围 = 敌人（fraction 1..99）+ 中立单位（fraction 0：NPC/装饰/
       * 动物，傀儡化后视觉一致）。玩家阵营（fraction 100：宠物/玩家陷阱）
       * 不同步。调用方保证：仅当双方处于同一 land 且同一 loc 时调用。
       */
      public function reconcileWorld(list:Array):void
      {
         if(world == null || loc == null || list == null)
         {
            return;
         }
         var units:Object = probe(loc, "units");
         if(units == null || !(units is Array))
         {
            return;
         }
         // 本地现有单位 id 集合
         var localIds:Object = {};
         try
         {
            for each(var u:Object in units as Array)
            {
               var uid:String = String(probe(u, "id"));
               if(uid != null && uid.length > 0)
               {
                  localIds[uid] = true;
               }
            }
         }
         catch(err:*)
         {
         }
         // 1) 生成本地缺失的宿主单位（每次上限 8，避免单帧大建）
         var spawned:int = 0;
         for each(var e:Object in list)
         {
            var eid:String = String(e.id);
            var frac:Number = numOr(e.fraction, 0);
            if(frac >= 100)
            {
               continue;   // 玩家阵营不同步（宠物/玩家放置的陷阱）
            }
            if(localIds[eid])
            {
               continue;
            }
            if(spawned >= 8)
            {
               break;
            }
            if(spawnUnitPuppet(e) != null)
            {
               localIds[eid] = true;
               spawned++;
            }
         }
         // 2) 移除本地多出的非玩家阵营单位（宿主世界没有的）
         try
         {
            var arr:Array = units as Array;
            for(var i:int = arr.length - 1; i >= 0; i--)
            {
               var v:Object = arr[i];
               if(v == gg)
               {
                  continue;
               }
               var vid:String = String(probe(v, "id"));
               if(vid == null || vid.indexOf("rconnect_ghost") == 0)
               {
                  continue;
               }
               var vf:Number = numOr(probe(v, "fraction"), 0);
               if(vf >= 100)
               {
                  continue;
               }
               var inHost:Boolean = false;
               for each(var h:Object in list)
               {
                  if(String(h.id) == vid)
                  {
                     inHost = true;
                     break;
                  }
               }
               if(!inHost)
               {
                  try
                  {
                     loc["remObj"](v);
                     arr.splice(i, 1);
                     delete _frozen[vid];   // 清理已移除单位的动画驱动残留
                     Log.d("RConnectGame: removed local extra '" + vid + "'");
                  }
                  catch(err:*)
                  {
                  }
               }
            }
         }
         catch(err:*)
         {
         }
      }

      /** 按宿主快照动态生成一个傀儡单位（敌人或中立：doop/unres/disabled，
       *  只做视觉与状态同步，不跑本地 AI、不可交互）。 */
      private function spawnUnitPuppet(e:Object):Object
      {
         try
         {
            var eid:String = String(e.id);
            // M13：注塑失败黑名单——boss 类（如 alicorn）构造依赖 XML，
            // AllData 查不到时静默跳过，避免每轮重试刷日志
            if(_injectFailed[eid])
            {
               return null;
            }
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var cls:Object = ad["getDefinition"](String(e.cls));
            if(cls == null)
            {
               Log.d("RConnectGame: inject '" + e.id + "': class "
                  + e.cls + " not found");
               return null;
            }
            var xml:Object = findUnitXml(String(e.id));
            if(xml == null)
            {
               _injectFailed[eid] = true;
               Log.d("RConnectGame: inject '" + e.id + "' skipped: no unit xml"
                  + " (boss? host-authority only)");
               return null;
            }
            var u:Object = new (cls as Class)(String(e.id), 100, xml, null);
            u["doop"] = true;
            u["unres"] = true;
            u["fraction"] = numOr(e.fraction, 1);
            u["warn"] = 0;
            u["id"] = String(e.id);
            u["putLoc"](loc, numOr(e.x, 0), numOr(e.y, 0));
            loc["addObj"](u);
            var units:Object = loc["units"];
            units["push"](u);
            u["disabled"] = true;   // 视觉已挂，停本地 AI
            u["setVisPos"]();
            Log.d("RConnectGame: injected '" + e.id + "' (" + e.cls
               + ") at " + Math.round(numOr(e.x, 0)) + ","
               + Math.round(numOr(e.y, 0)));
            return u;
         }
         catch(err:*)
         {
            _injectFailed[String(e.id)] = true;
            Log.d("RConnectGame: inject '" + e.id + "' failed: " + err);
            return null;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return null;
      }

      private var _injectFailed:Object = {};

      /** 从游戏全量数据 AllData.d 中取单位 XML（blit 动画定义的数据源）。 */
      private function findUnitXml(id:String):Object
      {
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var allDataCls:Object = ad["getDefinition"]("fe.AllData");
            var d:Object = allDataCls["d"];
            if(d is XML)
            {
               var x:XML = (d as XML)..unit.(@id == id)[0];
               if(x != null)
               {
                  return x;
               }
            }
         }
         catch(err:*)
         {
         }
         return null;
      }

      private var _baseHp:Object = {};
      private var _lastLocRef:Object = null;
      private var _phantomLogged:Object = {};
      private var _hpRejectLogged:Object = {};

      /** M8：loc 对象引用变化（读档/换房/换图）时清空客户端同步基线，
       *  防止旧世界血量基线对新世界单位产生幻影伤害上报。 */
      private function resetBaselinesIfWorldChanged():void
      {
         if(_lastLocRef != loc)
         {
            _lastLocRef = loc;
            _baseHp = {};
            _frozen = {};
            _animLogged = {};
            if(loc != null)
            {
               Log.d("RConnectGame: world loc changed, baselines reset");
            }
         }
      }

      /** M6a：驱动被冻结单位的动画（调用游戏自己的公开 animate()，
       *  内部 restart/blit/step 管线由游戏代码完成）。 */
      public function tickFrozenAnims():void
      {
         for(var id:String in _frozen)
         {
            var u:Object = _frozen[id];
            try
            {
               u["animate"]();
            }
            catch(err:*)
            {
            }
         }
      }

      private var _frozen:Object = {};
      private var _animLogged:Object = {};

      /** M6 验证：采样被冻结 blit 单位的显示像素，两次采样不同 = 动画在动。 */
      public function animProbeTest():void
      {
         for(var id:String in _frozen)
         {
            var u:Object = _frozen[id];
            if(probe(u, "blitData") == null)
            {
               continue;   // 只看 blit 渲染的单位
            }
            var px:int = sampleVisPixel(u);
            if(_animProbe.unit == u)
            {
               if(px != _animProbe.px)
               {
                  Log.d("RConnectGame: puppet anim LIVE '" + id
                     + "' px " + _animProbe.px + " -> " + px);
               }
               else
               {
                  Log.d("RConnectGame: puppet anim static '" + id
                     + "' px=" + px);
               }
            }
            else
            {
               Log.d("RConnectGame: puppet probe start '" + id
                  + "' px=" + px);
            }
            _animProbe.unit = u;
            _animProbe.px = px;
            return;
         }
      }

      /** 经显示树取 blit 位图多个采样点的像素和（vis→Sprite→Bitmap）。 */
      private function sampleVisPixel(u:Object):int
      {
         try
         {
            var vis:Object = probe(u, "vis");
            if(vis == null)
            {
               return -1;
            }
            var c0:Object = vis["getChildAt"](0);
            var bmp:Object = c0["getChildAt"](0);
            var bd:Object = bmp["bitmapData"];
            var sum:int = 0;
            for(var i:int = 0; i < 8; i++)
            {
               sum += int(bd["getPixel"](i * 13 + 4, 30 + i * 11));
            }
             return sum;
         }
         catch(err:*)
         {
            return -1;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return -1;
      }

      private var _animProbe:Object = {unit: null, px: 0};

      /** 自动化联测（M5b/M6）：攻击**离本机玩家最近**的存活敌对单位（60 伤害）。
       *  凤凰等特殊单位 hp 可为负而不死，故跳过 hp<=0 的目标。 */
      public function damageTest():void
      {
         if(world == null || loc == null)
         {
            return;
         }
         var units:Object = probe(loc, "units");
         if(units == null || !(units is Array))
         {
            return;
         }
         try
         {
            var px:Number = gg != null ? numOr(probe(gg, "X"), 0) : 0;
            var py:Number = gg != null ? numOr(probe(gg, "Y"), 0) : 0;
            var best:Object = null;
            var bestD:Number = Number.MAX_VALUE;
            for each(var u:Object in units as Array)
            {
               if(u == gg)
               {
                  continue;
               }
               var uid:String = String(probe(u, "id"));
               if(uid == null || uid.indexOf("rconnect_ghost") == 0)
               {
                  continue;
               }
               var frac:Number = numOr(probe(u, "fraction"), 0);
               if(numOr(probe(u, "hp"), -1) <= 0
                  || numOr(probe(u, "sost"), 1) >= 3
                  || frac < 1 || frac >= 100
                  || isTrigger(u))
               {
                  continue;
               }
               var dx:Number = numOr(probe(u, "X"), 0) - px;
               var dy:Number = numOr(probe(u, "Y"), 0) - py;
               var d:Number = dx * dx + dy * dy;
               if(d < bestD)
               {
                  bestD = d;
                  best = u;
               }
            }
            if(best != null)
            {
               best["damage"](60, 0, null, false);
               Log.d("RConnectGame: damageTest hit '"
                  + String(probe(best, "id")) + "' hp="
                  + numOr(probe(best, "hp"), -1)
                  + " dist=" + Math.round(Math.sqrt(bestD)));
            }
         }
         catch(err:*)
         {
            Log.d("RConnectGame: damageTest failed: " + err);
         }
      }

      private var _damageTestIdx:int = 0;

      /** M9/M10b 验证钩子：宿主对第一个客户端幽灵化身直接造成伤害
       *  （伤害量取 testGhostDmg，联测可设大值触发客户端死亡→复活闭环）。 */
      public function ghostDamageTest():void
      {
         for(var k:String in _remotes)
         {
            var ghost:Object = _remotes[k].ghost;
            if(ghost == null)
            {
               continue;
            }
            try
            {
               ghost["damage"](testGhostDmg, 0, null, false);
               Log.d("RConnectGame: ghostDamageTest ghost#" + k
                  + " hp=" + numOr(probe(ghost, "hp"), -1));
            }
            catch(err:*)
            {
               Log.d("RConnectGame: ghostDamageTest failed: " + err);
            }
            return;
         }
      }

      private static function numOr(v:*, def:Number):Number
      {
         return (v != null && isFinite(Number(v))) ? Number(v) : def;
      }

      /** 触发器/陷阱类单位（UnitTrigger：踏板、绊线、罐头等）。
       *  攻击它们曾导致宿主崩溃（trigcans），测试钩子一律跳过。 */
      private function isTrigger(u:Object):Boolean
      {
         try
         {
            return getQualifiedClassName(u).indexOf("UnitTrigger") >= 0;
         }
         catch(err:*)
         {
            return false;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return false;
      }
   }
}
