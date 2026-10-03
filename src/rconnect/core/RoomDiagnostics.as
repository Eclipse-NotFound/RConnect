package rconnect.core {
   import flash.events.Event;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;

   /** Bounded, read-only evidence for hidden-room transitions. Does not repair
    * pointers or force player visibility, which would hide the original fault. */
   public class RoomDiagnostics {
      private var mod:RConnectMod;
      private var previous:Object,pending:Object;
      private var episodes:int=0,errors:int=0;
      private function key(room:Object):String {return room==null?"missing":mod.game.roomKey(room);}
      public function RoomDiagnostics(m:RConnectMod) {
         mod=m;m.stage.addEventListener(Event.ENTER_FRAME,tick,false,-12000,true);
      }
      private function tick(e:Event):void {
         try {
            var s:Session=mod.session,g:GameBridge=mod.game,now:int=getTimer();
            if(s.mode!=Session.CONNECTED && !(s.mode==Session.HOSTING && s.peers.length>0))
               {previous=null;pending=null;return;}
            if(g.loc==null || g.gg==null || g.world==null)return;
            if(previous!==g.loc) {
               if(previous!=null && previous.land===g.loc.land && episodes<32
                  && (int(previous.landZ)>0 || int(g.loc.landZ)>0)) {
                  pending={id:++episodes,from:g.roomKey(previous),to:g.roomKey(),at:now,settled:false};
                  record("changed");
               }
               previous=g.loc;
            }
            if(pending==null)return;
            if(!pending.settled && s.rooms.ready && !s.rooms.busy) {
               pending.settled=true;record("settled");
            }
            if(now-int(pending.at)>=2000) {record("after-2s");pending=null;}
         } catch(error:Error) {
            pending=null;if(errors++<2)Log.d("RConnectRoomTrace: failed "+error);
         }
      }
      private function record(phase:String):void {
         var g:GameBridge=mod.game,w:Object=g.world,u:Object=g.gg,room:Object=g.loc;
         var vis:Object=GameBridge.probe(u,"vis"),osn:Object=GameBridge.probe(vis,"osn");
         var linked:Dictionary=new Dictionary(),node:Object=room.firstObj,n:int=0;
         while(node!=null && !linked[node] && n<4096) {linked[node]=true;n++;node=node.nobj;}
         var problems:Array=[],alive:int=0,dead:int=0;
         for each(var unit:Object in room.units) {
            // Collision receivers intentionally belong to units only, not the
            // native simulation/display chain. They are not orphan enemies.
            if(unit===u || unit is MirrorHitUnit || getQualifiedClassName(unit)=="fe.unit::VirtualUnit"
               || Number(unit.fraction)>=100)continue;
            if(Number(unit.sost)<3 && Number(unit.hp)>0)alive++;else dead++;
            if(problems.length<8 && (unit.loc!==room || (!linked[unit] && Number(unit.sost)<4)))
               problems.push({id:String(unit.id),sost:unit.sost,hp:unit.hp,linked:linked[unit]===true,room:key(unit.loc)});
         }
         Log.d("RConnectRoomTrace: "+JSON.stringify({phase:phase,id:pending.id,from:pending.from,to:pending.to,
            role:mod.session.mode,term:mod.session.rooms.term,busy:mod.session.rooms.busy,owner:mod.session.rooms.authority,
            logical:g.roomKey(),rendered:key(w.grafon.loc),playerRoom:key(u.loc),
            worldRoom:key(w.loc),landRoom:key(w.land.loc),
            playerIsWorld:w.gg===u,playerIsLand:w.land.gg===u,playerLinked:linked[u]===true,
            control:u.ggControl,disabled:u.disabled,hp:u.hp,sost:u.sost,tDie:w.t_die,
            x:u.X,y:u.Y,bodyStage:GameBridge.probe(vis,"stage")===mod.stage,
            bodyVisible:GameBridge.probe(vis,"visible"),bodyAlpha:GameBridge.probe(vis,"alpha"),
            innerVisible:GameBridge.probe(osn,"visible"),bodyPose:GameBridge.probe(osn,"currentLabel"),
            pause:w.onPause,pip:GameBridge.probe(w.pip,"active"),sats:GameBridge.probe(w.sats,"active"),
            alive:alive,dead:dead,chainCycle:node!=null,unitProblems:problems}));
      }
   }
}
