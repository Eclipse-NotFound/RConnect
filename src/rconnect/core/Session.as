package rconnect.core
{
   import flash.events.Event;
   import flash.events.TimerEvent;
   import flash.utils.Timer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   import rconnect.net.HostServer;
   import rconnect.net.NetMessageEvent;
   import rconnect.net.Protocol;
   import rconnect.net.TcpLink;

   /**
    * 会话状态机：offline / hosting / joining / connected。
    * 宿主权威中继：客户端发 playerstate，宿主合并广播 worldstate。
    */
   public class Session
   {
      public static const OFFLINE:String = "offline";
      public static const HOSTING:String = "hosting";
      public static const JOINING:String = "joining";
      public static const CONNECTED:String = "connected";

      public var mod:RConnectMod;
      public var mode:String = OFFLINE;
      public var error:String = "";

      public var server:HostServer;      // 宿主端
      public var link:TcpLink;           // 客户端端（宿主自己不用）
      public var myId:int = -1;          // 宿主固定 0
      public var myName:String = "";
      public var hostName:String = "";

      /** 宿主维护的 peer 表：{id, name, link, snap} */
      public var peers:Array = [];
      /** 客户端维护的远程状态：{id, name, snap} */
      public var remotes:Array = [];

      private var _tick:Timer;
      private var _tickCount:int = 0;
      private var _seq:int = 0;
      private var _lastRecvAt:Number = 0;
      private var _worldProbeT:int = 0;
      private var _autoRole:String = "";
      private var _autoGame:Boolean = false;
      private var _autoGameTries:int = 0;
      private var _autoMove:Boolean = false;
      private var _autoTravel:Boolean = false;
      private var _autoFollow:Boolean = false;
      private var _autoDamage:Boolean = false;
      private var _autoGhostDmg:Boolean = false;
      private var _autoHeal:Boolean = false;
      private var _autoHostKill:Boolean = false;
      private var _hostKillDone:Boolean = false;
      private var _autoDeactivate:Boolean = false;
      private var _deactDone:Boolean = false;
      private var _autoWalk:Boolean = false;
      private var _autoGhostAnim:Boolean = false;
      private var _autoBoxKill:Boolean = false;
      private var _boxKillDone:Boolean = false;
      private var _spawnTxLog:Boolean = false;
      private var _spawnRxLog:Boolean = false;
      private var _autoTileBreak:Boolean = false;
      private var _tileBreakDone:Boolean = false;
      private var _autoObjSpawn:Boolean = false;
      private var _objSpawnDone:Boolean = false;
      private var _autoDoorToggle:Boolean = false;
      private var _doorToggleCount:int = 0;
      private var _autoBoxLoot:Boolean = false;
      private var _boxLootDone:Boolean = false;
      private var _autoLootTest:Boolean = false;
      private var _lootTestCount:int = 0;
      private var _autoLootJoin:Boolean = false;
      private var _lootJoinDone:Boolean = false;
      private var _lootsTxLog:Boolean = false;
      private var _lootsRxLog:Boolean = false;
      private var _autoBoxMove:Boolean = false;
      private var _boxMoveDone:Boolean = false;
      private var _autoBoxMoveJoin:Boolean = false;
      private var _boxMoveJoinDone:Boolean = false;
      private var _autoDoorJoin:Boolean = false;
      private var _doorJoinDone:Boolean = false;
      private var _autoBoxLootJoin:Boolean = false;
      private var _boxLootJoinDone:Boolean = false;
      private var _autoLoadSave:int = -1;
      private var _loadSaveDone:Boolean = false;
      private var _loadSaveTries:int = 0;
      private var _autoTravelLand:String = "";
      private var _travelLandDone:Boolean = false;
      private var _worldInject:Boolean = true;
      private var _userLeft:Boolean = false;
      private var _rejoinTries:int = 0;
      private var _rejoinTimer:Timer;
      private var _autoChatSent:Boolean = false;
      private var _wasDead:Boolean = false;
      /** M11：跟随抑制截止时刻（ms）——存档加载前后/过渡期不跟随。 */
      private var _followSuppressUntil:Number = 0;

      public function Session(mod:RConnectMod)
      {
         this.mod = mod;
         this.myName = mod.config.getValue("nickname");
         this._autoRole = String(mod.config.getValue("autoRole"));
         var ag:String = String(mod.config.getValue("autoGame"));
         this._autoGame = (ag == "1" || ag == "true" || ag == "yes");
         var am:String = String(mod.config.getValue("autoMove"));
         this._autoMove = (am == "1" || am == "true" || am == "yes");
         var at:String = String(mod.config.getValue("autoTravel"));
         this._autoTravel = (at == "1" || at == "true" || at == "yes");
         var af:String = String(mod.config.getValue("autoFollow"));
         this._autoFollow = (af == "1" || af == "true" || af == "yes");
         var ad:String = String(mod.config.getValue("autoDamage"));
         this._autoDamage = (ad == "1" || ad == "true" || ad == "yes");
         var agd:String = String(mod.config.getValue("autoGhostDmg"));
         this._autoGhostDmg = (agd == "1" || agd == "true" || agd == "yes");
         var ah:String = String(mod.config.getValue("autoHeal"));
         this._autoHeal = (ah == "1" || ah == "true" || ah == "yes");
         var als:String = String(mod.config.getValue("autoLoadSave"));
         this._autoLoadSave = (als != "" && !isNaN(Number(als)))
            ? int(als) : -1;
         var hk:String = String(mod.config.getValue("autoHostKill"));
         this._autoHostKill = (hk == "1" || hk == "true" || hk == "yes");
         var de:String = String(mod.config.getValue("autoDeactivate"));
         this._autoDeactivate = (de == "1" || de == "true" || de == "yes");
         var wk:String = String(mod.config.getValue("autoWalk"));
         this._autoWalk = (wk == "1" || wk == "true" || wk == "yes");
         var ga:String = String(mod.config.getValue("autoGhostAnim"));
         this._autoGhostAnim = (ga == "1" || ga == "true" || ga == "yes");
         var bk:String = String(mod.config.getValue("autoBoxKill"));
         this._autoBoxKill = (bk == "1" || bk == "true" || bk == "yes");
         var tb:String = String(mod.config.getValue("autoTileBreak"));
         this._autoTileBreak = (tb == "1" || tb == "true" || tb == "yes");
         var os:String = String(mod.config.getValue("autoObjSpawn"));
         this._autoObjSpawn = (os == "1" || os == "true" || os == "yes");
         var dt:String = String(mod.config.getValue("autoDoorToggle"));
         this._autoDoorToggle = (dt == "1" || dt == "true" || dt == "yes");
         var bl:String = String(mod.config.getValue("autoBoxLoot"));
         this._autoBoxLoot = (bl == "1" || bl == "true" || bl == "yes");
         var lt:String = String(mod.config.getValue("autoLootTest"));
         this._autoLootTest = (lt == "1" || lt == "true" || lt == "yes");
         var lj:String = String(mod.config.getValue("autoLootJoin"));
         this._autoLootJoin = (lj == "1" || lj == "true" || lj == "yes");
         var bm:String = String(mod.config.getValue("autoBoxMove"));
         this._autoBoxMove = (bm == "1" || bm == "true" || bm == "yes");
         var bj:String = String(mod.config.getValue("autoBoxMoveJoin"));
         this._autoBoxMoveJoin = (bj == "1" || bj == "true" || bj == "yes");
         var dj:String = String(mod.config.getValue("autoDoorJoin"));
         this._autoDoorJoin = (dj == "1" || dj == "true" || dj == "yes");
         var blj:String = String(mod.config.getValue("autoBoxLootJoin"));
         this._autoBoxLootJoin = (blj == "1" || blj == "true" || blj == "yes");
         this._autoTravelLand = String(mod.config.getValue("autoTravelLand"));
         var wi:String = String(mod.config.getValue("worldInject"));
         this._worldInject = (wi != "0" && wi != "false" && wi != "no");
         _tick = new Timer(int(mod.config.getValue("tickMs")));
         _tick.addEventListener(TimerEvent.TIMER, onTick);
         _tick.start();
      }

      /** 自动化联测：按配置 autoRole 自动主持/加入。 */
      public function autoStart():void
      {
         if(_autoRole == "host")
         {
            Log.d("RConnectNet: autoStart host");
            startHost();
         }
         else if(_autoRole == "join")
         {
            Log.d("RConnectNet: autoStart join");
            startJoin();
         }
      }

      // ---- 状态机 -------------------------------------------------------

      public function startHost():void
      {
         stop();
         error = "";
         _userLeft = false;
         server = new HostServer();
         server.addEventListener(HostServer.STARTED, onServerStarted);
         server.addEventListener(HostServer.FAILED, onServerFailed);
         server.addEventListener(HostServer.CLIENT_ADDED, onClientAdded);
         server.addEventListener(HostServer.CLIENT_REMOVED, onClientRemoved);
         server.listen(int(mod.config.getValue("port")));
         if(!server.bound)
         {
            // 绑定失败（端口被占，如同机另一宿主实例）——mode 仍会显示
            // hosting，此行是唯一可靠信号
            Log.d("RConnectNet: host bind FAILED on port "
               + int(mod.config.getValue("port")));
         }
         mode = HOSTING;
         myId = 0;
         hostName = myName;
         myName = String(mod.config.getValue("nickname"));
      }

      public function startJoin():void
      {
         stop();
         error = "";
         _userLeft = false;
         link = new TcpLink();
         link.addEventListener(TcpLink.CONNECTED, onLinkConnected);
         link.addEventListener(TcpLink.CLOSED, onLinkClosed);
         link.addEventListener(TcpLink.FAILED, onLinkFailed);
         link.addEventListener(TcpLink.MESSAGE, onLinkMessage);
         link.connect(String(mod.config.getValue("hostIp")),
                      int(mod.config.getValue("port")));
         mode = JOINING;
         myId = -1;
      }

      public function leave():void
      {
         _userLeft = true;
         if(mode == CONNECTED || mode == JOINING)
         {
            if(link != null && link.isOpen)
            {
               link.send(Protocol.make(Protocol.MSG_GOODBYE, {}));
            }
         }
         stop();
         mode = OFFLINE;
         error = "";
      }

      public function sendChat(text:String):void
      {
         if(text == null || text.length == 0)
         {
            return;
         }
         var msg:Object = Protocol.make(Protocol.MSG_CHAT,
            {name: myName, text: text});
         if(server != null)
         {
            server.broadcast(msg);
         }
         else if(link != null && link.isOpen)
         {
            link.send(msg);
         }
         // 自己的消息本地回显
         if(mod.hud != null)
         {
            mod.hud.addChatLine(myName, text);
         }
      }

      private function stop():void
      {
         if(server != null)
         {
            server.close();
            server = null;
         }
         if(link != null)
         {
            link.close();
            link = null;
         }
         peers = [];
         remotes = [];
      }

      // ---- 宿主事件 -----------------------------------------------------

      private function onServerStarted(e:Event):void
      {
         mode = HOSTING;
      }

      private function onServerFailed(e:Event):void
      {
         error = "host failed (port busy?)";
         mode = OFFLINE;
      }

      private function onClientAdded(e:NetMessageEvent):void
      {
         // 新连接：接管其消息流，等 hello 里带昵称后入表
         var link:TcpLink = e.data as TcpLink;
         link.addEventListener(TcpLink.MESSAGE, onHostMessage);
      }

      private function onClientRemoved(e:NetMessageEvent):void
      {
         var link:TcpLink = e.data as TcpLink;
         Log.d("RConnectNet: peer '" + link.peerName + "' left");
         removePeerByLink(link);
         broadcastWorldState();
      }

      // ---- 客户端事件 ---------------------------------------------------

      private function onLinkConnected(e:Event):void
      {
         Log.d("RConnectNet: connected to host, sending hello");
         link.send(Protocol.make(Protocol.MSG_HELLO, {name: myName}));
      }

      private function onLinkClosed(e:Event):void
      {
         if(mode == JOINING || mode == CONNECTED)
         {
            if(mod.game != null)
            {
               for each(var r:Object in remotes)
               {
                  mod.game.removeRemote(int(r.id));
               }
            }
            remotes = [];
            mode = OFFLINE;
            maybeRejoin("closed");
         }
      }

      private function onLinkFailed(e:Event):void
      {
         error = "connect failed (check ip/port)";
         mode = OFFLINE;
         // 与断线重连共用同一重试通道（防双定时器竞态）
         maybeRejoin("failed");
      }

      /** 意外断线/连接失败自动重连（用户主动离开除外，限 20 次、间隔 2s）。 */
      private function maybeRejoin(reason:String):void
      {
         if(_userLeft || _autoRole != "join" || _rejoinTries >= 20)
         {
            return;
         }
         _rejoinTries++;
         Log.d("RConnectNet: link " + reason + ", auto-rejoin try "
            + _rejoinTries + "/20");
         if(_rejoinTimer == null)
         {
            _rejoinTimer = new Timer(2000, 1);
            _rejoinTimer.addEventListener(TimerEvent.TIMER_COMPLETE,
               function(ev:TimerEvent):void
               {
                  if(mode == OFFLINE && !_userLeft)
                  {
                     startJoin();
                  }
               });
         }
         _rejoinTimer.start();
      }

      // ---- 消息处理 -----------------------------------------------------

      private function onLinkMessage(e:NetMessageEvent):void
      {
         handleMessage(e.data as Object);
      }

      /** 客户端收到宿主的消息。 */
      private function handleMessage(msg:Object):void
      {
         var type:String = msg != null ? String(msg.type) : "";
         _lastRecvAt = new Date().time;

         switch(type)
         {
            case Protocol.MSG_WELCOME:
               myId = int(msg.id);
               hostName = msg.name != undefined ? String(msg.name) : "";
               mode = CONNECTED;
               Log.d("RConnectNet: welcome id=" + myId + " host=" + hostName);
               compareWorldInfo(msg.worldInfo);
               // 自动化联测：join 连接成功后自动发一条聊天验证转发
               if(_autoRole == "join" && !_autoChatSent)
               {
                  _autoChatSent = true;
                  sendChat("hello from " + myName);
               }
               break;

            case Protocol.MSG_UNITSYNC:
               if(mod.game != null)
               {
                  // M7：世界注入——同 land 同 loc 时把敌对单位镜像成宿主快照
                  if(_worldInject && msg.worldInfo != null)
                  {
                     mod.game.refreshWorld();
                     var mine:Object = mod.game.readWorldInfo();
                     if(mine != null
                        && String(mine.curLandId)
                           == String(msg.worldInfo.curLandId)
                        && String(mine.locId) == String(msg.worldInfo.locId))
                     {
                        mod.game.reconcileWorld(msg.units as Array);
                        // M16：同房物品（箱/门）状态镜像
                        if(msg.objs != null)
                        {
                           mod.game.reconcileObjs(msg.objs as Array);
                        }
                        // M17：瓦片破坏差分 + 新生成物品
                        if(msg.tilePatch != null)
                        {
                           mod.game.applyTilePatch(msg.tilePatch as Array);
                        }
                        if(msg.objSpawn != null)
                        {
                           if(!_spawnRxLog)
                           {
                              _spawnRxLog = true;
                              Log.d("RConnectNet: objSpawn rx "
                                 + (msg.objSpawn as Array).length);
                           }
                           mod.game.applyObjSpawn(msg.objSpawn as Array);
                        }
                        // M24：可移动物品（Loot）位置/移除镜像
                        if(msg.loots != null)
                        {
                           if(!_lootsRxLog)
                           {
                              _lootsRxLog = true;
                              Log.d("RConnectNet: loots rx first "
                                 + (msg.loots as Array).length);
                           }
                           mod.game.applyLootSync(msg.loots as Array);
                        }
                     }
                  }
                  var r:Object = mod.game.applyUnitsSync(msg.units as Array);
                  _syncCount++;
                  if(_syncCount % 20 == 1)
                  {
                     Log.d("RConnectNet: unitsync matched "
                        + r.matched + "/" + r.total);
                  }
                  // M5c：按宿主世界身份自动跟随换房（测试模式）
                  // M10b：本地玩家死亡流程期间暂停跟随，避免干扰复活回城
                  // M11：过渡期/存档加载后抑制期不跟随（否则房间被重置
                  // 回出生点，反复重进、场景无法正常加载）
                  if(_autoFollow && msg.worldInfo != null
                     && !mod.game.isPlayerDead()
                     && !mod.game.isTransitioning()
                     && flash.utils.getTimer() > _followSuppressUntil)
                  {
                     var fres:String = mod.game.followHostWorld(msg.worldInfo);
                     if(fres.indexOf("skip-same") != 0
                        && fres.indexOf("not-in-game") != 0
                        && fres.indexOf("skip-cooldown") != 0)
                     {
                        Log.d("RConnectWorld: follow result: " + fres);
                     }
                  }
               }
               break;

            case Protocol.MSG_WORLDSTATE:
               applyWorldState(msg.players as Array, msg.seen);
               break;

            case Protocol.MSG_CHAT:
               if(mod.hud != null)
               {
                  mod.hud.addChatLine(String(msg.name), String(msg.text));
               }
               break;

            case Protocol.MSG_PLAYERDMG:
               // 客户端：宿主世界对你的化身造成的伤害 → 本地玩家结算
               // M10b：本地已死（t_die/sost>=3）时不再施加（死亡流程本地处理）
               if(mod.game != null && mod.game.gg != null
                  && msg.dmg != undefined && Number(msg.dmg) > 0
                  && !mod.game.isPlayerDead())
               {
                  try
                  {
                     mod.game.gg["damage"](Number(msg.dmg), 0, null, false);
                     Log.d("RConnectNet: took " + Number(msg.dmg)
                        + " damage from host world");
                  }
                  catch(err:*)
                  {
                     Log.d("RConnectNet: player damage apply failed: " + err);
                  }
               }
               break;

            case Protocol.MSG_GOODBYE:
               break;
         }
      }

      /** 宿主收到客户端消息（在 server 的 link 上）。 */
      private function onHostMessage(e:NetMessageEvent):void
      {
         var link:TcpLink = e.target as TcpLink;
         var msg:Object = e.data as Object;
         if(msg == null)
         {
            return;
         }
         var type:String = String(msg.type);

         switch(type)
         {
            case Protocol.MSG_HELLO:
               link.id = nextPeerId();
               link.peerName = msg.name != undefined ? String(msg.name) : "Pony";
               peers.push({id: link.id, name: link.peerName, link: link, snap: null});
               var wInfo:Object = mod.game != null
                  ? mod.game.readWorldInfo() : null;
               link.send(Protocol.make(Protocol.MSG_WELCOME,
                  {id: link.id, name: myName, worldInfo: wInfo}));
               Log.d("RConnectNet: peer #" + link.id + " '" + link.peerName
                  + "' joined");
               broadcastWorldState();
               break;

            case Protocol.MSG_PLAYERSTATE:
               var peer:Object = findPeerByLink(link);
               if(peer != null)
               {
                  peer.snap = msg.snap;
                  // 宿主侧同样应用快照到本地幽灵
                  if(mod.game != null)
                  {
                     mod.game.updateRemote(peer.id, peer.snap,
                        String(peer.name));
                  }
               }
               broadcastWorldState();
               break;

            case Protocol.MSG_CHAT:
               var chat:Object = Protocol.make(Protocol.MSG_CHAT,
                  {name: link.peerName, text: String(msg.text)});
               server.broadcast(chat, link);
               Log.d("RConnectNet: chat '" + link.peerName + "': "
                  + String(msg.text));
               if(mod.hud != null)
               {
                  mod.hud.addChatLine(String(chat.name), String(chat.text));
               }
               break;

            case Protocol.MSG_DAMAGE:
               // 宿主：应用客户端上报的伤害（客户端命中检测 → 宿主权威结算），
               // 并把敌人仇恨拉到该客户端的幽灵化身上（M9）
               if(msg.hits is Array)
               {
                  var applied:int = 0;
                  var peerObj:Object = findPeerByLink(link);
                  var attacker:Object = (mod.game != null && peerObj != null)
                     ? mod.game.getRemoteGhost(peerObj.id) : null;
                  for each(var h:Object in msg.hits as Array)
                  {
                     if(mod.game != null
                        && mod.game.applyDamage(String(h.id), Number(h.dmg),
                           attacker))
                     {
                        applied++;
                     }
                  }
                  if(applied > 0)
                  {
                     Log.d("RConnectNet: applied " + applied
                        + " client damage hits");
                  }
               }
               break;

            case Protocol.MSG_LOOT:
               // M24：宿主应用加入方的拾取/推动上报（宿主权威落位）
               if(mod.game != null)
               {
                  mod.game.applyLootReports(msg);
               }
               break;

            case Protocol.MSG_OBJS:
               // M25：宿主应用加入方的 Box 位移（念力）与 ist 变更上报
               if(mod.game != null)
               {
                  mod.game.applyObjReports(msg);
               }
               break;

            case Protocol.MSG_GOODBYE:
               removePeerByLink(link);
               broadcastWorldState();
               break;
         }
      }

      // ---- tick --------------------------------------------------------

      /** M4：比较宿主世界身份与本地世界（只记录，不做自动传送）。 */
      private function compareWorldInfo(hostInfo:Object):void
      {
         _hostWorldInfo = hostInfo;
         doCompareWorldInfo();
      }

      private var _hostWorldInfo:Object = null;
      private var _worldCompared:Boolean = false;

      /** 双方都进游戏后再做一次对比（welcome 时客户端往往还在菜单）。 */
      private function doCompareWorldInfo():void
      {
         if(_hostWorldInfo == null || mod.game == null || _worldCompared)
         {
            return;
         }
         var mine:Object = mod.game.readWorldInfo();
         if(mine == null)
         {
            return;
         }
         _worldCompared = true;
         var hostInfo:Object = _hostWorldInfo;
         var sameLoc:Boolean = String(mine.locId) == String(hostInfo.locId);
         var sameLand:Boolean = String(mine.curLandId) == String(hostInfo.curLandId);
         Log.d("RConnectWorld: host=" + hostInfo.curLandId + "/"
            + hostInfo.locId + "@" + Math.round(Number(hostInfo.x)) + ","
            + Math.round(Number(hostInfo.y))
            + " mine=" + mine.curLandId + "/" + mine.locId + "@"
            + Math.round(Number(mine.x)) + "," + Math.round(Number(mine.y))
            + " -> landMatch=" + sameLand + " locMatch=" + sameLoc);
      }

      private var _syncCount:int = 0;

      private function onTick(e:TimerEvent):void
      {
         _tickCount++;
         // 调试心跳（每 10s），定位 tick 停滞点；M11：附带世界身份与
         // 过渡状态，用于定位"场景无法正常加载/卡在过渡"问题
         if(_tickCount % 200 == 0)
         {
            var dbg:String = "RConnectDbg: tick " + _tickCount + " mode=" + mode;
            if(mod.game != null && mod.game.world != null)
            {
               var wi:Object = mod.game.readWorldInfo();
               var w:Object = mod.game.world;
               dbg += " world=" + (wi != null
                  ? String(wi.curLandId) + "/" + String(wi.locId) : "null")
                  + (wi != null
                     ? " x=" + Math.round(Number(wi.x))
                        + "," + Math.round(Number(wi.y)) : "")
                  + " tileV=" + (mod.game != null
                     ? String(mod.game.debugTileV()) : "?")
                  + " grid=" + (mod.game != null
                     ? mod.game.debugTileGrid() : "?")
                  + " ghostPose=" + (mod.game != null
                     ? mod.game.debugGhostPose() : "?")
                  + " localPose=" + (mod.game != null
                     ? mod.game.debugLocalPose() : "?")
                  + " t_exit=" + String(GameBridge.probe(w, "t_exit"))
                  + " comLoad=" + String(GameBridge.probe(w, "comLoad"))
                  + " clickReq=" + String(GameBridge.probe(w, "clickReq"))
                  + " verror=" + String(GameBridge.probe(
                     GameBridge.probe(w, "verror"), "visible"));
               // M12：World.step 卡点门控诊断
               var mm12:Object = GameBridge.probe(w, "mm");
               dbg += " mm.active=" + String(mm12 != null
                  ? GameBridge.probe(mm12, "active") : "null")
                  + " ng_wait=" + String(GameBridge.probe(w, "ng_wait"))
                  + " allStat=" + String(GameBridge.probe(w, "allStat"))
                  + " onPause=" + String(GameBridge.probe(w, "onPause"));
               // M12：allStat=2 的覆盖层定位（pip/sats/stand/guiPause）
               dbg += " pipA=" + String(GameBridge.probe(
                  GameBridge.probe(w, "pip"), "active"))
                  + " satsA=" + String(GameBridge.probe(
                     GameBridge.probe(w, "sats"), "active"))
                  + " standA=" + String(GameBridge.probe(
                     GameBridge.probe(w, "stand"), "active"))
                  + " guiPause=" + String(GameBridge.probe(
                     GameBridge.probe(w, "gui"), "guiPause"));
            }
            Log.d(dbg);
         }

         // M21：会话摘要（每 60s 一行全量状态，复测时粘贴用）
         if(_tickCount % 1200 == 600 && mod.game != null)
         {
            Log.d("RConnectReport: " + mod.game.sessionReport());
         }

         // 周期性刷新世界引用（gg/loc 会随进游戏/切场景变化，不能长期缓存）
         if(mod.game != null && _tickCount % 40 == 0)
         {
            mod.game.refreshWorld();
            mod.game.dumpGameError();   // 诊断：错误对话框文本进日志
            // M12：旅行过渡中被覆盖层卡住（失焦 pip 等）→ 强制关闭恢复。
            // 窗口失焦会触发游戏 onDeactivate → pip.onoff(11) 打开 PipBuck，
            // 无复位机制 → allStat=2 → gameplay 与 exitStep 冻结
            if(mod.game.world != null
               && GameBridge.probeNum(mod.game.world, "t_exit", 0) > 0
               && GameBridge.probeNum(mod.game.world, "allStat", 1) != 1)
            {
               mod.game.forceCloseOverlays();
            }
            // M12 复现钩子：模拟失焦（确定性触发覆盖层卡死路径）
            if(_autoDeactivate && !_deactDone && _tickCount >= 400
               && mod.game != null && mod.game.gg != null)
            {
               _deactDone = true;
               mod.game.deactivateTest();
            }
         }

         // 自动化联测：autoGame=1 时程序化开新游戏（主菜单，每 2 秒重试）
         if(_autoGame && mod.game != null
            && mod.game.gg == null && _autoGameTries < 30
            && _tickCount % 40 == 0)
         {
            _autoGameTries++;
            mod.game.startGame();
         }
         if(_autoGame && mod.game != null)
         {
            mod.game.tickAutoGame();
         }

         // M8 自动化联测：autoLoadSave>=0 时程序化加载存档（等价菜单 Continue；
         // 内部先 newGame 初始化世界骨架再 comLoad 读档，用于让加入方用
         // 不同进度的存档制造世界差异）
         // M11：读档前后抑制跟随（读档完成 + 世界稳定前的 8s 内不跟随，
         // 防止过渡期 gotoXY 把房间重置回出生点）
         if(_autoLoadSave >= 0 && !_loadSaveDone
            && mod.game != null && _tickCount % 40 == 0
            && _loadSaveTries < 15)
         {
            _loadSaveTries++;
            _followSuppressUntil = flash.utils.getTimer() + 8000;
            if(mod.game.loadSaveTest(_autoLoadSave))
            {
               _loadSaveDone = true;
            }
         }

         // 自动化联测：autoMove=1 时周期挪动本地玩家（30s 后开始，避开传送过渡）
         // M10b：死亡流程期间不挪动（避免干扰复活回城）
         // M11：过渡期不挪动（避免干扰读档/退出流程）
         if(_autoMove && mod.game != null && _tickCount % 100 == 0
            && _tickCount > 600 && !mod.game.isPlayerDead()
            && !mod.game.isTransitioning())
         {
            mod.game.moveTest();
         }
         // M14 复现钩子：autoWalk=1 时在 30-60s 窗口平滑右移（每 10 tick=0.5s 一步）
         if(_autoWalk && mod.game != null && _tickCount >= 600
            && _tickCount <= 1200 && _tickCount % 10 == 0
            && !mod.game.isTransitioning())
         {
            mod.game.walkStepTest();
         }
            // M20：近身敌人转火加入方（每 1s；让敌人会识别/攻击加入方）
            if(mod.game != null && _tickCount % 20 == 0)
            {
               mod.game.redirectNearbyAggro();
            }
            // M16 复现钩子：宿主破坏第一个物品（验证 join 端 dead 同步）
            if(_autoBoxKill && !_boxKillDone && mod.game != null
               && mod.game.gg != null && _tickCount > 800)
            {
               _boxKillDone = true;
               mod.game.boxKillTest();
            }
            // M17 复现钩子：宿主破墙 + 现场生成掉落（验证瓦片/新物品同步）
            if(_autoTileBreak && !_tileBreakDone && mod.game != null
               && mod.game.gg != null && _tickCount > 800)
            {
               _tileBreakDone = true;
               mod.game.tileBreakTest();
            }
            if(_autoObjSpawn && !_objSpawnDone && mod.game != null
               && mod.game.gg != null && _tickCount > 800)
            {
               _objSpawnDone = true;
               mod.game.objSpawnTest();
            }
            // M25 复现钩子：宿主 60s 移箱（joiner 镜像断言 box pos synced）
            if(_autoBoxMove && !_boxMoveDone && mod.game != null
               && mod.game.gg != null && _tickCount > 1200
               && !mod.game.isTransitioning())
            {
               _boxMoveDone = true;
               mod.game.boxMoveTest();
            }
            // M25 复现钩子：joiner 100s 移箱（错峰于宿主 60s，两方向各自
            // 可观测：宿主断言 box move applied）
            if(_autoBoxMoveJoin && !_boxMoveJoinDone && mod.game != null
               && mod.game.gg != null && _tickCount > 2000
               && !mod.game.isTransitioning())
            {
               _boxMoveJoinDone = true;
               mod.game.boxMoveTest();
            }
            // M25 复现钩子：joiner 70s 开门（宿主断言 ist report applied）
            if(_autoDoorJoin && !_doorJoinDone && mod.game != null
               && mod.game.gg != null && _tickCount > 1400
               && !mod.game.isTransitioning())
            {
               _doorJoinDone = true;
               mod.game.doorJoinTest();
            }
            // M25 复现钩子：joiner 80s 搜刮第一个容器（ist 上报路径——
            // 稳定持久态，可过稳定性门；宿主断言 ist report applied t=2）
            if(_autoBoxLootJoin && !_boxLootJoinDone && mod.game != null
               && mod.game.gg != null && _tickCount > 1600
               && !mod.game.isTransitioning())
            {
               _boxLootJoinDone = true;
               mod.game.boxLootTest();
            }
            // M24 复现钩子：宿主 50-70s 生成/推 Loot（自推进），90s 捡起；
            // joiner 70s 强制拾取（验证拾取上报→宿主移除）
            if(_autoLootTest && mod.game != null && mod.game.gg != null
               && !mod.game.isTransitioning())
            {
               if(_tickCount > 1000 && _tickCount < 1200)
               {
                  mod.game.lootSpawnTest();   // 生成窗（幂等）
               }
               if(_tickCount > 1600 && _lootTestCount < 1)
               {
                  mod.game.lootPushTest();
                  _lootTestCount = 1;
               }
               if(_tickCount > 2400 && _lootTestCount < 2)
               {
                  if(mod.game.lootTakeTest())
                  {
                     _lootTestCount = 2;
                  }
               }
            }
            if(_autoLootJoin && !_lootJoinDone && mod.game != null
               && mod.game.gg != null && _tickCount > 1400)
            {
               _lootJoinDone = true;
               mod.game.lootTakeJoinTest();
            }
            // M22 复现钩子：宿主 80s 开门 / 120s 关门（验证门开关双向同步；
            // 时点须晚于加入方连接收敛，首次快照会先收敛到当前状态）
            if(_autoDoorToggle && mod.game != null && mod.game.gg != null
               && !mod.game.isTransitioning())
            {
               if(_tickCount > 1600 && _doorToggleCount == 0)
               {
                  _doorToggleCount = 1;
                  mod.game.doorIcTest();
               }
               if(_tickCount > 2400 && _doorToggleCount == 1)
               {
                  _doorToggleCount = 2;
                  mod.game.doorIcTest();
               }
            }
            // M22 复现钩子：宿主搜刮第一个容器（验证已搜刮状态同步）
            if(_autoBoxLoot && !_boxLootDone && mod.game != null
               && mod.game.gg != null && _tickCount > 1600)
            {
               _boxLootDone = true;
               mod.game.boxLootTest();
            }
         // M17：瓦片变化后整房重绘（加入方应用瓦片差分后）
         if(mod.game != null && _tickCount % 10 == 0)
         {
            mod.game.tileRedrawIfDirty();
         }
         // M26：Box 平滑插值驱动（50ms/tick，tween 逼近宿主目标位）
         if(mod.game != null)
         {
            mod.game.tickBoxTweens();
         }
         // M26 诊断：宿主每房记一次门清单（id/autoClose/open）
         if(mod.game != null && _tickCount % 200 == 0
            && mode == HOSTING)
         {
            mod.game.logDoorInventory();
         }
         // M26 诊断：joiner 每房记一次本地单位可见性采样（RV 隐藏排查）
         if(mod.game != null && _tickCount % 200 == 0
            && mode == CONNECTED)
         {
            mod.game.logUnitVisibility();
         }
         // M24/M25/M26：joiner 高频（200ms）扫描本地 Loot 拾取/推动 + Box
         // 位移（念力）+ ist 变化（开门/开锁/搜刮）→ 上报宿主（搬运中的
         // 物体每秒 5 跳，接收端 tween 平滑）
         if(mode == CONNECTED && _tickCount % 4 == 0 && mod.game != null
            && link != null && link.isOpen)
         {
            var lrep:Object = mod.game.scanLootReports();
            if(lrep != null)
            {
               link.send(Protocol.make(Protocol.MSG_LOOT, lrep));
               Log.d("RConnectNet: loot report picked="
                  + (lrep.picked as Array).length + " moved="
                  + (lrep.moved as Array).length);
            }
            var orep:Object = mod.game.scanObjReports();
            if(orep != null)
            {
               link.send(Protocol.make(Protocol.MSG_OBJS, orep));
               Log.d("RConnectNet: objs report moved="
                  + ((orep.moved as Array) != null ? (orep.moved as Array).length : 0)
                  + " ist=" + ((orep.ist as Array) != null ? (orep.ist as Array).length : 0));
            }
         }

         // M14 诊断：autoGhostAnim=1 时强制幽灵标签循环（验证动画帧推进）
         if(_autoGhostAnim && mod.game != null && _tickCount % 20 == 0
            && _tickCount > 400)
         {
            mod.game.ghostAnimTest();
         }

         // M4：客户端进游戏后完成世界身份对比
         if(mode == CONNECTED && !_worldCompared && _tickCount % 20 == 0)
         {
            doCompareWorldInfo();
         }

         if(mode == CONNECTED && link != null && link.isOpen)
         {
            var snap:Object = mod.game != null ? mod.game.readSnapshot() : null;
            link.send(Protocol.make(Protocol.MSG_PLAYERSTATE,
               {id: myId, seq: _seq++, name: myName, snap: snap}));
            // M6a：驱动被冻结单位的动画（游戏自己的公开 animate()）
            if(mod.game != null)
            {
               mod.game.tickFrozenAnims();
               if(_autoDamage && _tickCount % 200 == 0)
               {
                  mod.game.animProbeTest();
               }
            }
            // M5b：客户端本地命中检测 → 上报宿主结算（每 10 tick = 500ms）
            if(mod.game != null && _tickCount % 10 == 0)
            {
               // 自动化联测：autoDamage=1 时先模拟本地伤害再检测
               if(_autoDamage && _tickCount % 100 == 0
                  && !mod.game.isPlayerDead()
                  && !mod.game.isTransitioning())
               {
                  mod.game.damageTest();
               }
               // M10b：死亡/复活过渡日志（确定性验证用）
               var dead:Boolean = mod.game.isPlayerDead();
               if(dead && !_wasDead)
               {
                  Log.d("RConnectNet: local player died (respawn flow)");
               }
               else if(!dead && _wasDead)
               {
                  Log.d("RConnectNet: local player revived");
                  // 测试钩子：复活后完全治疗（身体部件伤重会挡旅行）
                  if(_autoHeal)
                  {
                     mod.game.healTest();
                  }
               }
               _wasDead = dead;
               var hits:Array = mod.game.scanAndReportDamage();
               if(hits != null && hits.length > 0)
               {
                  link.send(Protocol.make(Protocol.MSG_DAMAGE, {hits: hits}));
                  Log.d("RConnectNet: reported " + hits.length
                     + " damage hits first=" + String(hits[0].id)
                     + "/" + Math.round(Number(hits[0].dmg)));
               }
            }
         }
         else if(mode == HOSTING && server != null)
         {
            broadcastWorldState();
            // M4/M5：宿主每 4 tick（200ms = 5Hz）广播单位快照 + 世界身份
            // M17：不设 units>0 门槛——房间无敌人时也要传瓦片/物品/新生成
            if(_tickCount % 4 == 0 && mod.game != null)
            {
               var usnap:Array = mod.game.readUnitsSnapshot();
               var usMsg:Object = Protocol.make(Protocol.MSG_UNITSYNC,
                  {tick: _tickCount, units: usnap != null ? usnap : [],
                   worldInfo: mod.game.readWorldInfo()});
               // M16：物品（箱/门）状态快照随行广播（对象级重建/破坏同步）
               var olist:Array = mod.game.readObjsSnapshot();
               if(olist != null)
               {
                  usMsg.objs = olist;
               }
               // M17：瓦片破坏差分 + 新生成物品广播
               var tpatch:Array = mod.game.readTilePatch();
               if(tpatch != null)
               {
                  usMsg.tilePatch = tpatch;
               }
               var nspawn:Array = mod.game.readNewObjs();
               if(nspawn != null)
               {
                  usMsg.objSpawn = nspawn;
                  if(!_spawnTxLog)
                  {
                     _spawnTxLog = true;
                     Log.d("RConnectNet: objSpawn tx " + nspawn.length
                        + " first=" + String(nspawn[0].id));
                  }
               }
               // M24：可移动物品（Loot）快照随行广播（稳定键+实时位置）。
               // 空数组也必须发——"缺席"就是移除信号，不发会让 joiner
               // 永远收不到清理指令而重复上报
               var llist:Array = mod.game.readLootSync();
               usMsg.loots = llist != null ? llist : [];
               if(llist != null && !_lootsTxLog)
               {
                  _lootsTxLog = true;
                  Log.d("RConnectNet: loots tx first " + llist.length
                     + " k=" + String(llist[0].k));
               }
               server.broadcast(usMsg);
            }
            // M5c：自动化联测换房（每 15s）
            if(_autoTravel && mod.game != null && _tickCount % 300 == 0)
            {
               mod.game.travelTest();
            }
            // M9：监测客户端化身受击，伤害回传客户端（每 10 tick = 500ms）
            // M10b：客户端已死（快照 sost>=3/hp<=0）时不上报——死亡流程本地处理
            if(mod.game != null && _tickCount % 10 == 0)
            {
               for each(var gp:Object in peers)
               {
                  var ps:Object = gp.snap;
                  var peerDead:Boolean = ps != null
                     && (Number(ps.sost) >= 3 || Number(ps.hp) <= 0);
                  if(peerDead)
                  {
                     continue;
                  }
                  var gdmg:Number = mod.game.scanGhostHp(int(gp.id));
                  if(gdmg > 0 && gp.link != null && gp.link.isOpen)
                  {
                     gp.link.send(Protocol.make(Protocol.MSG_PLAYERDMG,
                        {dmg: gdmg}));
                     Log.d("RConnectNet: relayed " + gdmg
                        + " damage to '" + gp.name + "'");
                  }
               }
            }
            // M6.5：自动化联测——跨地图传送（世界就绪后执行一次；
            // travelToLand 返回 false 时（加载中/已在目标）稍后重试）
            if(_autoTravelLand != "" && !_travelLandDone
               && mod.game != null && mod.game.gg != null
               && _tickCount % 40 == 0)
            {
               if(mod.game.travelToLand(_autoTravelLand))
               {
                  _travelLandDone = true;
               }
            }
            // M11 复现钩子：宿主自毁（确定性触发死亡回城→rbl，
            // 验证加入方跟随到基地的过程）
            if(_autoHostKill && !_hostKillDone
               && mod.game != null && mod.game.gg != null
               && _tickCount > 800 && _tickCount % 20 == 0)
            {
               _hostKillDone = true;
               mod.game.hostKillTest();
            }
            // M6：自动化联测——宿主侧伤害自己的单位（权威死亡→animState 变化）
            if(_autoDamage && mod.game != null && _tickCount % 100 == 0
               && !mod.game.isPlayerDead() && !mod.game.isTransitioning())
            {
               mod.game.damageTest();
            }
            // M10b：确定性验证——宿主直接伤害客户端幽灵化身（每 15s，
            // 伤害量=testGhostDmg；联测设大值触发客户端死亡→复活闭环）
            if(_autoGhostDmg && mod.game != null && _tickCount % 300 == 0
               && _tickCount > 600)
            {
               mod.game.ghostDamageTest();
            }
         }

         if(mod.hud != null)
         {
            mod.hud.refresh();
         }
      }

      // ---- 世界状态广播 -------------------------------------------------

      private function broadcastWorldState():void
      {
         if(server == null || !server.bound)
         {
            return;
         }
         var players:Array = [];
         var selfSnap:Object = mod.game != null ? mod.game.readSnapshot() : null;
         players.push({id: 0, name: myName, snap: selfSnap});
         for each(var p:Object in peers)
         {
            players.push({id: p.id, name: p.name, snap: p.snap});
         }
         var ws:Object = Protocol.make(Protocol.MSG_WORLDSTATE,
            {tick: _tickCount, players: players});
         // M14c：探索迷雾同步——宿主当前房间已探索掩码（readSeenMask 按 loc
         // 引用缓存，换房才重建；加入方同房间点亮一致）
         if(mod.game != null && peers.length > 0 && mod.game.loc != null)
         {
            var seenData:String = mod.game.readSeenMask();
            if(seenData != "")
            {
               ws.seen = {locId: String(GameBridge.probe(mod.game.loc, "id")),
                  cols: int(GameBridge.probeNum(mod.game.loc, "spaceX", 0)),
                  data: seenData};
            }
         }
         server.broadcast(ws);
      }

      private function applyWorldState(players:Array, seenMask:Object = null):void
      {
         if(players == null || mod.game == null)
         {
            return;
         }
         // M14c：宿主的房间探索掩码 → 加入方同房点亮（地图/暗幕一致）
         if(seenMask != null && seenMask.data != undefined)
         {
            mod.game.applySeenMask(String(seenMask.locId),
               int(seenMask.cols), String(seenMask.data));
         }
         var seen:Object = {};
         var next:Array = [];
         for each(var p:Object in players)
         {
            var id:int = int(p.id);
            seen[id] = true;
            if(id == myId)
            {
               continue;
            }
            mod.game.updateRemote(id, p.snap != null ? p.snap : {},
               p.name != undefined ? String(p.name) : "");
            next.push({id: id, name: p.name, snap: p.snap});
         }
         // 清理已消失的远程玩家
         for each(var r:Object in remotes)
         {
            if(!seen[int(r.id)])
            {
               mod.game.removeRemote(int(r.id));
            }
         }
         remotes = next;
      }

      // ---- 工具 --------------------------------------------------------

      private function nextPeerId():int
      {
         var id:int = 1;
         while(findPeer(id) != null)
         {
            id++;
         }
         return id;
      }

      private function findPeer(id:int):Object
      {
         for each(var p:Object in peers)
         {
            if(p.id == id)
            {
               return p;
            }
         }
         return null;
      }

      private function findPeerByLink(link:TcpLink):Object
      {
         for each(var p:Object in peers)
         {
            if(p.link == link)
            {
               return p;
            }
         }
         return null;
      }

      private function removePeerByLink(link:TcpLink):void
      {
         for(var i:int = peers.length - 1; i >= 0; i--)
         {
            if(peers[i].link == link)
            {
               if(mod.game != null)
               {
                  mod.game.removeRemote(int(peers[i].id));
               }
               peers.splice(i, 1);
            }
         }
      }

      /** 状态行文本（HUD 每帧读取）。 */
      public function statusText():String
      {
         var s:String = "RConnect v" + RConnectMod.VERSION
            + " | " + mod.versionInfo.version;
         s += "\nmode: " + mode;
         if(mode == HOSTING)
         {
            s += " (port " + mod.config.getValue("port")
               + ", peers " + peers.length + ")";
         }
         else if(mode == CONNECTED)
         {
            s += " (id " + myId + " of " + hostName + ", remotes "
               + remotes.length + ")";
         }
         else if(mode == JOINING)
         {
            s += " (" + mod.config.getValue("hostIp") + ":"
               + mod.config.getValue("port") + ")";
         }
         if(mode == HOSTING)
         {
            for each(var p:Object in peers)
            {
               s += "\n  " + String(p.name) + " hp=" + snapHp(p.snap);
            }
         }
         else if(mode == CONNECTED)
         {
            for each(var r:Object in remotes)
            {
               s += "\n  " + String(r.name) + " hp=" + snapHp(r.snap);
            }
         }
         if(error != "")
         {
            s += "\nerror: " + error;
         }
         return s;
      }

      private static function snapHp(snap:Object):String
      {
         if(snap == null || snap.hp == undefined)
         {
            return "?";
         }
         return String(Math.round(Number(snap.hp)));
      }
   }
}
