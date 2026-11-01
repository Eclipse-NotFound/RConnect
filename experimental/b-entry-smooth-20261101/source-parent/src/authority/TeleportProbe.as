package authority {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   /** Real Q hold/release, native charge/collision/mana and native arrival parts.
    * Source observations are sampled before the production confirmation. */
   public final class TeleportProbe extends Probe {
      private static const CASES:Array=["short","long","reverse","blocked","mana","tap","cooldown","relocate","pause","sats","redraw"];
      private var phase:int=-1,begin:int=-1,peerReady:int=-1,ending:int=-1,sent:int=-1,owner:int=0;
      private var ready:Boolean=false,waiting:Boolean=false,report:Object,refs:Object={},counts:Object;
      private var fy:Number,fromX:Number,toX:Number,manaBefore:Number,initialEpoch:uint,charge:int=0;
      private var arrivals:Dictionary,arrivalCount:int=0,arrivalSamples:int=0,arrivalFrames:Object={};
      private var relocated:Boolean=false,redrawn:Boolean=false,paused:Boolean=false,closed:Boolean=false,pauseAt:int=0;
      private var confirmedPauseAt:int=0;
      private var pauseState:String,still:Boolean=true,pauseSamples:int=0,previousNativeX:Number=NaN,teleported:Boolean=false;
      public function TeleportProbe(a:NativeAccess,h:Boolean){super(a,h);}
      private function kind():String{return CASES[int(phase/2)];}
      private function succeeds():Boolean{return ["short","long","reverse","pause","sats","redraw"].indexOf(kind())>=0;}
      override public function message(v:Object):void {
         if(host && v.type=="teleport-ready")peerReady=v.phase;
         if(host && v.type=="teleport-report")report=v;
         if(!host && v.type=="teleport-phase") {
            phase=v.phase;owner=v.owner;fy=v.floor;fromX=v.from;toX=v.to;begin=ending=-1;refs={};
            counts={samples:0,position:0,arrivals:0,missing:0,pose:0,pixels:0,intermediate:0};
            paused=closed=redrawn=false;pauseSamples=0;pauseState=null;still=true;confirmedPauseAt=0;
         }
         if(!host && v.type=="teleport-go")begin=v.tick;
         if(!host && v.type=="teleport-reference")refs[v.presentation]=v;
         if(!host && v.type=="teleport-end")ending=v.tick;
         if(!host && v.type=="teleport-finish")finish();
      }
      override public function input(f:Object,s:HostSession):Object {
         f.buttons=0;f.actions=[];
         if(phase<0)return f;
         f.aimX=toX;f.aimY=fy-39;
         if(begin<0)return f;
         var elapsed:int=(host?s.runtime.tick:RConnectMod.instance.replica.lastTick)-begin;
         if((host?0:1)==owner && kind()!="relocate" && elapsed>=8 && elapsed<(kind()=="tap"?11:52))f.buttons=Commands.TELE;
         return f;
      }
      private function start(s:HostSession,index:int):void {
         phase=index;owner=phase%2;begin=peerReady=-1;waiting=false;report=null;charge=arrivalCount=arrivalSamples=0;
         arrivals=new Dictionary(true);arrivalFrames={};relocated=teleported=false;previousNativeX=NaN;
         fy=ProbeArena.floor(s.actors[0].unit.loc);fromX=kind()=="reverse"?480:320;
         toX=fromX+(kind()=="long"?640:kind()=="reverse"?-80:80);
         var room:Object=s.actors[0].unit.loc;room.base=false;room.portOn=true;room.sky=false;access.world.black=false;
         if(kind()=="blocked")for(var y:int=int((fy+1)/40)-3;y<int((fy+1)/40);y++) {
            var t:Object=room.space[int(toX/40)][y];t.phis=1;t.opac=1;t.front="A";
         }
         for each(var a:PlayerActor in s.actors)access.scope.run(a.context,function():void {
            var g:Object=a.unit;g.dropTeleObj();g.setLocPos(a.id==owner?fromX:160,fy);g.dx=g.dy=0;
            g.invulner=true;g.ggControl=true;g.t_culd=0;g.t_port=0;g.mana=g.maxmana=10000;g.dmana=0;
            g.pers.recMana=g.pers.recManaMin=0;g.pers.portPoss=g.pers.spellsPoss=1;g.pers.portTime=25;
            g.pers.portMagic=950;g.pers.portMana=25;g.pers.portDown=300;g.pers.spellDown=g.pers.allDManaMult=1;
            if(a.id==owner){if(kind()=="mana")g.mana=0;if(kind()=="cooldown")g.t_culd=10000;}
         });
         var caster:Object=s.actors[owner].unit;manaBefore=caster.mana;initialEpoch=access.positionEpoch(caster);
         s.pause.policyMenus=kind()=="pause";
         s.pause.policySats=kind()=="sats";
         s.link.send({type:"teleport-phase",phase:phase,owner:owner,floor:fy,from:fromX,to:toX});
      }
      private function pixels(clip:DisplayObject,bounds:Array):uint {
         var image:BitmapData=new BitmapData(bounds[2],bounds[3],true,0);
         image.draw(clip,new Matrix(1,0,0,1,-bounds[0],-bounds[1]));
         var h:uint=2166136261;for each(var pixel:uint in image.getVector(image.rect))h=uint((h^pixel)*16777619);
         image.dispose();return h;
      }
      private function source(s:HostSession):void {
         if(begin<0 || waiting)return;
         var g:Object=s.actors[owner].unit,parts:Array=[];charge=Math.max(charge,g.t_port);
         if(isFinite(previousNativeX) && g.X!=previousNativeX && access.positionEpoch(g)>initialEpoch)teleported=true;
         previousNativeX=g.X;
         for(var o:Object=g.loc.firstObj;o!=null;o=o.nobj)if(o.vis!=null && getQualifiedClassName(o.vis)=="visualTele") {
            if(!arrivals[o]){arrivals[o]=true;++arrivalCount;}
            ++arrivalSamples;arrivalFrames[o.vis.currentFrame]=true;
            var r:Rectangle=o.vis.getBounds(o.vis),bounds:Array=[Math.floor(r.x),Math.floor(r.y),Math.max(1,Math.ceil(r.right)-Math.floor(r.x)),Math.max(1,Math.ceil(r.bottom)-Math.floor(r.y))];
            parts.push({id:s.sceneId(o),layer:o.sloy,x:o.vis.x,y:o.vis.y,frame:o.vis.currentFrame,alpha:o.vis.alpha,visible:o.vis.visible,
               bounds:bounds,pixels:pixels(o.vis,bounds)});
         }
         s.link.send({type:"teleport-reference",phase:phase,tick:s.runtime.tick,presentation:s.presentations+1,x:g.X,y:g.Y,parts:parts});
      }
      private function applied(f:Object):void {
         var ref:Object=refs[f.presentation];if(ref==null || ref.phase!=phase)return;delete refs[f.presentation];++counts.samples;
         var r:ClientReplica=RConnectMod.instance.replica,g:Object=displayedPlayer(owner);
         if(g==null || Math.abs(g.X-ref.x)>.06 || Math.abs(g.Y-ref.y)>.06)++counts.position;
         for each(var p:Object in ref.parts) {
            ++counts.arrivals;var record:Object=r.scene.effects.records[p.id],v:DisplayObject=record==null?null:record.clip;
            if(v==null || v.parent!==access.world.grafon.visObjs[p.layer]){++counts.missing;continue;}
            if(Math.abs(v.x-p.x)>.06 || Math.abs(v.y-p.y)>.06 || !(v is MovieClip) || MovieClip(v).currentFrame!=p.frame ||
               Math.abs(v.alpha-p.alpha)>.005 || v.visible!=p.visible) {
               ++counts.pose;if(counts.pose==1)Log.write("teleport-first-pose-diff",{tick:f.tick,presentation:f.presentation,expected:p,
                  actual:{x:v.x,y:v.y,frame:v is MovieClip?MovieClip(v).currentFrame:-1,alpha:v.alpha,visible:v.visible}});
            }
            if(pixels(v,p.bounds)!=uint(p.pixels))++counts.pixels;
         }
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(r==null || r.displayFrame==null)return;
            if(!ready){ready=true;r.confirmed=applied;}
            if(phase>=0 && sent!=phase){sent=phase;RConnectMod.instance.link.send({type:"teleport-ready",phase:phase});}
            var shown:Object=displayedPlayer(owner);
            if(begin>=0 && counts.samples>0 && succeeds() && shown!=null) {
               var x:Number=shown.vis.x;
               if(Math.abs(x-fromX)>.06 && Math.abs(x-toX)>.06)++counts.intermediate;
            }
            if(kind()=="redraw" && counts.arrivals>=3 && !redrawn){redrawn=true;access.world.redrawLoc();}
            if((kind()=="pause" || kind()=="sats") && counts.arrivals>0 && !paused){
               paused=true;pauseAt=getTimer();
               if(kind()=="sats")access.world.sats.onoff(1);else access.world.pip.onoff(5);
            }
            if(paused && !closed && r.displayFrame.paused && shown!=null) {
               if(confirmedPauseAt==0)confirmedPauseAt=getTimer();
               var parts:Array=[];for each(var fx:Object in r.displayFrame.scene.effects)if(fx.clip=="visualTele")parts.push(fx);
               var now:String=JSON.stringify({tick:r.displayFrame.tick,x:shown.X,visual:shown.vis.osn.currentFrame,arrivals:parts});
               if(pauseState==null)pauseState=now;else still=still && pauseState==now;++pauseSamples;
            }
            if(paused && !closed && confirmedPauseAt>0 && getTimer()-confirmedPauseAt>=1200){closed=true;if(kind()=="sats")access.world.sats.onoff(-1);else access.world.pip.onoff(-1);}
            if(ending>=0 && r.displayFrame.tick>=ending) {
               check(counts.samples>100 && counts.position==0,"native teleport position confirmed without a second cast "+kind()+" owner "+owner,counts);
               check(counts.missing==0 && counts.pose==0 && counts.pixels==0 && (succeeds()?counts.arrivals>3:counts.arrivals==0),
                  "native arrival lifetime and frames reproduce once "+kind()+" owner "+owner,counts);
               if(succeeds())check(counts.intermediate==0,"teleport never renders a fabricated in-between body position",counts);
               if(kind()=="pause" || kind()=="sats")check(pauseSamples>3 && still && closed,"native "+kind()+" pause holds teleport body and arrival playback and resumes it",{samples:pauseSamples});
               if(kind()=="redraw")check(redrawn,"native room display rebuild occurs during arrival playback");
               RConnectMod.instance.link.send({type:"teleport-report",phase:phase});ending=-1;
            }return;
         }
         if(s==null || !s.active)return;
         if(!ready){ready=true;var publish:Function=s.runtime.afterStep;s.runtime.afterStep=function():void{source(s);publish();};start(s,0);return;}
         if(begin<0 && peerReady==phase){begin=s.runtime.tick;s.link.send({type:"teleport-go",tick:begin});}
         if(begin<0)return;
         var g:Object=s.actors[owner].unit,elapsed:int=s.runtime.tick-begin;
         if(kind()=="relocate" && elapsed>=35 && !relocated){relocated=true;g.setPos(toX,fy);g.setVisPos();}
         if(elapsed>=180 && !waiting) {
            waiting=true;var expected:Number=succeeds() || kind()=="relocate"?toX:fromX;
            check(Math.abs(g.X-expected)<.06,"native Q success/rejection retains expected position "+kind()+" owner "+owner,{x:g.X,wanted:expected,charge:charge});
            check(succeeds()?teleported && access.positionEpoch(g)==initialEpoch+1 && g.mana<manaBefore:
               access.positionEpoch(g)==initialEpoch && g.mana==manaBefore,"native cast spends mana and changes discontinuity identity only on success "+kind(),{before:manaBefore,after:g.mana});
            var frames:int=0;for(var key:String in arrivalFrames)++frames;
            check(succeeds()?arrivalCount==1 && arrivalSamples>3 && frames>1:arrivalCount==0,
               "exactly one authored arrival follows a successful cast; rejected input and relocation create none",{arrivals:arrivalCount,samples:arrivalSamples,frames:frames});
            s.link.send({type:"teleport-end",tick:s.runtime.tick});
         }
         if(waiting && report!=null && report.phase==phase) {
            if(phase+1<CASES.length*2)start(s,phase+1);
            else {s.pause.policyMenus=s.pause.policySats=false;s.link.send({type:"teleport-finish"});finish();}
         }
      }
   }
}
