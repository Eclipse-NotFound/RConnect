package
{
   import flash.geom.Point;
   import flash.display.Stage;
   import flash.events.MouseEvent;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import fe.weapon.MSWSmartReplayStep;

   public class MSWSmartWeapons
   {
      private var mod:*;
      public var lock:MSWSmartLock=new MSWSmartLock();
      public var multiLock:MSWSmartMultiLock=new MSWSmartMultiLock();
      private var focus:MSWSmartFocus=new MSWSmartFocus();
      private var inputStage:Stage;
      private var mouseX:Number=NaN,mouseY:Number=NaN;
      private var multiMode:Boolean=false;
      private var lastLoc:*;
      private var lastPlayer:*;
      private var hook:*;
      private var states:Dictionary=new Dictionary(true);
      private var observed:Dictionary=new Dictionary(true);
      private var lastTime:int=0;
      private var hud:MSWSmartHUD=new MSWSmartHUD();
      private var routeCache:Object={};
      private var searches:int=0;
      private var recording:Boolean=false;
      private var replaying:Boolean=false;
      private var history:Array=[];
      private var replayHook:*;
      private var replayOriginals:Dictionary=new Dictionary(true);
      private var motion:MSWSmartMotion=new MSWSmartMotion();
      private var tail:*;
      public function MSWSmartWeapons(m:*)
      {
         mod=m;
      }
      public static function weaponAllowed(w:*):Boolean
      { return w!=null && MSWU.num(w,"skill")==2 && (MSWU.num(w,"tip")==2 || MSWU.num(w,"tip")==3); }
      public function targetAllowed(u:*,w:*):Boolean
      {
         if(w==null || u==null || u===w.gg || !MSWU.has(u,"loc") || u.loc!==w.loc ||
            MSWU.num(u,"hp")<=0 || MSWU.num(u,"sost")>=3 || u.disabled || u.trigDis ||
            MSWSmartExclusions.excludes(u,mod.cfg.smartExclusions))return false;
         if(MSWU.num(u,"fraction")>=1 && MSWU.num(u,"fraction")<=4 && u.fraction!=w.gg.fraction
            && !u.npc && !u.noAgro)return true;
         // Optional cooperative collision receiver, with eligibility owned by
         // the network mod. Old installations have no method and keep the
         // original enemy-only rules. Never relax generic NPC/faction filters.
         if(MSWU.has(u,"rconnectSmartTargetAllowed") && u.rconnectSmartTargetAllowed is Function) {
            try {return u.rconnectSmartTargetAllowed(w.gg)===true;}catch(error:*) {}
         }
         return false;
      }
      private function alivePlayer(w:*):Boolean
      { return w!=null && MSWU.has(w,"gg") && w.gg!=null && MSWU.num(w.gg,"hp")>0 && MSWU.num(w.gg,"sost")<3; }
      private function active(w:*):Boolean
      { return MSWU.inGameplay(w) && !w.catPause && !mod.panel.overlayOpen && w.gg.ggControl; }
      /** Runs before the host ENTER_FRAME, and again after it to observe transitions. */
      public function prepare(w:*):void
      {
         if(w==null || !mod.cfg.smartEnabled || w.loc!==lastLoc || !alivePlayer(w)) return;
         if(w.onPause && !w.godMode)
         {
            if(!recording && !replaying) { recording=true; history=[]; }
         }
         else if(w.onPause && w.godMode && recording)
         {
            recording=false; replaying=true;
            replayOriginals=new Dictionary(true);
            var old:*=w.loc.firstObj;
            while(old!=null) { replayOriginals[old]=true;old=old.nobj; }
            replayHook=new MSWSmartReplayStep(w.gg,function():void { beforeProjectiles(); });
            placeHead(replayHook,w.loc); mod.cfg.diagAdd("smartReplayStart");
         }
         else if(!w.onPause)
         {
            recording=false; replaying=false; history=[];
            replayOriginals=new Dictionary(true);
            if(replayHook!=null && replayHook.in_chain) replayHook.loc.remObj(replayHook);
            replayHook=null;
         }
      }
      public function frame(w:*):void
      {
         try
         {
            mod.cfg.diagSet("smartMotionVersion","1.4-adaptive-radius");
            mod.cfg.diagSet("smartGlassVersion",MSWSmartGlass.VERSION);
            afterProjectiles(); motion.prune();
            var now:int=getTimer(); var dt:Number=lastTime==0?0:Math.min(0.1,(now-lastTime)/1000); lastTime=now;
            if(w.loc!==lastLoc || w.gg!==lastPlayer)
            {
               detach(); lastLoc=w.loc; lastPlayer=w.gg;
               states=new Dictionary(true); observed=new Dictionary(true); clearLocks();
               recording=false;replaying=false;history=[];
            }
            syncMode();
            bindInput(w);
            if(!mod.cfg.smartFocus)focus.clear();
            if(!mod.cfg.smartEnabled || !alivePlayer(w)) { clearLocks(); stopGuidance(); detach(); hide(); return; }
            prepare(w);
            if(!replaying) attach(w);
            if(w.sats!=null && w.sats.active) clearLocks();
            if(!active(w)) { hide(); return; }
            if(!weaponAllowed(w.gg.currentWeapon)) clearLocks();
            else if(multiMode)
            {
               var allowed:Array=[],seen:Array=[];
               for each(var unit:* in w.loc.units)
               {
                  if(!targetAllowed(unit,w)) continue;
                  allowed.push(unit);
                  if(visible(unit,w)) seen.push(unit);
               }
               multiLock.advance(allowed,seen,dt,mod.cfg);
               updateFocus(w);
            }
            else
            {
               if(lock.target!=null && !targetAllowed(lock.target,w)) lock.clear();
               if(lock.candidate!=null && !targetAllowed(lock.candidate,w)) lock.clearCandidate();
               var choice:*=null; var nearest:Number=mod.cfg.smartRadius+0.0001;
               for each(var u:* in w.loc.units)
               {
                  if(!targetAllowed(u,w)) continue;
                  var dx:Number=Math.max(u.X1-w.celX,0,w.celX-u.X2);
                  var dy:Number=Math.max(u.Y1-w.celY,0,w.celY-u.Y2);
                  var distance:Number=Math.sqrt(dx*dx+dy*dy);
                  if(distance<=nearest && visible(u,w))
                  { if(distance<nearest || u===lock.candidate) { choice=u; nearest=distance; } }
               }
               lock.advance(choice,lock.target!=null && visible(lock.target,w),dt,mod.cfg);
            }
            scan(w,false); // Snapshot shots born on a time-stop display frame with no world step.
            draw(w);
         }
         catch(e:*) { mod.cfg.diagSet("smartError","frame:"+e); }
      }
      private function clearLocks():void
      { lock.clear();multiLock.clear();focus.clear(); }
      private function bindInput(w:*):void
      {
         if(inputStage===w.main.stage)return;
         if(inputStage!=null)inputStage.removeEventListener(MouseEvent.MOUSE_MOVE,onMouseMove);
         inputStage=w.main.stage;mouseX=w.cam.celX;mouseY=w.cam.celY;
         if(inputStage!=null)inputStage.addEventListener(MouseEvent.MOUSE_MOVE,onMouseMove,false,0,true);
      }
      private function onMouseMove(event:MouseEvent):void
      {
         var changed:Boolean=event.stageX!=mouseX || event.stageY!=mouseY;
         mouseX=event.stageX;mouseY=event.stageY;
         if(!changed)return;
         try
         {
            var w:*=MSWU.world();
            if(w==null || w.loc!==lastLoc || w.gg!==lastPlayer || !mod.cfg.smartEnabled ||
               !mod.cfg.smartMultiLock || !mod.cfg.smartFocus || !alivePlayer(w) || !active(w) ||
               !weaponAllowed(w.gg.currentWeapon))return;
            focus.aimMoved();
            // Use the event position: Camera.calc has not yet copied this input to w.celX/Y.
            if(w.cam.scaleV>0)updateFocus(w,(mouseX-w.cam.vx)/w.cam.scaleV,(mouseY-w.cam.vy)/w.cam.scaleV);
         }
         catch(e:*) { mod.cfg.diagSet("smartError","focusInput:"+e); }
      }
      private function updateFocus(w:*,x:Number=NaN,y:Number=NaN):MSWSmartLock
      {
         if(!mod.cfg.smartFocus || !multiMode || !weaponAllowed(w.gg.currentWeapon))
         { focus.clear();return null; }
         if(isNaN(x) || isNaN(y))
         {
            if(!(w.cam.scaleV>0))return null;
            x=(w.cam.celX-w.cam.vx)/w.cam.scaleV;y=(w.cam.celY-w.cam.vy)/w.cam.scaleV;
         }
         return focus.select(multiLock.locks,x,y,mod.cfg.smartFocusRadius,function(u:*):Boolean { return targetAllowed(u,w); });
      }
      private function syncMode():void
      {
         if(multiMode==mod.cfg.smartMultiLock) return;
         multiMode=mod.cfg.smartMultiLock;clearLocks();
      }
      private function attach(w:*):void
      {
         if(hook==null) hook=new MSWSmartStep(function():void { beforeProjectiles(); });
         placeHead(hook,w.loc);
      }
      private function placeHead(node:*,loc:*):void
      {
         if(node.in_chain && node.loc===loc && loc.firstObj===node) return;
         if(node.in_chain && node.loc!=null) node.loc.remObj(node);
         node.loc=loc; node.X=node.Y=0;
         loc.addObj(node);
         // Move our own node only; retain every original object's relative order.
         if(loc.firstObj!==node)
         {
            loc.remObj(node);
            var first:*=loc.firstObj;
            node.nobj=first; node.pobj=null; node.in_chain=true;
            if(first!=null) first.pobj=node; else loc.lastObj=node;
            loc.firstObj=node;
         }
      }
      private function detach():void
      {
         afterProjectiles(); motion.clear();
         if(hook!=null && hook.in_chain && hook.loc!=null) hook.loc.remObj(hook);
         if(replayHook!=null && replayHook.in_chain && replayHook.loc!=null) replayHook.loc.remObj(replayHook);
         replayHook=null; recording=false;replaying=false;history=[];
         replayOriginals=new Dictionary(true);
      }
      private function stopGuidance():void
      { for each(var s:Object in states) s.remaining=0; }
      public function beforeProjectiles():void
      {
         try
         {
            afterProjectiles();
            var w:*=MSWU.world();
            if(w==null || w.loc!==lastLoc || !mod.cfg.smartEnabled || !alivePlayer(w)) return;
            prepare(w);
            routeCache={}; searches=0;
            // This callback runs inside the original Location.step, not every display frame.
            scan(w,true);
            // Newborn bullets were appended by player.step. Append a one-use
            // finalizer AFTER them; remove it from inside its own callback so
            // neither Location nor Sandevistan retains a stale next pointer.
            tail=replaying ? new MSWSmartReplayStep(w.gg,afterProjectiles) : new MSWSmartStep(afterProjectiles);
            tail.loc=w.loc; tail.X=tail.Y=0; w.loc.addObj(tail);
         }
         catch(e:*) { afterProjectiles(); mod.cfg.diagSet("smartError","step:"+e); }
      }
      public function afterProjectiles():void
      {
         motion.finish();
         if(tail!=null && tail.in_chain && tail.loc!=null) tail.loc.remObj(tail);
         tail=null;
      }
      private function eligible(b:*,w:*):Boolean
      {
         return b.owner===w.gg && weaponAllowed(b.weap) && b.tipBullet==0 && !b.babah &&
            b.liv>3 && b.flame==0 && b.brakeR==0;
      }
      private function scan(w:*,advance:Boolean):void
      {
         syncMode();
         var valid:Function=function(u:*):Boolean { return targetAllowed(u,w); };
         var focused:MSWSmartLock=!replaying && active(w)?updateFocus(w):null;
         var b:*=w.loc.firstObj; var guard:int=0;
         while(b!=null && guard++<12000)
         {
            if(getQualifiedClassName(b)=="fe.weapon::Bullet" && b.owner===w.gg)
            {
               if(!observed[b])
               {
                  observed[b]=true;
                  var shot:Object=null;
                  if(eligible(b,w) && replaying) shot=replayShot(b);
                  else if(eligible(b,w) && active(w))
                  {
                     var selected:MSWSmartLock=multiMode?(focused!=null?focused:multiLock.pick(valid)):lock;
                     if(selected!=null && selected.target!=null && selected.strength>0 && valid(selected.target))
                        shot={target:selected.target,strength:selected.strength,turn:mod.cfg.smartTurn,turnRadius:mod.cfg.smartTurnRadius,
                           adaptive:mod.cfg.smartAdaptiveRadius,minTurnRadius:mod.cfg.smartMinTurnRadius,
                           remaining:mod.cfg.smartLife,route:[],routeAge:0,goalX:0,goalY:0};
                  }
                  if(shot!=null) { states[b]=shot;b.precision=0;b.miss=0;mod.cfg.diagAdd("smartShots"); }
                  if(recording && eligible(b,w))
                     history.push({used:false,x:b.begx,y:b.begy,id:MSWU.str(b.weap,"id"),dx:b.dx,dy:b.dy,vel:b.vel,
                        shot:shot==null?null:{target:shot.target,strength:shot.strength,turn:shot.turn,turnRadius:shot.turnRadius,
                           adaptive:shot.adaptive,minTurnRadius:shot.minTurnRadius,remaining:shot.remaining}});
               }
               var s:Object=states[b];
               // The time-stop mod pins recorded originals during replay; only
               // recreated player shots actually take a physics step there.
               if(s!=null && advance && !b.babah && b.liv>0 && !(replaying && replayOriginals[b])) guide(b,s,w);
            }
            b=b.nobj;
         }
      }
      private function guide(b:*,s:Object,w:*):void
      {
         if(s.remaining<=0) { motion.remove(b); return; }
         if(!targetAllowed(s.target,w)) { s.remaining=0; motion.remove(b); return; }
         var dt:Number=Math.min(1/30,s.remaining); s.remaining=Math.max(0,s.remaining-dt);
         if(s.remaining<0.000000001) s.remaining=0;
         var tx:Number=(s.target.X1+s.target.X2)/2, ty:Number=(s.target.Y1+s.target.Y2)/2;
         var policy:String=MSWSmartGlass.routeKey(b)+":"+w.loc.destroyOn;
         if(s.routePolicy!==policy){s.route=[];s.routeAge=0;s.routePolicy=policy;}
         if(MSWSmartRoute.clear(w.loc,b.X,b.Y,tx,ty,2,b)) s.route=[{x:tx,y:ty}];
         else if(s.routeAge<=0 || MSWSmartRoute.distance(tx,ty,s.goalX,s.goalY)>32)
         {
            var key:String=int(b.X/24)+","+int(b.Y/24)+":"+int(tx/24)+","+int(ty/24)+":"+policy;
            var resolved:Boolean=true;
            if(routeCache[key]!=null) s.route=routeCache[key].concat();
            else if(searches<4)
            {
               searches++; s.route=MSWSmartRoute.find(w.loc,b.X,b.Y,tx,ty,b);
               routeCache[key]=s.route.concat(); mod.cfg.diagAdd("smartRoutes");
            }
            else resolved=false;
            // Defer to the next step, not the same six-step cohort: otherwise a
            // large volley's later rounds could repeatedly lose the search budget.
            s.routeAge=resolved?6:0; s.goalX=tx; s.goalY=ty;
         }
         s.routeAge--;
         var path:Array=s.route;
         if(path.length==0) { motion.remove(b); return; }
         while(path.length>1 && MSWSmartRoute.clear(w.loc,b.X,b.Y,path[1].x,path[1].y,2,b)) path.shift();
         motion.advance(b,s,path,s.turn*s.strength*dt*Math.PI/180);
         mod.cfg.diagAdd("smartSteps");
      }
      public function inherit(from:*,to:*):void
      {
         motion.remove(from);
         observed[to]=true;
         var s:Object=states[from];
         if(s!=null) { states[to]=s; delete states[from]; s.route=[]; s.routeAge=0; MSWAdaptiveRadius.reset(s); }
      }
      public function snapshot(b:*):Object { return states[b]; }
      private function replayShot(b:*):Object
      {
         var id:String=MSWU.str(b.weap,"id");var best:Object=null;
         for each(var record:Object in history)
         {
            if(record.used || record.id!=id) continue;
            // Sandevistan replays fire events in recording order, but the
            // reconstructed muzzle can shift with pose. Nearest-only matching
            // can steal a later shot's target; position is a tolerance gate.
            if(MSWSmartRoute.distance(record.x,record.y,b.begx,b.begy)<97)
            {best=record;break;}
         }
         if(best==null) { mod.cfg.diagAdd("smartReplayUnmatched");return null; }
         best.used=true;
         if(best.shot==null || MSWSmartExclusions.excludes(best.shot.target,mod.cfg.smartExclusions))return null;
         mod.cfg.diagAdd("smartReplayMatched");
         b.dx=best.dx;b.dy=best.dy;b.vel=best.vel;b.rot=Math.atan2(b.dy,b.dx);
         return {target:best.shot.target,strength:best.shot.strength,turn:best.shot.turn,turnRadius:best.shot.turnRadius,remaining:best.shot.remaining,
            adaptive:best.shot.adaptive,minTurnRadius:best.shot.minTurnRadius,
            route:[],routeAge:0,goalX:0,goalY:0};
      }
      public function visible(u:*,w:*):Boolean
      {
         if((!u.isVis || MSWU.has(u,"invis") && u.invis) && !infraredRevealed(u,w)) return false;
         var a:Point=w.visual.localToGlobal(new Point(u.X1,u.Y1));
         var b:Point=w.visual.localToGlobal(new Point(u.X2,u.Y2));
         var st:*=w.main.stage;
         if(Math.max(a.x,b.x)<0 || Math.max(a.y,b.y)<0 || Math.min(a.x,b.x)>st.stageWidth || Math.min(a.y,b.y)>st.stageHeight) return false;
         var x:Number=(u.X1+u.X2)/2;
         // Match Unit.actions' eye position using the current pose. Its cached
         // eyeX/Y may still belong to the previous position after a teleport.
         var gx:Number=w.gg.X+w.gg.scX*0.25*w.gg.storona, gy:Number=w.gg.Y-w.gg.scY*0.75;
         return MSWSmartGlass.visible(w.loc,gx,gy,x,(u.Y1+u.Y2)/2) || MSWSmartGlass.visible(w.loc,gx,gy,x,u.Y1+3) || MSWSmartGlass.visible(w.loc,gx,gy,x,u.Y2-3);
      }
      private function infraredRevealed(u:*,w:*):Boolean
      {
         if(!MSWU.has(w,"pers") || MSWU.num(w.pers,"infravis")<=0 ||
            !MSWU.has(u,"vis") || u.vis==null || !u.vis.visible || u.vis.alpha<=0.5) return false;
         // These native animate() methods reveal stealth to infravis without
         // clearing isVis/invis. Do not extend this to buried units or turrets.
         var type:String=getQualifiedClassName(u);
         return type=="fe.unit::UnitAlicorn" || type=="fe.unit::UnitBossAlicorn" || type=="fe.unit::UnitBossNecr";
      }
      private function hide():void { hud.visible=false; }
      private function draw(w:*):void
      {
         if(multiMode) hud.renderMany(w,multiLock.locks,mod.cfg.smartHudSize);
         else hud.render(w,lock,mod.cfg.smartHudSize);
      }
   }
}
