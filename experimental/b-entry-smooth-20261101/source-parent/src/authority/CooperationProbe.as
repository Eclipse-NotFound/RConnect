package authority {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.getQualifiedClassName;
   /** Actual join inputs open native doors/containers; host owns the single loot. */
   public final class CooperationProbe extends Probe {
      private var tick:uint=0,ready:Boolean=false,phase:int=0,door:Object,box:Object,bonus:Object;
      private var floorY:Number=0,initial:Array=[],xp:Array=[],key:uint=0;
      private var joinLootSeen:Boolean=false,doorOpenSeen:Boolean=false,doorClosedSeen:Boolean=false,joinReady:Boolean=false;
      private var sentStage:int=0;
      private var generated:int=0,loose:Object;
      private var begin:int=-1;
      private var doorRefs:Object={},doorSamples:int=0,doorWrong:int=0,doorPoses:Object={},doorObserved:Boolean=false;
      private var doorFirst:Object;
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
         if(!host && value.type=="door-reference")doorRefs[value.tick]=value;
      }
      private function doorPixels(vis:DisplayObject,bounds:Array):uint {
         var bitmap:BitmapData=new BitmapData(bounds[2],bounds[3],true,0);
         bitmap.draw(vis,new Matrix(1,0,0,1,-bounds[0],-bounds[1]));
         var hash:uint=2166136261;for each(var p:uint in bitmap.getVector(bitmap.rect)){hash^=p;hash*=16777619;}
         bitmap.dispose();return hash;
      }
      private function doorSource(s:HostSession):void {
         if(door==null || begin<0 || s.runtime.tick-begin>122)return;
         var v:DisplayObject=door.vis,b:Rectangle=v.getBounds(v),m:Matrix=v.transform.matrix;
         var bounds:Array=[Math.floor(b.x),Math.floor(b.y),Math.max(1,Math.ceil(b.right)-Math.floor(b.x)),Math.max(1,Math.ceil(b.bottom)-Math.floor(b.y))];
         s.link.send({type:"door-reference",tick:s.runtime.tick,key:s.sceneId(door),bounds:bounds,
            pixels:doorPixels(v,bounds),matrix:[m.a,m.b,m.c,m.d,m.tx,m.ty],
            frame:v is MovieClip?MovieClip(v).currentFrame:0,dead:door.dead});
      }
      private function doorConfirmed(f:Object):void {
         var ref:Object=doorRefs[f.tick];if(ref==null)return;delete doorRefs[f.tick];++doorSamples;
         var rec:Object=RConnectMod.instance.replica.scene.objects[ref.key],ok:Boolean=rec!=null;
         var confirmed:Object=null;
         for each(var state:Object in f.scene.objects)if(state.key==ref.key){confirmed=state;break;}
         if(ok) {
            var v:DisplayObject=rec.object.vis,m:Matrix=v.transform.matrix;
            var matrix:Array=[m.a,m.b,m.c,m.d,m.tx,m.ty];
            // Replay objects deliberately use inert fe.Obj wrappers, which
            // have no Box.dead field. Check confirmed Box state and rendered
            // pixels independently instead of invoking nonexistent behavior.
            ok=!ref.dead && confirmed!=null && NativeFields.get(confirmed,"dead")===false && v.parent!=null &&
               (v is MovieClip?MovieClip(v).currentFrame:0)==ref.frame && doorPixels(v,ref.bounds)==uint(ref.pixels);
            for(var i:int=0;i<6;i++)ok=ok && Math.abs(matrix[i]-ref.matrix[i])<.001;
         }
         doorPoses[ref.pixels]=true;
         if(!ok){++doorWrong;if(doorFirst==null)doorFirst={tick:f.tick,key:ref.key,missing:rec==null,reference:ref};}
      }
      public function CooperationProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         if(host || !joinReady)return frame;
         frame.probeStart=begin;
         frame.aimX=tick<110?620:450;frame.aimY=floorY-(tick<110?35:12);
         if(sentStage<3 && tick>=[30,75,125][sentStage]){frame.buttons=Commands.ACTION;++sentStage;}
         if(tick>=125 && tick<175)frame.buttons=Commands.ACTION;
         // Request the loose items through the same cursor and native pickup key.
         if(tick>=180 && tick<300 && loose!=null) {frame.buttons=Commands.ACTION;frame.aimX=loose.x;frame.aimY=loose.y-loose.h/2;}
         return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            if(!doorObserved){doorObserved=true;replica.confirmed=doorConfirmed;}
            var frame:Object=replica.lastFrame;if(begin<0)begin=frame.tick;tick=frame.tick-begin;floorY=frame.players[1].y;joinReady=true;
            loose=null;for each(var effect:Object in frame.scene.effects)if(effect.loot!=null && effect.loot.id=="kofe")loose=effect.loot;
            for each(var o:Object in frame.scene.objects) {
               if(NativeFields.get(o,"id")=="door1b" && o.inter!=null) {
                  if(o.inter.open)doorOpenSeen=true;
                  else if(doorOpenSeen)doorClosedSeen=true;
               }
            }
            if(frame.scene.effects.length>0)joinLootSeen=true;
            if(tick>365) {
               check(doorOpenSeen && doorClosedSeen,"join sees native reinforced door open and close from its own input");
               var poses:int=0;for(var pose:String in doorPoses)++poses;
               // Box.setDoor uses gotoAndStop("open"/"close"); this native
               // reinforced door has two poses, no intermediate swing frames.
               check(doorSamples>40 && doorWrong==0 && poses>=2,
                  "reinforced door preserves every sampled native animation pose and pixel while remaining intact",
                  {samples:doorSamples,wrong:doorWrong,distinctPoses:poses,first:doorFirst});
               check(joinLootSeen,"join receives native transient and loose-item displays");
               check(access.world.invent.items.kofe.kol==frame.character.inventory.items.kofe && access.world.invent.items.kofe.kol>=3,
                  "join bag displays its confirmed picked-up items",{local:access.world.invent.items.kofe.kol,confirmed:frame.character.inventory.items.kofe});
               check(access.world.sats.od==frame.character.sats.od,"join HUD uses its own authoritative action points");
               SceneChecks.picture(access,"cooperation-confirmed.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         tick=session.runtime.tick;
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1],room:Object=b.unit.loc;
         if(!ready) {
            ready=true;floorY=ProbeArena.floor(room);
            var publish:Function=session.runtime.afterStep;
            session.runtime.afterStep=function():void{doorSource(session);publish();};
            access.scope.run(a.context,function():void {a.unit.setLocPos(200,floorY);});
            access.scope.run(b.context,function():void {b.unit.setLocPos(500,floorY);});
            var Box:Class=access.definition("fe.loc.Box"),Bonus:Class=access.definition("fe.loc.Bonus");
            access.scope.run(b.context,function():void {
               door=new Box(room,"door1b",620,floorY,<obj lock="0" mine="0"/>,null);
               room.addObj(door);room.objs.push(door);door.addVisual();door.inter.setAct("lock",0);door.inter.setAct("open",0);
               box=new Box(room,"case",450,floorY,<obj cont="custom" lock="0" mine="0"><item id="kofe" kol="3"/></obj>,null);
               room.addObj(box);room.objs.push(box);box.addVisual();box.inter.setAct("lock",0);
               bonus=new Bonus(room,"xp",500,floorY-50);room.bonuses.push(bonus);
            });
            room.kolXp=room.maxXp=1;room.unXp=123;
            initial=[a.unit.invent.items.kofe.kol,b.unit.invent.items.kofe.kol];xp=[a.unit.pers.xpCur,b.unit.pers.xpCur];
            return;
         }
         if(begin<0)return;tick-=begin;
         if(tick>52 && phase==0){phase=1;check(door.inter.open && !door.dead,"join action opens actual native reinforced door without destroying it");}
         if(tick>120 && phase==1){phase=2;check(!door.inter.open && !door.dead,"second join action closes the same intact native door",NativeFields.capture(door.inter));}
         if(tick>155 && phase==2) {
            phase=3;var n:int=0,o2:Object=room.firstObj;
            while(o2!=null){if(getQualifiedClassName(o2)=="fe.loc::Loot" && o2.item.id=="kofe")n+=o2.item.kol;o2=o2.nobj;}
            generated=n+int(b.unit.invent.items.kofe.kol-initial[1]);
            check(box.inter.cont=="empty" && generated>=3,
               "join opening native container consumes its contents once and produces real drops",{cont:box.inter.cont,ground:n,picked:b.unit.invent.items.kofe.kol-initial[1]});
            access.scope.run(b.context,function():void {b.unit.setLocPos(450,floorY);});
         }
         if(tick>305 && phase==3) {
            phase=4;
            check(generated>=3 && a.unit.invent.items.kofe.kol==initial[0] && b.unit.invent.items.kofe.kol==initial[1]+generated,
               "one-copy pickup credits the joining player only",{host:a.unit.invent.items.kofe.kol,join:b.unit.invent.items.kofe.kol,generated:generated,initial:initial});
            room.addObj(bonus);bonus.addVisual();
            access.scope.run(b.context,function():void {b.unit.setLocPos(500,floorY);});
         }
         if(tick>360 && phase==4) {
            phase=5;
            check(bonus.sost==2 && room.kolXp==0 && a.unit.pers.xpCur>xp[0] && b.unit.pers.xpCur>xp[1],
               "join activates a single XP point and both native characters gain experience",{state:bonus.sost,remaining:room.kolXp,before:xp,after:[a.unit.pers.xpCur,b.unit.pers.xpCur]});
            check(access.world.gg===a.unit && access.scope.depth==0,"interaction and pickup restore host character ownership");
         }
         if(tick>380)finish();
      }
   }
}
