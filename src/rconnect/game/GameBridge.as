package rconnect.game
{
   import flash.display.Stage;
   import flash.display.DisplayObjectContainer;
   import flash.events.Event;
   import flash.geom.ColorTransform;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.text.TextFormat;
   import flash.utils.Dictionary;
   import fe.serv.RConnectInteractionAccess;
   import fe.unit.Unit;
   import fe.unit.RConnectAnimationAccess;
   import flash.utils.getTimer;
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
      public var roomEpoch:int=0;
      public var independentRooms:Boolean=false;
      public var roomHold:Boolean=false;
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
               // M28: EXIT_FRAME follows all ENTER_FRAME listeners, independent of loader order.
               st.addEventListener(Event.EXIT_FRAME, onVisForceFrame,
                  false, -10000, true);
               st.addEventListener(Event.ENTER_FRAME, onMirrorFrame, false, -10000, true);
               st.addEventListener(Event.RENDER, onVisForceFrame, false, -10000, true);
            }
         }
         catch(err:*)
         {
         }
         refreshWorld();
      }

      private var _hostAlive:Dictionary = new Dictionary();
      private var _mirroring:Boolean = false;
      private var _objects:ObjectIdentity = new ObjectIdentity();
      private var _units:ObjectIdentity = new ObjectIdentity("U");
      private var _mirrorMasks:Dictionary = new Dictionary();
      private var _sceneExpected:Dictionary = new Dictionary();
      private var _scenePending:Dictionary = new Dictionary();
      private var _freezeOriginal:Dictionary = new Dictionary();
      private var _spawnedPuppets:Dictionary = new Dictionary();
      private var _hitUnits:Dictionary = new Dictionary();
      private var _unitMotion:Dictionary = new Dictionary();
      private var _pendingHits:Dictionary = new Dictionary();
      private var _forcingVisibility:Boolean = false;
      private var _animatingMirrors:Boolean = false;
      private var _shieldFeedback:Dictionary = new Dictionary(true);
      private var _unitView:Dictionary = new Dictionary();
      private var _viewErrors:Object = {};
      // Optional runtime timing sink; null in normal play.
      public var presentationTiming:Object=null;

      public function endSession():void
      {
         _mirroring = false;
         _terrain.reset();
         _presentation.reset();
         _shieldFeedback = new Dictionary(true);
         clearHitUnits();
         _unitMotion = new Dictionary();
         _pendingHits = new Dictionary();
         restoreMirrorMasks();
         restoreUnitViews();
         _hostAlive = new Dictionary();
         for(var id:String in _remotes) removeRemote(int(id));
         for(var unit:Object in _freezeOriginal)
         {
            try { unit["disabled"] = _freezeOriginal[unit]; } catch(err:*) {}
         }
         _freezeOriginal = new Dictionary();
         for(var puppet:Object in _spawnedPuppets)
         {
            try
            {
               var room:Object = _spawnedPuppets[puppet];
               room["remObj"](puppet);
               var units:Array = room["units"] as Array;
               var index:int = units.indexOf(puppet);
               if(index >= 0) units.splice(index, 1);
            }
            catch(removeError:*) {}
         }
         _spawnedPuppets = new Dictionary();
         _frozen = new Dictionary();
         _baseHp = new Dictionary();
         _objects.reset();
         _units.reset();
         _sceneExpected = new Dictionary();
         _scenePending = new Dictionary();
         _boxTween = new Dictionary();
         _boxTrack = new Dictionary();
         _istExpectO = new Dictionary();
         _istPending = new Dictionary();
         _istSeen = new Dictionary();
         _istLast = new Dictionary();
         _istSeenLoc = null;
         _istLastLoc = null;
         _lastLocRef = null;
         lootSyncReset();
      }


      /** M27：宿主快照里存活的镜像单位（applyUnitsSync 每轮重建；
       *  死亡/离房自动移出——不强制显示尸体）。 */
      private function onVisForceFrame(e:Event):void
      {
         if(roomHold)return;
         if(_forcingVisibility || _animatingMirrors || _applyingUnits) return;
         var measureAt:int=presentationTiming==null?0:getTimer();
         _forcingVisibility = true;
         try
         {
            for(var remoteId:String in _remotes)
            {
               var rec:Object=_remotes[remoteId];
               try
               {
                  if(rec.ghost != null && rec.snap != null)
                  {
                     if(rec.snap.bodyPlaying === false && rec.motion != null)
                        driveVisAnim(rec.ghost,rec.motion.sample(getTimer()),int(remoteId));
                     if(rec.snap.ap != null)
                        RemoteArmor.apply(probe(rec.ghost,"vis") as DisplayObjectContainer,String(rec.snap.ap.armor || ""));
                  }
               }
               catch(armorError:*) {logViewError("remote-"+remoteId,armorError);}
            }
            if(!_mirroring) return;
            tickLootMotion();
            for(var viewed:Object in _unitView)
               if(probe(viewed,"loc")===loc)
                  try {applyUnitView(viewed,_unitView[viewed].host);_presentation.enforce(viewed);}
                  catch(viewError:*) {logViewError(String(probe(viewed,"id")),viewError);}
            for(var u:Object in _hostAlive)
            {
               try
               {
               var vis:Object = probe(u, "vis");
               if(probe(u, "loc") !== loc || numOr(probe(u, "sost"), 3) >= 3
                  || !unitCanShow(u))
               {
                  restoreMirrorMask(vis);
                  continue;
               }
               // drawLoc replaces the layer tree. A frozen unit can still have
               // a parent in the detached old tree; parent != null is insufficient.
               if(vis != null && (probe(vis, "parent") == null || probe(vis,"stage") !== probe(main,"stage"))
                  && probe(u, "in_chain") == true)
               {
                  var disabled:Boolean = probe(u, "disabled") == true;
                  try { u["disabled"] = false; u["addVisual"](); }
                  finally { u["disabled"] = disabled; }
               }
               if(vis == null) continue;
               releaseMirrorMask(vis);
               vis["visible"] = true;
               u["prior"] = 1;
               }
               catch(unitError:*) {logViewError(String(probe(u,"id")),unitError);}
            }
         }
         catch(err:*)
         {
         }
         finally {
            _forcingVisibility = false;
            if(presentationTiming!=null){presentationTiming.viewMs+=getTimer()-measureAt;presentationTiming.viewCalls++;}
         }
      }

      private function onMirrorFrame(e:Event):void
      {
         if(roomHold)return;
         if(!_mirroring) _presentation.observe(loc);
         try {main.stage.invalidate();} catch(stageError:*) {}
         // Native ghost physics and packet arrivals must not dictate display cadence.
         for(var id:String in _remotes)
         {
            var rec:Object=_remotes[id];
            if(rec.ghost!=null && rec.motion!=null && probe(rec.ghost,"loc")===loc)
               driveGhost(rec.ghost,rec.motion.sample(getTimer()),int(id));
         }
         if(!_mirroring) return;
         tickFrozenAnims();
      }

      private function logViewError(id:String,error:*):void
      {
         if(_viewErrors[id]) return;
         _viewErrors[id]=true;
         Log.d("RConnectGame: presentation '"+id+"' failed: "+error);
      }

      private function unitView(u:Object):Object
      {
         return {invis:probe(u,"invis")==true,isVis:probe(u,"isVis")!=false,isSats:probe(u,"isSats")==true,
            alpha:numOr(probe(probe(u,"vis"),"alpha"),1)};
      }

      private function applyUnitView(u:Object,state:Object):void
      {
         if(state==null) return;
         if(state.invis is Boolean) u["invis"]=state.invis;
         if(state.isVis is Boolean) u["isVis"]=state.isVis;
         if(state.isSats is Boolean) u["isSats"]=state.isSats;
         var vis:Object=probe(u,"vis");
         if(vis!=null && state.alpha!=null && isFinite(Number(state.alpha)))
            vis["alpha"]=Math.max(0,Math.min(1,Number(state.alpha)));
         if(vis!=null && (state.isVis===false || (state.invis===true && Number(state.alpha)<=0)))
            vis["visible"]=false;
      }

      private function unitCanShow(u:Object):Boolean
      {
         if(probe(u,"isVis")==false) return false;
         if(probe(u,"invis")!=true) return true;
         // Native camouflage can still shimmer while moving or firing. Keep
         // its gameplay invisibility, but show the host's partial fade.
         var rec:Object=_unitView[u];
         return rec!=null && Number(rec.host.alpha)>0;
      }

      private function restoreUnitViews():void
      {
         for(var u:Object in _unitView)
            try {applyUnitView(u,_unitView[u].original);} catch(error:*) {}
         _unitView=new Dictionary();
      }

      // A sibling alpha mask can erase every pixel despite visible=true.
      // Hide the detached mask itself to prevent white rectangles in its layer.
      private function releaseMirrorMask(vis:Object):void
      {
         var mask:Object = probe(vis, "mask");
         if(mask == null) return;
         if(_mirrorMasks[vis] == null)
            _mirrorMasks[vis] = {mask:mask, visible:probe(mask,"visible"), cache:probe(vis,"cacheAsBitmap")};
         mask["visible"] = false;
         vis["mask"] = null;
         vis["cacheAsBitmap"] = false;
      }

      private function restoreMirrorMasks():void
      {
         for(var vis:Object in _mirrorMasks) restoreMirrorMask(vis);
         _mirrorMasks = new Dictionary();
      }

      private function restoreMirrorMask(vis:Object):void
      {
         var saved:Object = _mirrorMasks[vis];
         if(saved == null) return;
         try
         {
            if(probe(saved.mask,"parent") != null) vis["mask"] = saved.mask;
            saved.mask.visible = saved.visible;
            vis["cacheAsBitmap"] = saved.cache;
         }
         catch(err:*) {}
         delete _mirrorMasks[vis];
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
            // M23：开机链门控——landData 由开机 stage-2 异步建立，未就绪时
            // Game 构造器访问 World.w.landData 直接 #1009（TDFC AutoTest
            // 同款教训），且失败的 newGame 会留下半初始化世界连累重试。
            // 等待即可，由 Session 周期重入。
            if(probe(world, "landData") == null)
            {
               Log.d("RConnectGame: startGame: landData not ready, wait");
               return;
            }
            _autoTries++;
            Log.d("RConnectGame: startGame: calling newGame (try "
               + _autoTries + ")");
            world["newGame"](-1, "LP", null);
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
         if(loc == null || probe(gg,"loc") !== loc) return null;
         s.x = numOr(probe(gg, "X"), 0);
         s.y = numOr(probe(gg, "Y"), 0);
         s.storona = numOr(probe(gg, "storona"), 1);
         s.dx = numOr(probe(gg, "dx"), 0);
         s.dy = numOr(probe(gg, "dy"), 0);
         s.stay = numOr(probe(gg, "stay"), 0);
         s.hp = numOr(probe(gg, "hp"), -1);
         s.maxhp = numOr(probe(gg, "maxhp"), 100);
         s.sost = numOr(probe(gg, "sost"), -1);
         s.hitShape=unitFields(gg,["scX","scY","dexter","dexterPlus","dodge","neujazMax","invulner","transp","vulner"]);
         s.visibility = numOr(probe(gg,"visibility"),1000);
         s.stealthMult = numOr(probe(gg,"stealthMult"),1);
         s.demask = numOr(probe(gg,"demask"),0);
         s.noise = numOr(probe(gg,"noise"),0);
         // M10b：带土地/房间身份，宿主据此隐藏"在别的土地"的客户端化身
         var g0:Object = probe(world, "game");
         s.landId = g0 != null ? String(probe(g0, "curLandId")) : "";
         s.locId = loc != null ? String(probe(loc, "id")) : "";
         s.roomKey=roomKey();s.roomEpoch=roomEpoch;
         // M14b：当前武器 id/变体（远端据此在幽灵手上镜像同款武器）
         var cw:Object = probe(gg, "currentWeapon");
         s.wi = cw != null ? String(probe(cw, "id")) : "";
         s.wv = cw != null ? int(numOr(probe(cw, "variant"), 0)) : 0;
         // M16：本机当前姿态标签（vis.osn.currentLabel）——让远端幽灵直接
         // 播放对方真实姿态（站/走/跑/蹲/趴都由对方游戏决定，不再本地猜测）
         s.pose = localPoseLabel();
         var osn:Object = probe(probe(gg, "vis"), "osn");
         s.poseFrame = numOr(probe(osn, "currentFrame"), 1);
         s.bodyFrame = numOr(probe(probe(osn, "body"), "currentFrame"), 1);
         s.bodyPlaying = probe(probe(osn, "body"), "isPlaying") == true;
         s.isSit = probe(gg, "isSit") == true;
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
         var snapRoom:String = snap.locId == null ? "" : String(snap.locId);
         if((snap.roomKey!=null && (String(snap.roomKey)!=roomKey() || int(snap.roomEpoch)!=roomEpoch))
            || (myLand != "" && snapLand != "" && myLand != snapLand)
            || (snapRoom != "" && snapRoom != String(probe(loc, "id"))))
         {
            if(rec.ghost != null)
            {
               despawnGhost(rec.ghost, id);
               rec.ghost = null;
               rec.motion = null;
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
            rec.motion = new RemoteMotion();
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
            if(rec.motion == null) rec.motion = new RemoteMotion();
            rec.motion.push(snap,getTimer());
            driveGhost(ghost, rec.motion.sample(getTimer()), id);
            syncRemoteWeapon(ghost, snap, id);
            // M20：外观热更——对方换装/换护甲后按 apKey 变化重装视觉
            var ak:String = apKeyOf(snap.ap);
            if(_apKey[id] != ak && snap.ap != null
               && snap.ap.cFur != undefined)
            {
               _apKey[id] = ak;
               restyleGhost(rec, id, snap);
            }
         }
      }

      private function apKeyOf(ap:Object):String
      {
         if(ap == null)
         {
            return "";
         }
         return JSON.stringify([ap.armor, ap.hideMane, ap.visHair1, ap.fEye, ap.fHair,
            ap.cFur, ap.cHair, ap.cHair1, ap.cEye, ap.cMagic,
            ap.tf, ap.tH, ap.tH1, ap.tE, ap.tM]);
      }

      private var _apKey:Object = {};

      /** M20：按对方最新外观重建幽灵视觉（保留名字标签与武器）。 */
      private function restyleGhost(rec:Object, id:int, snap:Object):void
      {
         var ghost:Object = rec.ghost;
         if(ghost == null)
         {
            return;
         }
         try
         {
            // 摘武器（旧 vis 将被替换）
            var wvis:Object = _weaponVis[id];
            var newVis:Object = buildPlayerVisStyled(snap.ap);
            if(newVis == null)
            {
               return;
            }
            preparePlayerVis(newVis);
            var name:String = rec.name != null ? String(rec.name) : "";
            // 迁移标签（新 vis 上重建）
            applyGhostMarking2(newVis, name, ghost);
            // 迁移武器
            if(wvis != null)
            {
               try
               {
                  newVis["addChild"](wvis);
               }
               catch(err:*)
               {
               }
            }
            var oldVis:Object = probe(ghost, "vis");
            var parent:Object = probe(oldVis, "parent");
            if(parent != null)
            {
               var index:int = parent["getChildIndex"](oldVis);
               parent["removeChild"](oldVis);
               parent["addChildAt"](newVis, index);
            }
            ghost["vis"] = newVis;
            ghost["setVisPos"]();
            driveVisAnim(ghost, snap, id);
            if(wvis != null)
            {
               _weaponVis[id] = wvis;
            }
            // 立即套用姿态
            var rec2:Object = _animState[id];
            if(rec2 != null)
            {
               rec2.label = "";
            }
            Log.d("RConnectGame: ghost #" + id + " restyled (appearance change)");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: restyleGhost failed: " + err);
         }
      }

      /** 把新 visualPlayer 做与玩家一致的初始化整理（拆出 installPlayerVis 共用）。 */
      private function preparePlayerVis(vis:Object):void
      {
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
            hideChild(vis, "inh");
            hideChild(vis, "cryst");
            hideChild(vis, "fetter");
            hideChild(vis, "rat");
            hideChild(vis, "shit");
            hideChild(vis, "svet");
         }
      }

      /** 在新 vis 上重建名字标签（不依赖 ghost 上的旧引用）。 */
      private function applyGhostMarking2(vis:Object, name:String,
         ghost:Object):void
      {
         try
         {
            var tf:TextField = new TextField();
            var fmt:TextFormat = new TextFormat("_sans", 12, 0xFFE066, true);
            tf.defaultTextFormat = fmt;
            tf.text = name.length > 0 ? name : "player";
            tf.selectable = false;
            tf.mouseEnabled = false;
            tf.autoSize = TextFieldAutoSize.CENTER;
            tf.y = -110;
            tf.x = -tf.width / 2;
            vis["addChild"](tf);
            vis["_rconnect_label"] = tf;
         }
         catch(err:*)
         {
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

      public function readRemoteHits(id:int):Array {
         var ghost:RemoteDamageUnit=getRemoteGhost(id) as RemoteDamageUnit;
         return ghost==null?[]:ghost.drain();
      }
      private var _incomingHit:NativeHit=new NativeHit();
      public function applyPlayerHits(hits:Array):void {
         if(hits==null || gg==null || isPlayerDead())return;
         for each(var hit:Object in hits) {
            if(isPlayerDead())break;
            try {_incomingHit.apply(gg,hit,main);}
            catch(err:*) {logViewError("incoming-hit",err);}
         }
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
         delete _ghostHp[id];
         delete _ghostPassive[id];
         delete _apKey[id];
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
            var tr:int = 5 + (id % 10);   // 不同远程玩家用不同配色
            var ghost:Object = new RemoteDamageUnit(tr);
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
            applyUnitFields(ghost,snap.hitShape);
            for each(var sense:String in ["visibility","stealthMult","demask","noise"])
               if(snap[sense] != null) ghost[sense] = Number(snap[sense]);
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
               // M18b/M23：强制不悬浮——幽灵垂直位置只由快照 setPos 决定，
               // isFly 与 levit 都压掉，防止游戏自身飞行/悬浮物理把幽灵
               // 带起来（“飞行药水效果”）
               ghost["isFly"] = false;
               ghost["levit"] = false;
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
         if(rec == null) rec = _animState[id] = {lx:0,ly:0,label:""};
         if(snap.poseFrame != null && snap.bodyFrame != null)
         {
            try
            {
               var targetOsn:Object = probe(probe(ghost, "vis"), "osn");
               var pf:int = int(snap.poseFrame);
               if(pf >= 1 && pf <= numOr(probe(targetOsn, "totalFrames"), 0))
               {
                  var changed:Boolean=int(probe(targetOsn, "currentFrame")) != pf || rec.osn !== targetOsn;
                  if(changed) targetOsn["gotoAndStop"](pf);
                  var targetBody:Object = probe(targetOsn, "body");
                  if(!changed && rec.body===targetBody && rec.frameSnap===snap
                     && (snap.bodyPlaying === true || int(probe(targetBody,"currentFrame"))==int(snap.bodyFrame))) return;
                  rec.osn=targetOsn;rec.body=targetBody;rec.frameSnap=snap;
                  var bf:int = int(snap.bodyFrame);
                  var total:int=int(numOr(probe(targetBody,"totalFrames"),0));
                  if(bf >= 1 && bf <= total)
                  {
                     if(snap.bodyPlaying === true)
                     {
                        var drift:int=Math.abs(int(probe(targetBody,"currentFrame"))-bf);
                        drift=Math.min(drift,total-drift);
                        // Let the game's own frame scripts loop/stop. Only correct a
                        // changed pose or significant drift, not every packet/frame.
                        if(changed || probe(targetBody,"isPlaying")!==true || drift>Math.max(3,total/3))
                           targetBody["gotoAndPlay"](bf);
                     }
                     else
                     {
                        if(int(probe(targetBody,"currentFrame"))!=bf) targetBody["gotoAndStop"](bf);
                        // A frame script may call play while gotoAndStop constructs
                        // the frame. Stop after construction, without re-entering it.
                        targetBody["stop"]();
                     }
                  }
                  return;
               }
            }
            catch(poseError:*) {}
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
            // M23：皮肤语义映射。玩家皮肤(visualPlayer)的 idle 主段是
            // "stay"（UnitPlayer.animate：stay 段=站立待机基础位，
            // free1/2/3 只是随机小动作），而幽灵皮肤(NPC 小马视觉)的
            // "stay" 渲染为趴/卧姿（M16a/M20 实证）——直接镜像会让幽灵
            // 大部分时间趴着。玩家 idle 族 {stay,free1,free2,free3} 映射
            // 到幽灵站立待机族：stay→free1，freeX 原样；移动/跳跃等
            // 其余标签两皮肤语义一致，原样透传。
            if(label == "stay")
            {
               label = "free1";
            }
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
            // M20：兜底用站立待机标签 free1——"stay" 是蹲/趴姿态，
            // 旧客户端无 pose 字段时绝不能回落到趴姿
            label = "free1";
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
         w.landProb=loc==null?"":String(probe(loc,"landProb"));
         w.roomKey=roomKey();w.roomEpoch=roomEpoch;
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
         if(independentRooms) return "skip-same-map";
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
         _objects.enter(loc);
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
               var ent:Object = {
                  id: id,
                  k: _objects.key(b),
                  cls: getQualifiedClassName(b),
                  x: numOr(probe(b, "X"), -1),
                  y: numOr(probe(b, "Y"), -1),
                  w: numOr(probe(b, "wall"), 0),
                  // M25：念力托举态（levit/fracLevit）——接收端据此保持悬浮
                  // （stay=true 抗重力）而不是让它下坠
                  q: (numOr(probe(b, "levit"), 0) != 0
                     || numOr(probe(b, "fracLevit"), 0) > 0),
                  dead: probe(b, "dead") == true,
                  hp: numOr(probe(b,"hp"),0),
                  door: numOr(probe(b, "door"), -1),
                  door_opac: numOr(probe(b, "door_opac"), -1),
                  shelf: probe(b, "shelf") == true
               };
               // M22：交互状态（门开关/上锁/已搜刮/陷阱/爆炸）。
               // saveOpen/saveLock 等是 fe.serv 内部成员，外部只能走公共
               // save() 打包；open 与 lock 用实时值——open 是 autoClose 门
               // 的唯一可靠来源，而 saveLock 在开门后不清（setAct("open")
               // 只清实时 lock），照发会让加入方"开着门还带锁"。
               // 开着的对象不带 lock（游戏语义开=无锁）；实时 lock=100
               // （卡死）映射回 102（setAct 只认 101/102 特殊值）。
               // 持久状态纪律（M17 教训的 door 版）：按房间记住曾经非
               // 默认的字段（_istSeen），回默认后也显式广播 0 值——否则
               // "开门后再关门/解锁"的字段直接消失，加入方锁存回不去。
               var iv:Object = probe(b, "inter");
               if(iv == null && numOr(probe(b, "door"), 0) > 0)
                  ent.doorOpen = firstDoorTilePhis(b) == 0;
               if(iv != null)
               {
                  if(_istSeenLoc !== loc)
                  {
                     _istSeenLoc = loc;
                     _istSeen = new Dictionary();
                  }
                  var seen:Object = _istSeen[b];
                  if(seen == null)
                  {
                     seen = {open: false, lock: false, mine: false,
                        loot: false, expl: false};
                     _istSeen[b] = seen;
                  }
                  var so:Object = {};
                  iv["save"](so);
                  var ist:Object = null;
                  // autoClose 门（XML autoclose/time）的 open 是瞬态——游戏
                  // 存档也不持久化它（setAct: if(autoClose==0) saveOpen），
                  // 且堵门/脚本会让它高速振荡，不同步
                  var ac:int = numOr(probe(iv, "autoClose"), 0);
                  var isOpen:Boolean = (probe(iv, "open") == true && ac == 0);
                  if(isOpen)
                  {
                     ist = istNew(ist, "open", 1);
                     seen.open = true;
                  }
                  else if(seen.open)
                  {
                     ist = istNew(ist, "open", 0);
                  }
                  if(!isOpen)
                  {
                     var lv:int = numOr(probe(iv, "lock"), 0);
                     if(lv == 100)
                     {
                        lv = 102;
                     }
                     if(lv != 0)
                     {
                        ist = istNew(ist, "lock", lv);
                        seen.lock = true;
                     }
                     else if(seen.lock)
                     {
                        ist = istNew(ist, "lock", 0);
                     }
                  }
                  var mv:int = numOr(so.mine, 0);
                  if(mv != 0)
                  {
                     ist = istNew(ist, "mine", mv);
                     seen.mine = true;
                  }
                  else if(seen.mine)
                  {
                     ist = istNew(ist, "mine", 0);
                  }
                  var lov:int = numOr(so.loot, 0);
                  if(lov > 0)
                  {
                     ist = istNew(ist, "loot", lov);
                     seen.loot = true;
                  }
                  var ev:int = numOr(so.expl, 0);
                  if(ev != 0)
                  {
                     ist = istNew(ist, "expl", ev);
                     seen.expl = true;
                  }
                  else if(seen.expl)
                  {
                     ist = istNew(ist, "expl", 0);
                  }
                  if(ist != null)
                  {
                     ent.ist = ist;
                  }
               }
               out.push(ent);
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
         _objects.enter(loc);
         if(_boxTrackLoc!==loc) {
            _boxTrackLoc=loc;boxTrackReset();_istExpectO=new Dictionary();_istPending=new Dictionary();
         }
         var byId:Object = {};
         // M25：本轮已消费的 Box（同 id 就近匹配用）
         var consumed:Dictionary = new Dictionary();
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
            var lb:Object = _objects.resolve(h, objs as Array, consumed);
            if(lb == null && h.dead != true && String(h.cls) == "fe.loc::Box")
            {
               try
               {
                  var ad:Object = main["loaderInfo"]["applicationDomain"];
                  var boxClass:Class = ad["getDefinition"]("fe.loc.Box") as Class;
                  var pos:Object = validLandPos(Number(h.x), Number(h.y));
                  if(pos != null)
                  {
                     var made:Object = new boxClass(loc,String(h.id),int(pos.x),int(pos.y));
                     if(numOr(probe(made,"door"),0)>0) made["initDoor"]();
                     (objs as Array).push(made);
                     loc["addObj"](made);
                     _objects.bind(String(h.k), made);
                     lb = _objects.resolve(h, objs as Array, consumed);
                     Log.d("RConnectGame: scene object injected '"+String(h.id)+"' key="+String(h.k));
                  }
               }
               catch(createError:*) { Log.d("RConnectGame: scene injection failed: "+createError); }
            }
            if(lb == null)
            {
               continue;
            }
            queueSceneChange(lb);
            captureInteractionIntent(lb);
            var pending:Object = _scenePending[lb];
            if(pending != null)
            {
               if((pending.dead == true && h.dead != true)
                  || (pending.doorOpen != null && pending.doorOpen != h.doorOpen)) continue;
               delete _scenePending[lb];
            }
            try
            {
               if(h.dead != undefined)
               {
                  var wasDead:Boolean = (probe(lb, "dead") == true);
                  if(!wasDead && h.dead == true)
                  {
                     _boxDeadLogged[String(h.id)] = true;
                     if(numOr(probe(lb, "door"), 0) > 0)
                     {
                        // M22：门类 Box 只翻 dead 字段不清瓦片（phis/opac/视觉
                        // 都在瓦片上）——走 die(-1)，即存档加载恢复同款路径
                        lb["die"](-1);
                        Log.d("RConnectGame: door destroyed synced '"
                           + String(h.id) + "'");
                     }
                     else
                     {
                        lb["die"](-1);
                        Log.d("RConnectGame: box destroyed synced '" + String(h.id)
                           + "'");
                     }
                  }
                  // 只单向置 dead（游戏语义死亡不可逆；不回写 false 防止
                  // 宿主快照把加入方本地破坏过的物品"复活"）
                  if(h.dead == true)
                  {
                     lb["dead"] = true;
                  }
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
               if(h.ist != undefined && h.ist != null)
               {
                  applyIst(lb, String(h.id), h.ist);
               }
               applySceneState(lb, h);
               // M25：可移动 Box（念力可移动物品：wall==0 且非门）位置镜像
               // ——就近匹配同 id（房间可有多个同 id 箱子），本地正被念力
               // 托举的跳过（防镜像与本地持有互抢，由上报通道主导）
               if(numOr(h.door, 0) <= 0 && numOr(h.w, 0) <= 0
                  && numOr(h.x, -1) >= 0)
               {
                  var cand:Object = lb;
                  if(cand != null && !boxHeldLocally(cand))
                  {
                     trackBoxPos(cand, Number(h.x), Number(h.y),
                        h.q == true);
                  }
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

      private function applySceneState(b:Object, s:Object):void
      {
         if(s.dead == true && probe(b, "dead") != true) b["die"](-1);
         if(probe(b, "dead") != true && s.doorOpen != null
            && probe(b, "inter") == null && numOr(probe(b, "door"), 0) > 0)
         {
            if((firstDoorTilePhis(b) == 0) != (s.doorOpen == true))
            {
               b["setDoor"](s.doorOpen == true);
               loc["isRelight"] = true;
               loc["isRebuild"] = true;
            }
         }
         _sceneExpected[b] = {dead: probe(b, "dead") == true,
            doorOpen: firstDoorTilePhis(b) == 0};
      }

      private function scanSceneReports():Array
      {
         var changes:Array = [];
         for(var b:Object in _sceneExpected)
         {
            queueSceneChange(b);
            if(_scenePending[b] != null) changes.push(_scenePending[b]);
         }
         return changes;
      }

      private function queueSceneChange(b:Object):void
      {
            // Keep local intent until the host acknowledges it. A tile patch or
            // redraw can change physical door tiles while that intent is in flight.
            if(_scenePending[b] != null) return;
            var ex:Object = _sceneExpected[b];
            if(ex == null) return;
            var dead:Boolean = probe(b, "dead") == true;
            var open:Boolean = firstDoorTilePhis(b) == 0;
            var scriptDoor:Boolean = probe(b, "inter") == null && numOr(probe(b, "door"), 0) > 0;
            if((dead && !ex.dead) || (scriptDoor && !dead && open != ex.doorOpen))
            {
               var s:Object = {k: _objects.known(b), id: String(probe(b, "id")),
                  x: probe(b, "X"), y: probe(b, "Y"), dead: dead};
               if(scriptDoor) s.doorOpen = open;
               _scenePending[b] = s;
               Log.d("RConnectGame: scene local pending " + JSON.stringify(s));
               ex.dead = dead;
               ex.doorOpen = open;
            }
      }

      private var _objsLogged2:Boolean = false;
      private var _boxDeadLogged:Object = {};

      /** M22：ist 构造（懒初始化）。 */
      private function istNew(ist:Object, key:String, val:int):Object
      {
         if(ist == null)
         {
            ist = {};
         }
         ist[key] = val;
         return ist;
      }

      private var _istLast:Dictionary = new Dictionary();
      private var _istLastLoc:Object = null;
      private var _istSeen:Dictionary = new Dictionary();
      private var _istSeenLoc:Object = null;

      /** Local interactions awaiting the authority's matching echo. */
      private var _istPending:Dictionary=new Dictionary();

      private function captureInteractionIntent(b:Object):void {
         var iv:Object=probe(b,"inter");
         if(iv==null || numOr(probe(iv,"autoClose"),0)>0 || probe(b,"dead")==true)return;
         var so:Object={};iv["save"](so);
         var current:Object={o:probe(iv,"open")==true?1:0,l:int(probe(iv,"lock")),t:numOr(so.loot,0)>0?2:0};
         if(current.l==100)current.l=102;
         var expected:Object=_istExpectO[b];
         if(expected==null){_istExpectO[b]=current;return;}
         var pending:Object=_istPending[b];
         for each(var field:String in ["o","l","t"])if(current[field]!=expected[field]) {
            if(pending==null)pending=_istPending[b]={id:String(b.id),k:_objects.known(b),x:b.X,y:b.Y};
            pending[field]=current[field];expected[field]=current[field];
         }
      }
      private function acceptInteraction(b:Object,field:String,value:int):Boolean {
         var pending:Object=_istPending[b];
         if(pending!=null && pending[field]!=undefined) {
            if(int(pending[field])!=value)return false;
            delete pending[field];
            if(pending.o==undefined && pending.l==undefined && pending.t==undefined)delete _istPending[b];
         }
         return true;
      }

      /** M22：把宿主交互状态应用到本地 inter。只在变化时 setAct——
       *  setAct 会触发 setVisState（开门/搜刮音效）与整房重光照，
       *  每 200ms 重放会刷屏；应用值记入 _istLast（换房重置，
       *  不同房间可有同名 id）。被阻挡的关门（有人堵门口）会在本地
       *  保持 open，属于游戏自身语义，宿主下次变更前不再重试。 */
      private function applyIst(lb:Object, oid:String, ist:Object):void
      {
         try
         {
            if(_istLastLoc !== loc)
            {
               // M22 诊断：非 null→null 的重置说明 loc 引用在换，锁存被清
               if(_istLastLoc != null)
               {
                  Log.d("RConnectGame: ist latch RESET (loc ref changed)");
               }
               _istLastLoc = loc;
               _istLast = new Dictionary();
            }
            var iv:Object = probe(lb, "inter");
            if(iv == null)
            {
               return;
            }
            if(probe(lb, "dead") == true)
            {
               return;   // 已破坏：die(-1) 已定视觉，交互状态不再镜像
            }
            var last:Object = _istLast[lb];
            if(last == null)
            {
               last = {open: -1, lock: -1, loot: 0, mine: -1, expl: -1};
               _istLast[lb] = last;
            }
            // TCP preserves event order. Apply once immediately; retain a local
            // interaction until the authority echoes it, instead of delaying all doors.
            var v:int;
            if(ist.open != undefined && acceptInteraction(lb,"o",int(ist.open)))
            {
               v = int(ist.open);
               last.open=v;
               if((probe(iv,"open")==true?1:0)!=v)iv["setAct"]("open",v);
               istExpectSet(lb,"o",v);
               if(v==1) {
                  // Native opening clears the lock. Open snapshots omit lock,
                  // so this is also the acknowledgement of a local unlock.
                  acceptInteraction(lb,"l",0);
                  last.lock=0;istExpectSet(lb,"l",0);
               }
            }
            if(ist.lock != undefined && acceptInteraction(lb,"l",int(ist.lock)))
            {
               v = int(ist.lock);
               if(last.lock!=v)iv["setAct"]("lock",v);
               last.lock=v;istExpectSet(lb,"l",v);
            }
            // Native search writes saveLoot=1; restoration may write 2. Both
            // acknowledge an opened container and must not echo forever.
            if(ist.loot != undefined && acceptInteraction(lb,"t",int(ist.loot)>0?2:0) && last.loot != (int(ist.loot)>0?2:0))
            {
               v = int(ist.loot);
               last.loot = v>0?2:0;
               iv["setAct"]("loot", v);
               istExpectSet(lb,"t",last.loot);
               Log.d("RConnectGame: ist apply loot=" + v + " '" + oid + "'");
            }
            if(ist.mine != undefined && last.mine != int(ist.mine))
            {
               v = int(ist.mine);
               last.mine = v;
               iv["setAct"]("mine", v);
            }
            if(ist.expl != undefined && last.expl != int(ist.expl))
            {
               v = int(ist.expl);
               last.expl = v;
               iv["setAct"]("expl", v);
            }
         }
         catch(err:*)
         {
         }
      }

      /** M25：推进 joiner 的 ist 期望态（宿主广播应用后调用，
       *  防止回流被 scanObjReports 误判为本地变更重复上报）。按对象实例。 */
      private function istExpectSet(lb:Object, key:String, v:int):void
      {
         var ex:Object = _istExpectO[lb];
         if(ex == null)
         {
            _istExpectO[lb] = {o: 0, l: 0, t: 0};
            ex = _istExpectO[lb];
         }
         ex[key] = v;
      }

      /** M22：读门 Box 第一块从属瓦片的 phis（0=通行，>0=阻挡）。 */
      private function firstDoorTilePhis(lb:Object):int
      {
         try
         {
            var tiles:Object = probe(lb, "tiles");
            if(tiles is Array && (tiles as Array).length > 0)
            {
               return numOr(probe((tiles as Array)[0], "phis"), -1);
            }
         }
         catch(err:*)
         {
         }
         return -1;
      }

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

      private var _doorIcTestOpen:Boolean = false;

      /** M22 复现钩子：宿主开关第一个活着的门——走真实使用路径
       *  inter.command("open"/"close")（含 autoClose 计时语义），
       *  每次调用翻转开/关。附 tilePhis 证明瓦片碰撞真实切换。
       *  跳过 autoClose 门——其 open 是瞬态，不参与同步。 */
      public function doorIcTest():void
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
            for each(var b:Object in objs as Array)
            {
               if(probe(b, "dead") == true || numOr(probe(b, "door"), 0) <= 0)
               {
                  continue;
               }
               var iv:Object = probe(b, "inter");
               if(iv == null)
               {
                  continue;
               }
               if(numOr(probe(iv, "autoClose"), 0) > 0)
               {
                  continue;
               }
               _doorIcTestOpen = !_doorIcTestOpen;
               iv["command"](_doorIcTestOpen ? "open" : "close");
               Log.d("RConnectGame: doorIcTest "
                  + (_doorIcTestOpen ? "open" : "close")
                  + " '" + String(probe(b, "id"))
                  + "' tilePhis=" + firstDoorTilePhis(b));
               return;
            }
            Log.d("RConnectGame: doorIcTest: no door obj");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: doorIcTest failed: " + err);
         }
      }

      /** M22 复现钩子：宿主搜刮第一个非空容器（setAct("loot",2)，
       *  与存档恢复同款状态写入）。 */
      public function boxLootTest():void
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
            for each(var b:Object in objs as Array)
            {
               if(probe(b, "dead") == true)
               {
                  continue;
               }
               var iv:Object = probe(b, "inter");
               if(iv == null)
               {
                  continue;
               }
               var cont:Object = probe(iv, "cont");
               if(!(cont is String) || cont == "" || cont == "empty")
               {
                  continue;
               }
               iv["setAct"]("loot", 2);
               Log.d("RConnectGame: boxLootTest looted '"
                  + String(probe(b, "id")) + "' (cont was " + cont + ")");
               return;
            }
            Log.d("RConnectGame: boxLootTest: no container obj");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: boxLootTest failed: " + err);
         }
      }

      private var _terrain:TerrainSync = new TerrainSync();
      private var _presentation:UnitPresentation = new UnitPresentation();

      public function readTilePatch():Array {return _terrain.hostPatch(loc);}
      public function applyTilePatch(list:Array):void {_terrain.apply(loc,list,freezeAI);}
      public function scanTileReports():Object {return _terrain.report(loc);}
      public function finishTileReports():Array {return _terrain.finishReports(loc);}
      public function applyTileReport(peer:String,request:Object):Object {return _terrain.settle(loc,peer,request);}
      public function acknowledgeTiles(receipt:Object):void {_terrain.acknowledge(loc,receipt);}

      public function tileRedrawIfDirty():void
      {
         if(!_terrain.dirty || world==null) return;
         try {world["redrawLoc"]();_terrain.dirty=false;}
         catch(err:*) {logViewError("terrain-redraw",err);}
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
                  // M24：Loot 一律走稳定键同步（readLootSync/applyLootSync），
                  // 这里不再上报——否则坐标键与稳定键两套系统会对同一
                  // 物品双重生成
                  if(!isLoot && id != null && id.length > 0
                     && _objTpl[id] !== true)
                  {
                     out.push({id: id, cls: clsS,
                        x: numOr(probe(cur, "X"), 0),
                        y: numOr(probe(cur, "Y"), 0),
                        isLoot: false,
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

      // ================= M24：可移动物品（Loot）同步 =================
      // M17b 只镜像"Loot 的诞生"且键含坐标——物品被推动后键变化，joiner
      // 会重复生成并留下旧位置残影；宿主捡起后 joiner 的副本也永存。
      // M24 给 Loot 稳定身份 + 位置/移除镜像 + joiner 侧拾取/推动上报。

      private var _lootIdOf:Dictionary;    // 宿主：Loot 对象 → 稳定键 L#n
      private var _lootIdSeq:int = 0;
      private var _lootObjOf:Object = {};  // 键 → Loot 对象（双端）
      private var _lootKeyOfJ:Dictionary;  // joiner：Loot 对象 → 已认领键
      private var _lootPos:Object = {};    // joiner：键 → 宿主上次广播位置
      private var _lootRepT:Object = {};   // joiner：键 → 上次移动上报时刻
      private var _lootLoc:Object = null;  // 房间守卫（换房清空身份表）
      private var _lootMotion:Object = {};

      /** Visual/position interpolation only; never call Loot.take on a mirror. */
      private function tickLootMotion():void
      {
         for(var key:String in _lootMotion)
         {
            var target:Object = _lootMotion[key];
            var o:Object = target.o;
            if(probe(o,"loc") !== loc || probe(o,"in_chain") != true
               || boxHeldLocally(o) || probe(o,"vsos") == true)
            { delete _lootMotion[key]; continue; }
            try
            {
               var x:Number = Number(probe(o,"X"));
               var y:Number = Number(probe(o,"Y"));
               x += (Number(target.x)-x)*0.4;
               y += (Number(target.y)-y)*0.4;
               o["X"]=x; o["Y"]=y; o["dx"]=0; o["dy"]=0;
               var vis:Object=probe(o,"vis");
               if(vis!=null) { vis["x"]=x; vis["y"]=y; }
               _lootPos[key]={x:x,y:y};
            }
            catch(err:*) { delete _lootMotion[key]; }
         }
      }

      private function lootSyncReset():void
      {
         _lootIdOf = new Dictionary();
         _lootKeyOfJ = new Dictionary();
         _lootObjOf = {};
         _lootPos = {};
         _lootRepT = {};
         _lootIdSeq = 0;
         _lootMotion = {};
      }

      /** 沿 Pt 链枚举本房间全部 Loot。@return [obj, base] 数组 */
      private function lootWalk():Array
      {
         var out:Array = [];
         try
         {
            var cur:Object = probe(loc, "firstObj");
            var visited:Dictionary = new Dictionary();
            while(cur != null && visited[cur] != true)
            {
               visited[cur] = true;
               if(getQualifiedClassName(cur).indexOf("Loot") >= 0)
               {
                  out.push([cur, lootItemBase(cur)]);
               }
               cur = probe(cur, "nobj");
            }
         }
         catch(err:*)
         {
         }
         return out;
      }

      /** M24：宿主扫描本房间 Loot（稳定键 = 首见顺序，随 unitsync 广播）。 */
      public function readLootSync():Array
      {
         if(loc == null)
         {
            return null;
         }
         if(_lootLoc !== loc)
         {
            _lootLoc = loc;
            lootSyncReset();
         }
         var out:Array = [];
         try
         {
            var list:Array = lootWalk();
            if(list.length > 0 && !_lootScanLogged)
            {
               _lootScanLogged = true;
               Log.d("RConnectGame: loots scan first n=" + list.length
                  + " keying...");
            }
            for each(var e:Object in list)
            {
               var o:Object = e[0];
               var k:String = _lootIdOf[o];
               if(k == null)
               {
                  k = "L#" + (++_lootIdSeq);
                  _lootIdOf[o] = k;
                  _lootObjOf[k] = o;
               }
               var itemData:Object = probe(o, "item")["save"]();
               out.push({k: k, x: numOr(probe(o, "X"), 0),
                  y: numOr(probe(o, "Y"), 0), b: String(e[1]), item: itemData,
                  suction: probe(o, "vsos") == true});
            }
         }
         catch(err:*)
         {
            if(!_lootScanErrLogged)
            {
               _lootScanErrLogged = true;
               Log.d("RConnectGame: loots scan err: " + err);
            }
         }
         return out.length > 0 ? out : null;
      }

      private var _lootScanLogged:Boolean = false;
      private var _lootScanErrLogged:Boolean = false;

      /** M24：joiner 应用宿主 Loot 快照（认领/生成/移动/移除）。 */
      public function applyLootSync(list:Array):void
      {
         if(loc == null || list == null)
         {
            return;
         }
         if(_lootLoc !== loc)
         {
            _lootLoc = loc;
            lootSyncReset();
         }
         var spawned:int = 0;
         var claimed:int = 0;
         try
         {
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var seen:Object = {};
            for each(var s:Object in list)
            {
               var k:String = String(s.k);
               seen[k] = true;
               var lo:Object = _lootObjOf[k];
               if(lo == null)
               {
                  lo = claimLocalLoot(k, String(s.b),
                     Number(s.x), Number(s.y), s.item);
                  if(lo != null)
                  {
                     claimed++;
                  }
               }
               if(lo == null)
               {
                  lo = spawnLootByKey(ad, s);
                  if(lo != null)
                  {
                     spawned++;
                     Log.d("RConnectGame: loot spawn '" + k + "' base="
                        + String(s.b));
                  }
               }
               if(lo != null)
               {
                  if(s.suction == true && !boxHeldLocally(lo) && probe(lo,"vsos") != true)
                  {
                     _lootMotion[k]={o:lo,x:Number(s.x),y:Number(s.y)};
                     continue;
                  }
                  delete _lootMotion[k];
                  // 位置镜像：直接落位并清速度（防双端物理分叉），vis 由
                  // Loot.step 每帧自跟随。
                  // 本地偏差保护（与 M25 trackBoxPos 同理）：本地已偏离
                  // 宿主基线 >25px（本地推动/念力进行中）时不覆写不刷
                  // 基线，交给 scanLootReports 上报——否则 5Hz 旧快照会
                  // 把本地推动拽回吞掉
                  var baseP:Object = _lootPos[k];
                  var ldev:Number = baseP != null
                     ? (numOr(probe(lo, "X"), 0) - Number(baseP.x))
                        * (numOr(probe(lo, "X"), 0) - Number(baseP.x))
                        + (numOr(probe(lo, "Y"), 0) - Number(baseP.y))
                        * (numOr(probe(lo, "Y"), 0) - Number(baseP.y))
                     : 0;
                  if(ldev <= 625)
                  {
                     var oldP:Object = baseP;
                     if(oldP != null
                        && (Math.abs(Number(s.x) - Number(oldP.x)) > 2
                           || Math.abs(Number(s.y) - Number(oldP.y)) > 2)
                        && _lootMoveLogged[k] == undefined)
                     {
                        _lootMoveLogged[k] = true;
                        Log.d("RConnectGame: loot move '" + k + "' -> "
                           + Math.round(Number(s.x)) + ","
                           + Math.round(Number(s.y)));
                     }
                     lo["X"] = Number(s.x);
                     lo["Y"] = Number(s.y);
                     lo["dx"] = 0;
                     lo["dy"] = 0;
                     _lootPos[k] = {x: Number(s.x), y: Number(s.y)};
                  }
                  else
                  {
                     // 本地推动挂起：若宿主快照已与本地一致（上报已被
                     // 采纳），刷新基线防无限重报
                     var cvx:Number = numOr(probe(lo, "X"), 0) - Number(s.x);
                     var cvy:Number = numOr(probe(lo, "Y"), 0) - Number(s.y);
                     if(cvx * cvx + cvy * cvy <= 625)
                     {
                        _lootPos[k] = {x: numOr(probe(lo, "X"), 0),
                           y: numOr(probe(lo, "Y"), 0)};
                     }
                  }
               }
            }
            // 移除：宿主广播里已消失的键 = 宿主侧被拾取/清除
            // （TCP 可靠有序，缺席即真移除，无丢包抖动）
            for(var pk:String in _lootObjOf)
            {
               if(seen[pk] !== true)
               {
                  var gone:Object = _lootObjOf[pk];
                  try
                  {
                     loc["remObj"](gone);
                     Log.d("RConnectGame: loot removed '" + pk + "'");
                  }
                  catch(e2:*)
                  {
                  }
                  forgetLoot(pk, gone);
               }
            }
            if((spawned > 0 || claimed > 0) && !_lootSyncLogged)
            {
               _lootSyncLogged = true;
               Log.d("RConnectGame: loot sync first: spawned=" + spawned
                  + " claimed=" + claimed + " total=" + list.length);
            }
         }
         catch(err:*)
         {
         }
      }

      private var _lootSyncLogged:Boolean = false;
      private var _lootMoveLogged:Object = {};

      /** joiner 认领：同 base 且距宿主广播位置 <40px 的未标记本地 Loot。 */
      private function claimLocalLoot(k:String, base:String,
         hx:Number, hy:Number, itemData:Object = null):Object
      {
         var best:Object = null;
         var bestD:Number = 1600;
         try
         {
            var list:Array = lootWalk();
            for each(var e:Object in list)
            {
               var o:Object = e[0];
               if(_lootKeyOfJ[o] != undefined)
               {
                  continue;   // 已被其他键认领
               }
               if(String(e[1]) != base)
               {
                  continue;
               }
               var item:Object = probe(o, "item");
               if(itemData != null && (int(probe(item,"kol")) != int(itemData.kol)
                  || int(probe(item,"variant")) != int(itemData.variant)
                  || Number(probe(item,"sost")) != Number(itemData.sost))) continue;
               var dx:Number = numOr(probe(o, "X"), 0) - hx;
               var dy:Number = numOr(probe(o, "Y"), 0) - hy;
               if(dx * dx + dy * dy < bestD)
               {
                  bestD = dx * dx + dy * dy;
                  best = o;
               }
            }
         }
         catch(err:*)
         {
         }
         if(best != null) { _lootKeyOfJ[best] = k; _lootObjOf[k] = best; }
         return best;
      }

      /** M17b 构造路径复用：按广播条目生成 Loot 并登记键。 */
      private function spawnLootByKey(ad:Object, s:Object):Object
      {
         var res:Object = null;
         try
         {
            var lootCls:Object = ad["getDefinition"]("fe.loc.Loot");
            var shaped:Object = {itemBase: String(s.b), item: s.item,
               x: Number(s.x), y: Number(s.y)};
            var lo:Object = spawnLoot(ad, lootCls, shaped);
            if(lo != null)
            {
               _lootKeyOfJ[lo] = String(s.k);
               _lootObjOf[String(s.k)] = lo;
            }
            res = lo;
         }
         catch(err:*)
         {
            res = null;
         }
         return res;
      }

      private function forgetLoot(k:String, o:Object):void
      {
         delete _lootObjOf[k];
         delete _lootPos[k];
         delete _lootRepT[k];
         delete _lootMotion[k];
         if(_lootKeyOfJ != null)
         {
            delete _lootKeyOfJ[o];
         }
      }

      /** M24：joiner 周期扫描（1Hz）——本地拾取/推动上报宿主。 */
      public function scanLootReports():Object
      {
         var res:Object = null;
         if(loc == null || _lootLoc !== loc)
         {
            return null;
         }
         var picked:Array = [];
         var moved:Array = [];
         try
         {
            // 在链上的 Loot 集合（用于识别"未拾取但已不在链上"的清除）
            // 注意必须用 Dictionary——普通 Object 的键会被字符串化，
            // 所有对象撞成同一个键
            var live:Dictionary = new Dictionary();
            var list:Array = lootWalk();
            for each(var e:Object in list)
            {
               live[e[0]] = true;
            }
            var now:int = flash.utils.getTimer();
            for(var k:String in _lootObjOf)
            {
               var o:Object = _lootObjOf[k];
               var isTake:Boolean = (probe(o, "isTake") == true);
               var inChain:Boolean = (live[o] === true);
               if(isTake || !inChain)
               {
                  picked.push(k);
                  continue;
               }
               if(_lootMotion[k] != null && !boxHeldLocally(o) && probe(o,"vsos") != true) continue;
               var p:Object = _lootPos[k];
               if(p == null)
               {
                  continue;
               }
               var dx:Number = numOr(probe(o, "X"), 0) - Number(p.x);
               var dy:Number = numOr(probe(o, "Y"), 0) - Number(p.y);
               if(dx * dx + dy * dy > 625)
               {
                  if(now - numOr(_lootRepT[k], 0) > 200)
                  {
                     _lootRepT[k] = now;
                     moved.push({k: k, x: numOr(probe(o, "X"), 0),
                        y: numOr(probe(o, "Y"), 0)});
                  }
               }
            }
            if(picked.length > 0 || moved.length > 0)
            {
               res = {picked: picked, moved: moved};
            }
         }
         catch(err:*)
         {
         }
         return res;
      }

      /** M24：宿主应用 joiner 的拾取/推动上报（宿主仍是权威：落位即可）。 */
      public function applyLootReports(o:Object):void
      {
         if(o == null || loc == null || _lootLoc !== loc)
         {
            return;
         }
         try
         {
            var picked:Array = o.picked as Array;
            if(picked != null)
            {
               for each(var pk:Object in picked)
               {
                  var lo:Object = _lootObjOf[String(pk)];
                  if(lo != null)
                  {
                     loc["remObj"](lo);
                     Log.d("RConnectGame: loot pick applied '" + String(pk)
                        + "'");
                  }
                  forgetLoot(String(pk), lo);
               }
            }
            var moved:Array = o.moved as Array;
            if(moved != null)
            {
               for each(var m:Object in moved)
               {
                  var mo:Object = _lootObjOf[String(m.k)];
                  if(mo != null)
                  {
                     mo["X"] = Number(m.x);
                     mo["Y"] = Number(m.y);
                     mo["dx"] = 0;
                     mo["dy"] = 0;
                     Log.d("RConnectGame: loot push applied '" + String(m.k)
                        + "'");
                  }
               }
            }
         }
         catch(err:*)
         {
         }
      }

      /** M24 复现钩子（幂等）：房间无地面 Loot 则生成一件 kofe（M17b
       *  同款构造）。由 Session 在时间窗内每 tick 调用，自守卫。 */
      public function lootSpawnTest():void
      {
         if(loc == null)
         {
            return;
         }
         try
         {
            if(lootWalk().length > 0)
            {
               return;
            }
            var ad:Object = main["loaderInfo"]["applicationDomain"];
            var itCls:Object = ad["getDefinition"]("fe.serv.Item");
            var loCls:Object = ad["getDefinition"]("fe.loc.Loot");
            var item:Object = new (itCls as Class)(null, "kofe", 1);
            new (loCls as Class)(loc, item,
               Number(numOr(probe(gg, "X"), 0)) + 40,
               Number(numOr(probe(gg, "Y"), 0)), false, false, false);
            Log.d("RConnectGame: lootTest spawned 'kofe' (room empty)");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: lootSpawnTest failed: " + err);
         }
      }

      /** M24 复现钩子：推第一件 Loot——直接位移 60px（确定性位置变化，
       *  比速度更可靠：静止物品的 dx 会被摩擦/休眠逻辑吞掉）。 */
      public function lootPushTest():void
      {
         if(loc == null)
         {
            return;
         }
         try
         {
            var list:Array = lootWalk();
            if(list.length == 0)
            {
               return;
            }
            var o:Object = list[0][0];
            o["X"] = Number(numOr(probe(o, "X"), 0)) + 60;
            o["Y"] = Number(numOr(probe(o, "Y"), 0)) - 10;
            o["stay"] = false;
            Log.d("RConnectGame: lootTest pushed '"
               + String(list[0][1]) + "' @" + Math.round(numOr(probe(o,
               "X"), 0)) + "," + Math.round(numOr(probe(o, "Y"), 0)));
         }
         catch(err:*)
         {
            Log.d("RConnectGame: lootPushTest failed: " + err);
         }
      }

      /** M24 复现钩子：捡第一件 Loot（take(true)=强制拾取，走游戏原生
       *  remObj+入包）。房间没有就先现场生成。@return 是否已捡。 */
      public function lootTakeTest():Boolean
      {
         var res:Boolean = false;
         if(loc == null)
         {
            return false;
         }
         try
         {
            var list:Array = lootWalk();
            if(list.length == 0)
            {
               lootSpawnTest();
               res = false;
            }
            else
            {
               list[0][0]["take"](true);
               Log.d("RConnectGame: lootTest taken '"
                  + String(list[0][1]) + "'");
               res = true;
            }
         }
         catch(err:*)
         {
            Log.d("RConnectGame: lootTakeTest failed: " + err);
            res = false;
         }
         return res;
      }

      /** M24 复现钩子：joiner 强制拾取本地第一件 Loot（验证拾取上报→
       *  宿主移除链路）。 */
      public function lootTakeJoinTest():void
      {
         if(loc == null)
         {
            return;
         }
         try
         {
            var list:Array = lootWalk();
            if(list.length == 0)
            {
               Log.d("RConnectGame: lootTakeJoin: no loot in room");
               return;
            }
            list[0][0]["take"](true);
            Log.d("RConnectGame: lootTakeJoin taken '"
               + String(list[0][1]) + "'");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: lootTakeJoin failed: " + err);
         }
      }

      /** M25 复现钩子：把第一个可移动 Box（door<=0 且 wall==0）位移 60px
       *  （确定性位置变化，宿主/joiner 两侧通用——验证双向位置同步）。 */
      public function boxMoveTest():Boolean
      {
         if(loc == null)
         {
            return false;
         }
         try
         {
            var objs:Object = probe(loc, "objs");
            for each(var b:Object in objs as Array)
            {
               if(numOr(probe(b, "door"), 0) > 0
                  || numOr(probe(b, "wall"), 0) > 0
                  || probe(b, "dead") == true)
               {
                  continue;
               }
               b["X"] = numOr(probe(b, "X"), 0) + 60;
               b["Y"] = numOr(probe(b, "Y"), 0) - 10;
               b["runVis"]();
               Log.d("RConnectGame: boxMoveTest moved '" + String(probe(b,
                  "id")) + "' -> " + Math.round(numOr(probe(b, "X"), 0))
                  + "," + Math.round(numOr(probe(b, "Y"), 0)));
               return true;
            }
            Log.d("RConnectGame: boxMoveTest: no movable box");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: boxMoveTest failed: " + err);
         }
         return false;
      }

      /** M25 复现钩子：joiner 开第一个非 autoClose 活门（真实使用路径，
       *  验证 ist 上报→宿主应用→广播回流收敛）。 */
      public function doorJoinTest():void
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
            for each(var b:Object in objs as Array)
            {
               if(probe(b, "dead") == true || numOr(probe(b, "door"), 0) <= 0)
               {
                  continue;
               }
               var iv:Object = probe(b, "inter");
               if(iv == null || numOr(probe(iv, "autoClose"), 0) > 0)
               {
                  continue;
               }
               iv["command"]("open");
               Log.d("RConnectGame: doorJoinTest open '" + String(probe(b,
                  "id")) + "' tilePhis=" + firstDoorTilePhis(b));
               return;
            }
            Log.d("RConnectGame: doorJoinTest: no door obj");
         }
         catch(err:*)
         {
            Log.d("RConnectGame: doorJoinTest failed: " + err);
         }
      }

      // ================= M25：可移动 Box（念力物品）+ ist 双向 =================
      // M16 只同步 Box 的 dead/hp/ist 状态，位置不动——念力（telekinesis）
      // 移动的箱子在对端原地不动。M25 补位置镜像（宿主→joiner，随 objs
      // 快照）+ 移动/交互上报（joiner→宿主，宿主权威落位后经快照回流）。

      private var _boxTrack:Dictionary = new Dictionary();
      private var _boxTrackLoc:Object = null;
      // M25：ist 扫描期望/稳定性按对象实例跟踪（同 id 多实例实测会互殴）
      private var _istExpectO:Dictionary = new Dictionary();

      private function boxTrackReset():void
      {
         _boxTrack = new Dictionary();
      }

      /** 同 id 就近匹配（未消费的里挑离 (x,y) 最近者，150px 内才算）。
       *  含门/墙对象（ist 上报路径用；可移动物路径用 matchBoxById）。 */
      private function matchObjByIdPos(id:String, x:Number, y:Number,
         consumed:Dictionary):Object
      {
         var best:Object = null;
         var bestD:Number = 22500;   // 150²
         try
         {
            var objs:Object = probe(loc, "objs");
            for each(var b:Object in objs as Array)
            {
               if(consumed[b] === true
                  || String(probe(b, "id")) != id)
               {
                  continue;
               }
               var dx:Number = numOr(probe(b, "X"), 0) - x;
               var dy:Number = numOr(probe(b, "Y"), 0) - y;
               var d2:Number = dx * dx + dy * dy;
               if(d2 < bestD)
               {
                  bestD = d2;
                  best = b;
               }
            }
         }
         catch(err:*)
         {
         }
         return best;
      }

      /** 本地正被念力托举？（levit/fracLevit 由施法侧设置） */
      private function boxHeldLocally(b:Object):Boolean
      {
         return numOr(probe(b, "levit"), 0) != 0
            || numOr(probe(b, "fracLevit"), 0) > 0;
      }

      /** 同 id 就近匹配（未消费的里挑离 (x,y) 最近者，150px 内才算）。 */
      private function matchBoxById(id:String, x:Number, y:Number,
         consumed:Dictionary):Object
      {
         var best:Object = null;
         var bestD:Number = 22500;   // 150²
         try
         {
            var objs:Object = probe(loc, "objs");
            for each(var b:Object in objs as Array)
            {
               if(consumed[b] === true
                  || numOr(probe(b, "door"), 0) > 0
                  || numOr(probe(b, "wall"), 0) > 0)
               {
                  continue;
               }
               if(String(probe(b, "id")) != id)
               {
                  continue;
               }
               var dx:Number = numOr(probe(b, "X"), 0) - x;
               var dy:Number = numOr(probe(b, "Y"), 0) - y;
               var d2:Number = dx * dx + dy * dy;
               if(d2 < bestD)
               {
                  bestD = d2;
                  best = b;
               }
            }
         }
         catch(err:*)
         {
         }
         if(best != null)
         {
            consumed[best] = true;
         }
         return best;
      }

      /** M26：坐标落点校验——目标瓦片在 loc.space 内存在才允许注入/镜像
       *  落位。非确定性生成图（其他模组的随机房）两侧房间几何不同，宿主
       *  坐标可能落在加入方的房外/空行 → Unit.run() 读 space 越界 #1010
       *  （rr_showroom 实测崩溃）。@return 就近有效坐标或 null。 */
      private function validLandPos(x:Number, y:Number):Object
      {
         try
         {
            var sx:int = numOr(probe(loc, "spaceX"), 0);
            var sy:int = numOr(probe(loc, "spaceY"), 0);
            var space:Object = probe(loc, "space");
            if(sx <= 0 || sy <= 0 || space == null)
            {
               return null;
            }
            var tx:int = int(x / 40);
            var ty:int = int(y / 40);
            // 40px 网格内螺旋找有效瓦片（±24 格）
            for(var r:int = 0; r <= 24; r++)
            {
               for(var ox:int = -r; ox <= r; ox++)
               {
                  for(var oy:int = -r; oy <= r; oy++)
                  {
                     if(Math.abs(ox) != r && Math.abs(oy) != r)
                     {
                        continue;   // 只搜环边
                     }
                     var cx:int = tx + ox;
                     var cy:int = ty + oy;
                     if(cx < 0 || cx >= sx || cy < 0 || cy >= sy)
                     {
                        continue;
                     }
                     var row:Object = (space as Array)[cx];
                     if(row is Array && (row as Array)[cy] != null)
                     {
                        return r == 0 ? {x:x, y:y} : {x:cx * 40 + 20, y:cy * 40 + 20};
                     }
                  }
               }
            }
         }
         catch(err:*)
         {
         }
         return null;
      }

      private var _doorInvLoc:Object = null;
      private var _doorInvLogged:Boolean = false;

      /** M26 诊断（宿主，每房一次）：房间门清单 id:autoClose:open——
       *  用户报"宿主开门不同步"时对号入座（autoClose 门设计上不同步）。 */
      public function logDoorInventory():void
      {
         if(loc == null)
         {
            return;
         }
         if(_doorInvLoc !== loc)
         {
            _doorInvLoc = loc;
            _doorInvLogged = false;
         }
         if(_doorInvLogged)
         {
            return;
         }
         _doorInvLogged = true;
         try
         {
            var objs:Object = probe(loc, "objs");
            var parts:Array = [];
            for each(var b:Object in objs as Array)
            {
               if(numOr(probe(b, "door"), 0) <= 0)
               {
                  continue;
               }
               var iv:Object = probe(b, "inter");
               parts.push(String(probe(b, "id")) + ":ac="
                  + (iv != null ? String(numOr(probe(iv, "autoClose"), 0))
                     : "?")
                  + ",o=" + (iv != null && probe(iv, "open") == true
                     ? "1" : "0"));
            }
            Log.d("RConnectGame: doors in room: "
               + (parts.length > 0 ? parts.join(" | ") : "(none)"));
         }
         catch(err:*)
         {
         }
      }

      private var _unitVisLoc:Object = null;
      private var _unitVisLogged:Boolean = false;

      /** M26 诊断（joiner，每房一次）：本地单位可见性采样——
       *  v=有vis层，p=vis挂显示树，s=vis.visible（RV 视距会把不在本地
       *  玩家视线内的敌人整个隐藏），m=被遮罩。用户报"敌人不显示"时
       *  区分：我们丢了渲染 vs RV 隐藏。 */
      public function logUnitVisibility():void
      {
         if(loc == null)
         {
            return;
         }
         if(_unitVisLoc !== loc)
         {
            _unitVisLoc = loc;
            _unitVisLogged = false;
         }
         if(_unitVisLogged)
         {
            return;
         }
         _unitVisLogged = true;
         try
         {
            var units:Object = probe(loc, "units");
            var parts:Array = [];
            var n:int = 0;
            var myX:Number = gg != null ? numOr(probe(gg, "X"), 0) : 0;
            var myY:Number = gg != null ? numOr(probe(gg, "Y"), 0) : 0;
            for each(var u:Object in units as Array)
            {
               if(u == gg || n >= 12)
               {
                  continue;
               }
               var uid:String = String(probe(u, "id"));
               if(uid.indexOf("rconnect_ghost") == 0)
               {
                  continue;
               }
               var vis:Object = probe(u, "vis");
               var ddx:Number = numOr(probe(u, "X"), 0) - myX;
               var ddy:Number = numOr(probe(u, "Y"), 0) - myY;
               parts.push(uid + "@d" + Math.round(Math.sqrt(ddx * ddx
                  + ddy * ddy)) + " v=" + (vis != null ? 1 : 0)
                  + " p=" + (vis != null && probe(vis, "parent") != null ? 1
                     : 0)
                  + " s=" + (vis != null && probe(vis, "visible") == true ? 1
                     : 0)
                  + " m=" + (vis != null && probe(vis, "mask") != null ? 1
                     : 0) + " a=" + numOr(probe(vis,"alpha"),-1)
                  + " hidden=" + (probe(u,"invis")==true ? 1:0)
                  + " isVis=" + (probe(u,"isVis")==false ? 0:1));
               n++;
            }
            Log.d("RConnectGame: unit vis sample: "
               + (parts.length > 0 ? parts.join(" ; ") : "(none)"));
         }
         catch(err:*)
         {
         }
      }

      /** 落位到宿主/对端报告的位置——M26 平滑插值：不硬跳，设 tween 目标
       *  由 tickBoxTweens 每 50ms 渐进（25%/tick），念力搬运观感平滑。
       *  本地偏差保护（force=false 的镜像路径）：本地已偏离基线 >25px
       *  （本地念力/推挤进行中）时不覆写也不刷新基线——否则宿主旧快照
       *  会把本地移动拽回、上报通道永远发不出。force=true 强制收目标。 */
      private function trackBoxPos(b:Object, x:Number, y:Number,
         held:Boolean, force:Boolean = false):void
      {
         try
         {
            var rec:Object = _boxTrack[b];
            var tween:Object = _boxTween[b];
            if(rec != null && !force && tween == null)
            {
               var ldx:Number = numOr(probe(b, "X"), 0) - Number(rec.x);
               var ldy:Number = numOr(probe(b, "Y"), 0) - Number(rec.y);
               if(ldx * ldx + ldy * ldy > 625)
               {
                  // 本地移动挂起：不覆写。但若宿主快照已与本地一致
                  // （上报已被采纳），刷新基线消除偏差，防无限重报
                  var hx:Number = numOr(probe(b, "X"), 0) - x;
                  var hy:Number = numOr(probe(b, "Y"), 0) - y;
                  if(hx * hx + hy * hy <= 625)
                  {
                     rec.x = x;
                     rec.y = y;
                  }
                  return;
               }
            }
            var bx:Number = numOr(probe(b, "X"), 0);
            var by:Number = numOr(probe(b, "Y"), 0);
            if(held || Math.abs(bx - x) >= 2 || Math.abs(by - y) >= 2)
            {
               // M26：设 tween 目标（平滑逼近），不直接写坐标
               _boxTween[b] = {tx: x, ty: y, q: held};
               if(!_boxMoveLogged[b])
               {
                  _boxMoveLogged[b] = true;
                  Log.d("RConnectGame: box pos synced '" + String(probe(b,
                     "id")) + "' -> " + Math.round(x) + "," + Math.round(y));
               }
            }
            else if(tween != null)
            {
               // 目标回到当前位：取消挂起的 tween（防漂移）
               delete _boxTween[b];
               if(tween.q == true) b["stay"] = false;
            }
            if(rec == null)
            {
               _boxTrack[b] = {x: bx, y: by, q: held, lastR: 0};
            }
            else
            {
               rec.x = x;
               rec.y = y;
               rec.q = held;
            }
         }
         catch(err:*)
         {
         }
      }

      /** M26：Box 平滑插值驱动（Session 每 50ms tick 调用）——每步向
       *  tween 目标逼近 25%，到位即停；托举态保持抗重力。 */
      public function tickBoxTweens():void
      {
         if(_boxTween == null)
         {
            return;
         }
         try
         {
            for(var b:Object in _boxTween)
            {
               var tw:Object = _boxTween[b];
               if(probe(b, "loc") !== loc || probe(b, "dead") == true || boxHeldLocally(b))
               { delete _boxTween[b]; continue; }
               var x:Number = numOr(probe(b, "X"), 0);
               var y:Number = numOr(probe(b, "Y"), 0);
               var dx:Number = Number(tw.tx) - x;
               var dy:Number = Number(tw.ty) - y;
               if(dx * dx + dy * dy <= 1)
               {
                  if(tw.q == true) { b["stay"] = true; b["dx"] = 0; b["dy"] = 0; }
                  else delete _boxTween[b];
                  continue;
               }
               var nx:Number = x + dx * 0.25;
               var ny:Number = y + dy * 0.25;
               var scX:Number = numOr(probe(b, "scX"), 20);
               var scY:Number = numOr(probe(b, "scY"), 20);
               b["X"] = nx;
               b["Y"] = ny;
               b["X1"] = nx - scX / 2;
               b["X2"] = nx + scX / 2;
               b["Y1"] = ny - scY;
               b["Y2"] = ny;
               b["dx"] = 0;
               b["dy"] = 0;
               if(tw.q == true)
               {
                  b["stay"] = true;
               }
               b["runVis"]();
               var baseline:Object = _boxTrack[b];
               if(baseline != null) { baseline.x = nx; baseline.y = ny; }
            }
         }
         catch(err:*)
         {
         }
      }

      private var _boxTween:Dictionary = new Dictionary();

      private var _boxMoveLogged:Dictionary = new Dictionary();
      private var _objScanErrLogged:Boolean = false;

      /** joiner 每约200ms扫描——本地 Box 移动（念力/推挤）与
       *  ist 变化（开关门/开锁/搜刮）上报宿主。@return 上报对象或 null。 */
      public function scanObjReports():Object
      {
         if(loc == null)
         {
            return null;
         }
         if(_boxTrackLoc !== loc)
         {
            _boxTrackLoc = loc;
            boxTrackReset();
            _istExpectO = new Dictionary();
            _istPending = new Dictionary();
         }
         var moved:Array = [];
         var ist:Array = [];
         try
         {
            var now:int = flash.utils.getTimer();
            // 1) Box 位移：偏离宿主快照基线 >25px 即本地被移动（念力）
            for(var b:Object in _boxTrack)
            {
               var rec:Object = _boxTrack[b];
               var dx:Number = numOr(probe(b, "X"), 0) - Number(rec.x);
               var dy:Number = numOr(probe(b, "Y"), 0) - Number(rec.y);
               if((_boxTween[b] == null || boxHeldLocally(b)) && dx * dx + dy * dy > 625
                  && now - numOr(rec.lastR, 0) > 200)
               {
                  rec.lastR = now;
                  moved.push({id: String(probe(b, "id")), k: _objects.known(b),
                     x: numOr(probe(b, "X"), 0),
                     y: numOr(probe(b, "Y"), 0),
                     q: boxHeldLocally(b)});
               }
            }
            // Send local intent on the first scan; repeat until echoed. Automatic
            // doors are excluded explicitly rather than delaying normal interactions.
            var objs:Object = probe(loc, "objs");
            for each(var o:Object in objs as Array)
            {
               captureInteractionIntent(o);
               if(_istPending[o]!=null)ist.push(_istPending[o]);
            }
         }
         catch(err:*)
         {
            if(!_objScanErrLogged)
            {
               _objScanErrLogged = true;
               Log.d("RConnectGame: obj scan err: " + err
                  + (err is Error && (err as Error).getStackTrace() != null
                     ? " | " + String((err as Error).getStackTrace()).split(
                        "\n").slice(0, 3).join(" <= ") : ""));
            }
         }
         var scene:Array = scanSceneReports();
         if(moved.length == 0 && ist.length == 0 && scene.length == 0)
         {
            return null;
         }
         return {moved: moved, ist: ist, scene: scene};
      }

      /** M25：宿主应用 joiner 上报（Box 位移就近落位；ist 经 setAct 官方
       *  路径 + ever-seen 标记使其随快照重播，两端收敛）。 */
      public function applyObjReports(o:Object):void
      {
         if(o == null || loc == null)
         {
            return;
         }
         try
         {
            _objects.enter(loc);
            for each(var scene:Object in o.scene as Array)
            {
               var sceneObj:Object = _objects.resolve(scene, probe(loc, "objs") as Array, new Dictionary());
               if(sceneObj != null) applySceneState(sceneObj, scene);
            }
            var moved:Array = o.moved as Array;
            if(moved != null)
            {
               for each(var m:Object in moved)
               {
                  var mb:Object = _objects.resolve(m, probe(loc, "objs") as Array, new Dictionary());
                  if(mb != null)
                  {
                     trackBoxPos(mb, Number(m.x), Number(m.y),
                        m.q == true, true);
                     Log.d("RConnectGame: box move applied '" + String(m.id)
                        + "'");
                  }
               }
            }
            var istl:Array = o.ist as Array;
            if(istl != null)
            {
               var used:Dictionary = new Dictionary();
               for each(var is2:Object in istl)
               {
                  // id+就近匹配到正确实例（同 id 多箱；含门/墙对象）
                  var target:Object = _objects.resolve(is2, probe(loc, "objs") as Array, used);
                  if(target == null)
                  {
                     continue;
                  }
                  used[target] = true;
                  var iv:Object = probe(target, "inter");
                  if(iv == null)
                  {
                     continue;
                  }
                  var seen:Object = _istSeen[target];
                  if(seen == null)
                  {
                     seen = {open: false, lock: false, mine: false,
                        loot: false, expl: false};
                     _istSeen[target] = seen;
                  }
                  if(is2.o != undefined)
                  {
                     if((probe(iv,"open")==true?1:0)!=int(is2.o))iv["setAct"]("open", int(is2.o));
                     seen.open = true;
                  }
                  if(is2.l != undefined && int(is2.o) != 1)
                  {
                     if(int(probe(iv,"lock"))!=int(is2.l))iv["setAct"]("lock", numOr(is2.l, 0));
                     seen.lock = true;
                  }
                  if(is2.t != undefined && numOr(is2.t, 0) > 0)
                  {
                     var saved:Object={};iv["save"](saved);
                     if(numOr(saved.loot,0)<=0)iv["setAct"]("loot", 2);
                     seen.loot = true;
                  }
                  Log.d("RConnectGame: ist report applied '" + String(is2.id)
                     + "' o=" + String(is2.o) + " l=" + String(is2.l)
                     + " t=" + String(is2.t));
               }
            }
         }
         catch(err:*)
         {
         }
      }

      private function lootItemBase(o:Object):String
      {
         try
         {
            var it:Object = probe(o, "item");
            if(it == null)
            {
               return "";
            }
            // M24：Item 构造器把 param2 赋给 id 而非 base（base 字段另有
            // 来源，实测 hook 生成的物品 base 恒为空）——身份键优先取 id
            var id:String = String(probe(it, "id"));
            if(id != null && id.length > 0)
            {
               return id;
            }
            return String(probe(it, "base"));
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
               // Box creation belongs exclusively to the keyed scene channel.
               if(String(s.cls) == "fe.loc::Box") continue;
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

      /** M17：按宿主广播生成 Loot（Item 按 base 构造）。@return Loot 对象
       *  或 null（M24：返回对象供键登记；applyObjSpawn 的真值判断兼容）。 */
      private function spawnLoot(ad:Object, lootCls:Object, s:Object):Object
      {
         try
         {
            var itCls:Object = ad["getDefinition"]("fe.serv.Item");
            var base:String = s.itemBase != undefined ? String(s.itemBase) : "";
            if(base == "")
            {
               return null;
            }
            var data:Object = s.item;
            var item:Object = data == null ? new (itCls as Class)(null, base, 1)
               : new (itCls as Class)(String(data.tip), base, int(data.kol), int(data.sost));
            if(data != null)
            {
               item["variant"] = int(data.variant);
               item["lvl"] = int(data.lvl);
               item["barter"] = data.barter;
               item["trig"] = data.trig;
            }
            var lo:Object = new (lootCls as Class)(loc, item, Number(s.x),
               Number(s.y), false, false, false);
            return lo;
         }
         catch(err:*)
         {
            Log.d("RConnectGame: spawnLoot failed: " + err);
            return null;
         }
         // mxmlc 控制流怪癖
         return null;
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

      /** Host perception: native findCel only discovers loc.gg on its own.
       *  Offer a nearby visible remote player even when celUnit still names a
       *  distant host. Keep a closer target to avoid rapid target oscillation. */
      public function redirectNearbyAggro():void
      {
         if(loc == null)
         {
            return;
         }
         var units:Object = probe(loc, "units");
         if(!(units is Array))
         {
            return;
         }
         var n:int = 0;
         try
         {
            for(var k:String in _remotes)
            {
               var ghost:Object = _remotes[k].ghost;
               if(ghost == null || _ghostPassive[k] || numOr(probe(ghost, "hp"), 0) <= 0)
               {
                  continue;
               }
               var gx:Number = numOr(probe(ghost, "X"), 0);
               var gy:Number = numOr(probe(ghost, "Y"), 0);
               for each(var u:Object in units as Array)
               {
                  if(n >= 4)
                  {
                     return;
                  }
                  var frac:Number = numOr(probe(u, "fraction"), 0);
                  if(frac < 1 || frac >= 100
                     || probe(u,"disabled") == true || isTrigger(u)
                     || numOr(probe(u, "sost"), 1) >= 2
                     || numOr(probe(u, "hp"), 0) <= 0)
                  {
                     continue;
                  }
                  var dx:Number = numOr(probe(u, "X"), 0) - gx;
                  var dy:Number = numOr(probe(u, "Y"), 0) - gy;
                  var distance:Number = dx * dx + dy * dy;
                  if(distance > 320 * 320)
                  {
                     continue;
                  }
                  // Use the game's cone, wall and stealth checks, not distance alone.
                  if(!u["isMeet"](ghost) || Number(u["look"](ghost,probe(u,"overLook") == true)) <= 0.5)
                     continue;
                  var current:Object = probe(u,"celUnit");
                  if(current == null) current = probe(u,"priorUnit");
                  if(current === ghost) continue;
                  if(current != null && u["isMeet"](current)
                     && numOr(probe(current,"sost"),3) < 3 && numOr(probe(current,"hp"),0) > 0)
                  {
                     var cx:Number = Number(probe(current,"X")) - Number(probe(u,"X"));
                     var cy:Number = Number(probe(current,"Y")) - Number(probe(u,"Y"));
                     if(distance >= (cx*cx+cy*cy)*0.64) continue;
                  }
                  u["priorUnit"] = ghost;
                  u["setCel"](ghost);
                  n++;
               }
            }
         }
         catch(err:*)
         {
         }
      }

      /** M21：单个远程玩家摘要（面板用）：姿态/护甲。 */
      public function remoteBrief(id:int):String
      {
         var rec:Object = _remotes[id];
         if(rec == null)
         {
            return "?";
         }
         var ghost:Object = rec.ghost;
         var pose:String = "?";
         if(ghost != null)
         {
            var vis:Object = probe(ghost, "vis");
            var osn:Object = vis != null ? probe(vis, "osn") : null;
            pose = osn != null ? String(probe(osn, "currentLabel")) : "?";
         }
         var ak:String = _apKey[id] != null ? String(_apKey[id]) : "";
         var armor:String = ak.split("|")[0];
         if(armor == null || armor == "")
         {
            armor = "?";
         }
         return "pose=" + pose + " armor=" + armor;
      }

      /** M21：会话摘要（每 60s 一行，供复测粘贴）。 */
      public function sessionReport():String
      {
         var wi:Object = readWorldInfo();
         var r:String = "land=" + (wi != null ? String(wi.curLandId) : "?")
            + "/" + (wi != null ? String(wi.locId) : "?")
            + " stage=" + (wi != null ? String(wi.landStage) : "?")
            + " localPose=" + localPoseLabel();
         var n:int = 0;
         for(var k:String in _remotes)
         {
            n++;
            r += " ghost" + k + "[" + remoteBrief(int(k)) + "]";
         }
         var objs:Object = probe(loc, "objs");
         var units:Object = probe(loc, "units");
         var ifail:int = 0;
         for(var f:String in _injectFailed)
         {
            ifail++;
         }
         r += " objs=" + (objs is Array ? String((objs as Array).length) : "?")
            + " units=" + (units is Array ? String((units as Array).length) : "?")
            + " injectFail=" + ifail;
         return r;
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
               world["newGame"](-1, "LP", null);
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

      /** M19：单位视觉帧（小马类 = vis.osn.pon.currentFrame，即配色/皮肤）。
       *  非小马（blit 等）无 osn.pon → -1（外观由类/XML 决定，天然一致）。 */
      private function unitVisualFrame(u:Object):Number
      {
         try
         {
            var vis:Object = probe(u, "vis");
            var osn:Object = vis != null ? probe(vis, "osn") : null;
            var pon:Object = osn != null ? probe(osn, "pon") : null;
            return pon != null ? int(probe(pon, "currentFrame")) : -1;
         }
         catch(err:*)
         {
            return -1;
         }
         return -1;
      }

      /** M19：把宿主单位的视觉帧/瞄准点应用到本地单位（镜像+傀儡）。
       *  @return 是否应用了外观帧（验证用）。 */
      public function applyUnitAppearance(u:Object, vf:Number, cx:Number,
         cy:Number):Boolean
      {
         var styled:Boolean = false;
         if(vf >= 1)
         {
            try
            {
               var vis:Object = probe(u, "vis");
               var osn:Object = vis != null ? probe(vis, "osn") : null;
               var pon:Object = osn != null ? probe(osn, "pon") : null;
               if(pon != null && int(probe(pon, "currentFrame")) != int(vf))
               {
                  pon["gotoAndStop"](int(vf));
                  styled = true;
               }
            }
            catch(err:*)
            {
            }
         }
         if(cx >= 0 && cy >= 0)
         {
            try
            {
               u["celX"] = cx;
               u["celY"] = cy;
            }
            catch(err:*)
            {
            }
         }
         return styled;
      }

      /** Box.bindUnit receivers belong to scene objects. They have no visual or
       * native step-chain membership and must never be rebuilt as enemies. */
      private static function isSceneHitUnit(unit:Object):Boolean
      {
         return getQualifiedClassName(unit)=="fe.unit::VirtualUnit";
      }

      /** M19：采集本世界单位快照（M4：宿主广播，客户端镜像）。 */
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
         _units.enter(loc);
         var out:Array = [];
         try
         {
            for each(var u:Object in units as Array)
            {
               if(u == gg || u is MirrorHitUnit || isSceneHitUnit(u) || numOr(probe(u,"fraction"),0) >= 100)
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
                  k: _units.key(u),
                  cls: getQualifiedClassName(u),
                  tr: numOr(probe(u, "tr"), 0),
                  x: numOr(probe(u, "X"), 0),
                  y: numOr(probe(u, "Y"), 0),
                  storona: numOr(probe(u, "storona"), 1),
                  sost: numOr(probe(u, "sost"), 1),
                  hp: numOr(probe(u, "hp"), -1),
                  fraction: numOr(probe(u, "fraction"), 0),
                  anim: String(probe(u, "animState")),
                  pose: RConnectAnimationAccess.capture(u as Unit),
                  motion: unitFields(u, ["dx","dy","stay","isFly","isLaz","levit","scX","scY"]),
                  // Mechanical visibility, never the local RV/FOV visible flag.
                  view: unitView(u),
                  body: TurretDisplay.capture(u),
                  weapons: _presentation.capture(u),
                  defense: unitFields(u, MirrorHitUnit.DEFENSE),
                  // M19：外观帧（小马类 osn.pon 帧=配色/皮肤）与瞄准点
                  // （celX/celY=敌人当前目标方向，仇恨可视化一致）
                  vf: unitVisualFrame(u),
                  cx: numOr(probe(u, "celX"), -1),
                  cy: numOr(probe(u, "celY"), -1)
               });
               // M19 诊断：房间是否存在小马类敌人（vf>=1）
               var vfN:Number = unitVisualFrame(u);
               if(vfN >= 1 && !_ponySeen)
               {
                  _ponySeen = true;
                  Log.d("RConnectGame: pony enemy '" + uid
                     + "' vf=" + vfN);
               }
            }
         }
         catch(err:*)
         {
         }
         return out;
      }

      /**
       * 镜像宿主单位快照；独立实例键贯穿位置、动画、血量和伤害回报。
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
         _applyingUnits=true;
         try {
         // M27：每轮重建强制显示集（宿主每轮广播完整单位表；死亡
         // sost>=3 与游戏隐身 invis 不强制——尸体与潜行语义留给游戏）
         var previouslyAlive:Dictionary = _hostAlive;
         _hostAlive = new Dictionary();
         _mirroring = true;
         _units.enter(loc);
         var used:Dictionary = new Dictionary();
         for each(var e:Object in list)
         {
            var eid:String = String(e.id);
            var target:Object = _units.resolve(e, units as Array, used);
            if(target == null)
            {
               continue;
            }
            try
            {
               captureUnitDamage(target);
               target["storona"] = Number(e.storona) >= 0 ? 1 : -1;
               // M26：镜像落点校验（同注入防护）——生成图两侧几何不同时
               // 拒绝越界 setPos，保命优先于位置精度（就近吸附会瞬移）
               if(validLandPos(Number(e.x), Number(e.y)) == null)
               {
                  if(!_posSkipLogged[eid])
                  {
                     _posSkipLogged[eid] = true;
                     Log.d("RConnectGame: pos mirror skip '" + eid
                        + "' (host pos outside local room)");
                  }
               }
               else
               {
                  var safe:Object = validLandPos(Number(e.x), Number(e.y));
                  queueUnitMotion(target, Number(safe.x), Number(safe.y));
               }
               if(e.sost != undefined && Number(e.sost) != -1)
               {
                  target["sost"] = int(e.sost);
               }
               if(e.hp != undefined && Number(e.hp) != -1)
               {
                  target["hp"] = Number(e.hp);
                  _baseHp[target] = Number(e.hp);
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
               applyUnitFields(target, e.motion);
               // Burrowed native ghoul instances have scY=0. Restore the host's
               // collision shape before creating/updating the bullet receiver.
               target["setPos"](target.X,target.Y);
               // Older/test snapshots may provide movement directly.
               applyUnitFields(target, unitFields(e, ["dx","dy","stay","isFly","isLaz","levit"]));
               applyUnitFields(target, e.defense);
               if(e.view!=null)
               {
                  if(_unitView[target]==null) _unitView[target]={original:unitView(target),host:e.view};
                  else _unitView[target].host=e.view;
                  applyUnitView(target,e.view);
               }
               _baseDefense[target] = {armor:numOr(probe(target,"armor_hp"),0),
                  shield:numOr(probe(target,"shithp"),0)};
               target["setVisPos"]();
               // Freeze native AI. disabled also excludes bullets, so MirrorHitUnit handles collision.
               // M8：每轮同步都重写——UnitNPC 会自我解除 disabled（实测 vendor
               // disabled=false 后 hp 漂移产生幻影伤害上报）
               if(freezeAI && target != gg)
               {
                  if(_freezeOriginal[target] === undefined)
                     _freezeOriginal[target] = probe(target, "disabled") == true;
                  target["disabled"] = true;
                  _frozen[target] = true;
               }
               // M6a：应用宿主姿态状态（公开 animState 字段）
               if(e.anim != undefined && e.anim != null)
               {
                  var wantAnim:String = String(e.anim);
                  var curAnim:String = String(probe(target, "animState"));
                  if(curAnim != wantAnim)
                  {
                     if(e.pose==null)target["animState"] = wantAnim;
                     if(!_animLogged[eid])
                     {
                        _animLogged[eid] = true;
                        Log.d("RConnectGame: puppet anim '" + eid
                           + "' -> " + wantAnim);
                     }
                  }
               }
               // M19：敌人外观帧/瞄准点（皮肤一致 + 仇恨朝向一致）
               applyUnitAppearance(target, numOr(e.vf, -1),
                  numOr(e.cx, -1), numOr(e.cy, -1));
               if(numOr(e.vf, -1) >= 1 && !_skinSeen)
               {
                  _skinSeen = true;
                  Log.d("RConnectGame: enemy skin '" + eid
                     + "' hostVf=" + String(e.vf)
                     + " localPon=" + String(unitVisualFrame(target)));
               }
               // M27：存活镜像单位进强制显示集（onVisForceFrame 每帧
               // 恢复被 RV 视距隐藏的 vis——"队友报点"语义）
               if(numOr(e.sost, 1) < 3 && unitCanShow(target))
               {
                  _hostAlive[target] = true;
               }
               if(freezeAI) _presentation.apply(target,e,main);
               var hit:MirrorHitUnit = _hitUnits[target];
               if(freezeAI && numOr(e.fraction,0)>0 && numOr(e.fraction,0)<100
                  && numOr(e.sost,1)<3 && !isTrigger(target))
               {
                  if(hit == null)
                  {
                     hit = new MirrorHitUnit(target);
                     _hitUnits[target] = hit;
                     (units as Array).push(hit);
                  }
                  hit.sync();
               }
               else if(hit != null) removeHitUnit(target);
               res.matched++;
            }
            catch(err:*)
            {
            }
         }
         for(var old:Object in previouslyAlive)
            if(_hostAlive[old] != true)
            {
               restoreMirrorMask(probe(old,"vis"));
            }
         for(old in _hitUnits)
            if(used[old] != true) removeHitUnit(old);
         for(old in _unitView)
            if(used[old] != true)
            {
               try {applyUnitView(old,_unitView[old].original);} catch(viewError:*) {}
               delete _unitView[old];
            }
         } finally {_applyingUnits=false;}
         return res;
      }
      private var _applyingUnits:Boolean=false;

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
         for each(var u:Object in units as Array) captureUnitDamage(u);
         var out:Array = [];
         for(var target:Object in _pendingHits) out.push(_pendingHits[target]);
         _pendingHits = new Dictionary();
         return out;
      }

      private var _baseDefense:Dictionary = new Dictionary();

      private function captureUnitDamage(u:Object):void
      {
         var frac:Number = numOr(probe(u,"fraction"),0);
         if(u == gg || u is MirrorHitUnit || frac < 1 || frac >= 100 || isTrigger(u)) return;
         var base:* = _baseHp[u];
         if(base === undefined) return;
         var cur:Number = numOr(probe(u,"hp"),Number(base));
         var dmg:Number = Math.max(0,Number(base)-cur);
         var armor:Number = numOr(probe(u,"armor_hp"),0);
         var shield:Number = numOr(probe(u,"shithp"),0);
         var defense:Object = _baseDefense[u];
         var armorLoss:Number = defense == null ? 0 : Math.max(0,defense.armor-armor);
         var shieldLoss:Number = defense == null ? 0 : Math.max(0,defense.shield-shield);
         _baseHp[u] = cur;
         _baseDefense[u] = {armor:armor,shield:shield};
         if(dmg <= 0 && armorLoss <= 0 && shieldLoss <= 0) return;
         var hit:Object = _pendingHits[u];
         if(hit == null)
         {
            hit = {id:String(probe(u,"id")),k:_units.known(u),dmg:0,armorLoss:0,shieldLoss:0};
            _pendingHits[u] = hit;
         }
         hit.dmg += dmg; hit.armorLoss += armorLoss; hit.shieldLoss += shieldLoss;
      }

      private static function unitFields(u:Object,names:Array):Object
      {
         var out:Object = {};
         for each(var name:String in names)
         {
            var value:* = probe(u,name);
            if(value != null) out[name] = name=="vulner" && value is Array
               ? NativeRoomState.numbers(value) : (value is Array ? value.concat() : value);
         }
         return out;
      }

      private static function applyUnitFields(u:Object,fields:Object):void
      {
         if(fields == null) return;
         for(var name:String in fields)
            try { u[name] = fields[name] is Array ? fields[name].concat() : fields[name]; } catch(err:*) {}
      }

      private function removeHitUnit(u:Object):void
      {
         var hit:MirrorHitUnit = _hitUnits[u];
         if(hit != null) hit.dispose();
         delete _hitUnits[u];
      }

      private function clearHitUnits():void
      {
         for(var u:Object in _hitUnits) removeHitUnit(u);
         _hitUnits = new Dictionary();
         _baseDefense = new Dictionary();
      }

      // Interpolate one snapshot interval behind the host; never quantize valid positions.
      private function queueUnitMotion(u:Object,x:Number,y:Number):void
      {
         var now:int = getTimer();
         var prev:Object = _unitMotion[u];
         var dx:Number = x-Number(probe(u,"X")), dy:Number = y-Number(probe(u,"Y"));
         if(prev == null || !freezeAI || dx*dx+dy*dy>600*600 || now-prev.at>1000)
         {
            u["setPos"](x,y);
            _unitMotion[u] = {x:x,y:y,tx:x,ty:y,at:now,duration:200};
            return;
         }
         _unitMotion[u] = {x:Number(u["X"]),y:Number(u["Y"]),tx:x,ty:y,at:now,
            duration:Math.max(50,Math.min(600,now-prev.at))};
      }

      /** Host applies net HP loss after client mitigation (native D_INSIDE, no second armor reduction).
       *  M9：attacker 传入客户端幽灵时，把敌人仇恨拉到幽灵上。 */
      public function applyDamage(id:String, dmg:Number, attacker:Object = null, key:String = "", hit:Object = null):Boolean
      {
         if(world == null || loc == null || !isFinite(dmg) || dmg < 0)
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
               if(String(probe(u, "id")) == id && (key == "" || _units.known(u) == key))
               {
                  if(numOr(probe(u,"sost"),3)>=3 || probe(u,"invulner")==true) return false;
                  // The joiner already applied native defenses. D_INSIDE avoids a second reduction.
                  if(hit != null)
                  {
                     var armorLoss:Number = numOr(hit.armorLoss,0);
                     var shieldLoss:Number = numOr(hit.shieldLoss,0);
                     if(isFinite(armorLoss) && armorLoss>0)
                     {
                        u["armor_hp"] = Math.max(0,numOr(probe(u,"armor_hp"),0)-armorLoss);
                        if(u["armor_hp"]<=0) u["armor_qual"]=0;
                     }
                     if(isFinite(shieldLoss) && shieldLoss>0)
                     {
                        shieldLoss = Math.min(shieldLoss,Math.max(0,numOr(probe(u,"shithp"),0)));
                        u["shithp"] = Math.max(0,numOr(probe(u,"shithp"),0)-shieldLoss);
                     }
                  }
                  if(dmg > 0) u["damage"](dmg, 100, null, true);
                  if(shieldLoss > 0)
                  {
                     var feedback:HitFeedback = _shieldFeedback[u];
                     if(feedback == null) _shieldFeedback[u] = feedback = new HitFeedback();
                     feedback.show(u,0,shieldLoss);
                     try { u["visDetails"](); } catch(feedbackError:*) {}
                  }
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
      public function reconcileWorld(list:Array, full:Boolean=false):void
      {
         if(world == null || loc == null || list == null)
         {
            return;
         }
         // M21：宿主列表为空时**不动**本地敌人——空列表可能是换房过渡/
         // 短暂空房的瞬时状态；照单移除会永久清空加入方房间
         // （之后注入失败的话房间就永远没敌人了）。
         if(list.length == 0 && !full)
         {
            return;
         }
         var units:Object = probe(loc, "units");
         if(units == null || !(units is Array))
         {
            return;
         }
         _units.enter(loc);
         var claimed:Dictionary = new Dictionary();
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
            if(_units.resolve(e, units as Array, claimed) != null)
            {
               continue;
            }
            if(spawned >= 8 && !full)
            {
               continue;
            }
            var puppet:Object = spawnUnitPuppet(e);
            if(puppet != null)
            {
               claimed[puppet] = true;
               if(e.k != null) _units.bind(String(e.k),puppet);
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
               if(v == gg || v is MirrorHitUnit || isSceneHitUnit(v))
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
               if(claimed[v] != true)
               {
                  try
                  {
                     loc["remObj"](v);
                     arr.splice(i, 1);
                     delete _frozen[v];
                     delete _baseHp[v];
                     delete _baseDefense[v];
                     delete _unitMotion[v];
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
            var cname:String = String(e.cls);
            var cid:String = String(e.id);
            var map:XML = <unit/>;
            if(cname.indexOf("UnitAlicorn") >= 0)
            {
               map.@tr = int(e.tr);
               cid = String(int(e.tr));
            }
            // Numeric variants drive raiders/slavers as well as alicorns.
            // Mine with tr=0 must use its id path; an explicit zero bypasses it.
            else if(int(e.tr) > 0) map.@tr = int(e.tr);
            if(cname.indexOf("UnitTurret") >= 0) cid=TurretDisplay.constructorId(e);
            if(cname=="fe.unit::UnitTrap")cid=null;
            // Constructors obtain base stats/animations from AllData themselves.
            // param3 is a map placement XML, NOT the AllData unit definition.
            var u:Object = new (cls as Class)(cid, 100, map, null);
            u["doop"] = true;
            u["unres"] = true;
            u["fraction"] = numOr(e.fraction, 1);
            u["warn"] = 0;
            u["id"] = String(e.id);
            // M26：落点校验——生成图（其他模组随机房）两侧几何不同，
            // 宿主坐标可能在加入方房外（#1010 实测）；就近吸附有效瓦片
            var landPos:Object = validLandPos(numOr(e.x, 0), numOr(e.y, 0));
            if(landPos == null)
            {
               _injectFailed[eid] = true;
               Log.d("RConnectGame: inject '" + eid
                  + "' skipped: no valid tile near host pos");
               return null;
            }
            u["putLoc"](loc, Number(landPos.x), Number(landPos.y));
            loc["addObj"](u);
            var units:Object = loc["units"];
            units["push"](u);
            _spawnedPuppets[u] = loc;
            u["disabled"] = true;   // 视觉已挂，停本地 AI
            u["setVisPos"]();
            // M19：注入时同步宿主外观帧/瞄准点
            applyUnitAppearance(u, numOr(e.vf, -1), numOr(e.cx, -1),
               numOr(e.cy, -1));
            Log.d("RConnectGame: injected '" + e.id + "' (" + e.cls
               + ") at " + Math.round(numOr(e.x, 0)) + ","
               + Math.round(numOr(e.y, 0)));
            return u;
         }
         catch(err:*)
         {
            _injectFailed[String(e.id)] = true;
            Log.d("RConnectGame: inject '" + e.id + "' failed: " + err
               + (err is Error && (err as Error).getStackTrace() != null
                  ? " | " + (err as Error).getStackTrace() : ""));
            return null;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return null;
      }

      private var _injectFailed:Object = {};

      public function roomKey(room:Object=null):String
      {
         if(room==null)room=loc;
         if(room==null)return "";
         return String(probe(probe(probe(room,"land"),"act"),"id"))+"/"+String(probe(room,"landProb"))+"/"+
            int(probe(room,"landX"))+","+int(probe(room,"landY"))+","+int(probe(room,"landZ"));
      }

      /** Scoped settlement for reports sent just before a door crossing.
       * Never step an inactive room or move the real player into it. */
      public function inRoom(room:Object,fn:Function):*
      {
         var old:Object=loc,wl:Object=world.loc,land:Object=world.land,ll:Object=land.loc;
         try {loc=room;world.loc=room;land.loc=room;return fn();}
         finally {loc=old;world.loc=wl;land.loc=ll;}
      }

      public function checkpoint():Object
      {
         rconnect.core.TravelGuard.clear();
         var list:Array=readUnitsSnapshot() || [],used:Dictionary=new Dictionary();
         for each(var s:Object in list)
         {
            var u:Object=_units.resolve(s,loc.units,used);
            if(u!=null)s.runtime=NativeRoomState.unit(u);
         }
         var objects:Array=readObjsSnapshot() || [];used=new Dictionary();
         for each(s in objects)
         {
            var b:Object=_objects.resolve(s,loc.objs,used);
            if(b!=null) {s.runtime=NativeRoomState.scalars(b);s.inter=NativeRoomState.scalars(probe(b,"inter"));s.interNative=RConnectInteractionAccess.capture(probe(b,"inter"));}
         }
         return {key:roomKey(),width:loc.spaceX,height:loc.spaceY,roomId:String(probe(loc.room,"id")),
            units:list,objs:objects,loots:readLootSync() || [],tiles:_terrain.checkpoint(loc)};
      }

      public function roomRole(authority:Boolean):void
      {
         _presentation.reset();clearHitUnits();restoreMirrorMasks();restoreUnitViews();
         for(var u:Object in _freezeOriginal) try {u.disabled=_freezeOriginal[u];}catch(e:*){}
         _freezeOriginal=new Dictionary();_frozen=new Dictionary();_hostAlive=new Dictionary();
         _pendingHits=new Dictionary();_baseHp=new Dictionary();_baseDefense=new Dictionary();
         _unitMotion=new Dictionary();_mirroring=!authority;freezeAI=!authority;
         _lastLocRef=null;resetBaselinesIfWorldChanged();
      }

      public function followMapGeneration(info:Object):void
      {
         adoptHostLandParams(info);regenCurrentLand();
      }

      public function restoreCheckpoint(s:Object,authority:Boolean,foreign:Boolean):void
      {
         if(s==null) {roomRole(authority);return;}
         if(int(s.width)!=int(loc.spaceX) || int(s.height)!=int(loc.spaceY))
            throw new Error("Room geometry differs: "+roomKey());
         roomRole(authority);
         if(foreign)_objects.clearRoom(loc);
         reconcileObjs(s.objs as Array);
         var used:Dictionary=new Dictionary();
         for each(var os:Object in s.objs)
         {
            var box:Object=_objects.resolve(os,loc.objs,used);
            if(box!=null){NativeRoomState.restore(box,os.runtime);NativeRoomState.restore(probe(box,"inter"),os.inter);RConnectInteractionAccess.restore(probe(box,"inter"),os.interNative);}
         }
         _terrain.restoreCheckpoint(loc,s.tiles as Array);
         // A mirror is a display surrogate. Reconstruct native units when its
         // authority changes, with original difficulty, AI and weapons.
         if(foreign)
         {
            for each(var previous:Object in (loc.units as Array).concat())
            {
               if(previous==gg || isSceneHitUnit(previous) || probeNum(previous,"fraction",0)>=100)continue;
               loc.remObj(previous);var index:int=loc.units.indexOf(previous);if(index>=0)loc.units.splice(index,1);
               delete _spawnedPuppets[previous];
            }
            _units.clearRoom(loc);
         }
         used=new Dictionary();_units.enter(loc);
         for each(var us:Object in s.units)
         {
            if(String(us.cls)=="fe.unit::VirtualUnit")continue;
            var unit:Object=_units.resolve(us,loc.units,used);
            if(unit==null)
            {
               var cls:Class=main.loaderInfo.applicationDomain.getDefinition(String(us.cls)) as Class;
               var map:XML=us.runtime.internal.xml==null?<unit/>:new XML(us.runtime.internal.xml);
               if(int(us.tr)>0)map.@tr=int(us.tr);
               unit=new cls(NativeRoomState.constructorId(us),Number(loc.locDifLevel),map,null);
               unit.putLoc(loc,Number(us.x),Number(us.y));loc.addObj(unit);loc.units.push(unit);
               _units.bind(String(us.k),unit);used[unit]=true;
            }
            NativeRoomState.restoreUnit(unit,us.runtime,main);
            RConnectAnimationAccess.receive(unit as Unit,us.pose,String(us.anim));
            if(us.body!=null)TurretDisplay.receive(unit,us.body);
            delete _spawnedPuppets[unit];
         }
         // Empty is a real checkpoint too, not a temporary network omission.
         for each(unit in (loc.units as Array).concat())
            if(unit!=gg && !(unit is MirrorHitUnit) && !isSceneHitUnit(unit) && probeNum(unit,"fraction",0)<100 && !used[unit])
            {loc.remObj(unit);index=loc.units.indexOf(unit);if(index>=0)loc.units.splice(index,1);}
         for each(var loot:Array in lootWalk())loc.remObj(loot[0]);
         lootSyncReset();_lootLoc=loc;applyLootSync(s.loots as Array);
         for(var lootKey:String in _lootObjOf)
         {
            _lootIdOf[_lootObjOf[lootKey]]=lootKey;
            _lootIdSeq=Math.max(_lootIdSeq,int(lootKey.substr(2)));
         }
         if(!authority)applyUnitsSync(s.units as Array);
         tileRedrawIfDirty();
      }

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

      private var _baseHp:Dictionary = new Dictionary();
      private var _lastLocRef:Object = null;
      private var _phantomLogged:Object = {};
      private var _hpRejectLogged:Object = {};
      private var _posSkipLogged:Object = {};

      /** M8：loc 对象引用变化（读档/换房/换图）时清空客户端同步基线，
       *  防止旧世界血量基线对新世界单位产生幻影伤害上报。 */
      private function resetBaselinesIfWorldChanged():void
      {
         if(_lastLocRef != loc)
         {
            _lastLocRef = loc;
            _presentation.reset();
            _objects.enter(loc);
            _units.enter(loc);
            restoreMirrorMasks();
            restoreUnitViews();
            _sceneExpected = new Dictionary();
            _scenePending = new Dictionary();
            _boxTween = new Dictionary();
            _boxTrack = new Dictionary();
            _istExpectO = new Dictionary();
            _istPending = new Dictionary();
            // Original AI flags belong to the whole session, including rooms
            // already visited. endSession must restore those units as well.
            clearHitUnits();
            _unitMotion = new Dictionary();
            _pendingHits = new Dictionary();
            _baseHp = new Dictionary();
            _frozen = new Dictionary();
            _animLogged = {};
            // M21：换房后清空注入失败黑名单——同一 id 在新房间可能可注入
            // （旧失败多为瞬时状态；防"永久空敌"）
            _injectFailed = {};
            // M27：换房清强制显示集（旧单位引用失效，等下轮重建）
            _hostAlive = new Dictionary();
            if(loc != null)
            {
               Log.d("RConnectGame: world loc changed, baselines reset");
            }
         }
      }

      /** 逐帧推进冻结单位的原生显示状态，不运行镜像AI或攻击。 */
      public function tickFrozenAnims():void
      {
         // gotoAndStop can synchronously broadcast EXIT_FRAME inside damage/animate.
         // Advance animation only from the game frame, never from those broadcasts.
         if(_animatingMirrors) return;
         var measureAt:int=presentationTiming==null?0:getTimer();
         _animatingMirrors = true;
         for(var u:Object in _frozen)
         {
            try
            {
               if(probe(u,"loc") !== loc) continue;
               captureUnitDamage(u);
               var motion:Object = _unitMotion[u];
               if(motion != null)
               {
                  var progress:Number = Math.min(1,Math.max(0,(getTimer()-motion.at)/motion.duration));
                  u["setPos"](motion.x+(motion.tx-motion.x)*progress,motion.y+(motion.ty-motion.y)*progress);
                  u["setVisPos"]();
               }
               _presentation.animateBody(u);
               _presentation.tick(u);
               var hit:MirrorHitUnit = _hitUnits[u];
               if(hit != null) hit.sync();
            }
            catch(err:*)
            {
            }
         }
         _animatingMirrors = false;
         if(presentationTiming!=null){presentationTiming.motionMs+=getTimer()-measureAt;presentationTiming.motionCalls++;}
      }

      private var _frozen:Dictionary = new Dictionary();
      private var _animLogged:Object = {};
      private var _skinSeen:Boolean = false;
      private var _ponySeen:Boolean = false;

      /** M6 验证：采样被冻结 blit 单位的显示像素，两次采样不同 = 动画在动。 */
      public function animProbeTest():void
      {
         for(var u:Object in _frozen)
         {
            var id:String = String(probe(u,"id"));
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
