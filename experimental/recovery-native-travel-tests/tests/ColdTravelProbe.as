package {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.events.Event;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Optional exact callback-entry stamps plus honest frame/render bounds.
    * Wrapping never supplies a decision and calls the real bridge exactly once.
    * No random seed, prepare message or native loading state is written. */
   public final class ColdTravelProbe {
      private var mod:Object,role:String,solo:Boolean,cls:Object,original:Function,wrapper:Function;
      private var active:Boolean=false,round:int,target:String,rows:Array=[];
      private var beginWall:Number=0,exitWall:Number=0,enterWall:Number=0,constructWall:Number=0,landWall:Number=0;
      private var previousLand:Object,adopted:Boolean=false,lastExit:int=-1,lastWait:Boolean=false;
      private var nativeFrames:int=0,coverFrames:int=0,errors:Object={},lastRender:int=0,maxGap:int=0;
      public var bridgeAvailable:Boolean=false;
      public function ColdTravelProbe(m:Object,name:String,isSolo:Boolean) {
         mod=m;role=name;solo=isSolo;cls=mod.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Game");
         bridgeAvailable="rconnectTravelBridge" in cls&&cls.rconnectTravelBridge is Function;
         if(bridgeAvailable) {
            original=cls.rconnectTravelBridge;
            wrapper=function(phase:String,g:Object,info:Object):Object {
               if(active&&String(g.curLandId)==target) {
                  if(phase=="adopt") {enterWall=new Date().time;mark("native-enter-call",{target:g.curLandId});}
                  if(phase=="announce") {constructWall=new Date().time;mark("native-before-constructor-call",{info:info});}
               }
               var result:Object=original(phase,g,info);
               if(active&&phase=="adopt"&&result!=null) {
                  adopted=true;mark("production-plan-adopted",{target:result.curLandId,firstVisit:result.firstVisit,
                     constructorLevel:result.constructorLevel,entryCoord:result.entryCoord});
               }
               return result;
            };
            cls.rconnectTravelBridge=wrapper;
         }
         mod.stage.addEventListener(Event.ENTER_FRAME,frame,false,-2000000000);
         mod.stage.addEventListener(Event.RENDER,render,false,-2147483648);
      }
      public function get sawExit():Boolean{return exitWall>0;}
      public function begin(n:int,id:String,wall:Number):void {
         round=n;target=id;beginWall=wall;active=true;rows=[];errors={};
         exitWall=enterWall=constructWall=landWall=0;adopted=false;lastExit=-1;lastWait=false;
         nativeFrames=coverFrames=lastRender=maxGap=0;previousLand=mod.game.world.land;
         mark("armed",{bridgeAvailable:bridgeAvailable,solo:solo});
      }
      private function mark(kind:String,detail:Object):void {
         var item:Object={role:role,round:round,target:target,kind:kind,wallMs:new Date().time,t:getTimer(),detail:detail};
         rows.push(item);Log.d("COLD NATIVE TRAVEL "+JSON.stringify(item));
      }
      private function require(ok:Boolean,label:String):void {
         if(!ok&&!errors[label]){errors[label]=true;Log.d("COOP FAIL cold-fixed-loading "+label+" round="+round);}
      }
      private function frame(e:Event):void {
         if(!active)return;var w:Object=mod.game.world;
         if(w==null)return;
         var count:int=int(w.t_exit);
         if(count>0&&exitWall==0){exitWall=new Date().time;mark("native-exit-first-frame",{exit:count,frameBound:true});}
         // Only phase boundaries; never log all 100 exit-counter ticks.
         var band:int=count>20?2:count>0?1:0;
         if(band!=lastExit){lastExit=band;mark("native-exit-band",{band:band,exit:count});}
         if(w.land!==previousLand) {
            previousLand=w.land;
            if(w.land!=null&&String(w.land.act.id)==target)landWall=new Date().time;
            mark("land-visible-to-frame-observer",{id:w.land==null?null:w.land.act.id,frameBound:true,
               notConstructorEnd:true});
         }
      }
      private function render(e:Event):void {
         if(!active)return;var w:Object=mod.game.world;if(w==null)return;
         var now:int=getTimer();if(lastRender>0)maxGap=Math.max(maxGap,now-lastRender);lastRender=now;
         var native:DisplayObject=w.vwait as DisplayObject;
         if(native==null)return;
         var visible:Boolean=native.visible&&native.stage!=null;
         if(visible)nativeFrames++;
         if(visible!=lastWait){lastWait=visible;mark("native-loading-render",{visible:visible,renderBound:true});}
         var visual:DisplayObject=w.visual as DisplayObject;
         if(visual==null||visual.parent==null)return;
         inspect(visual.parent.getChildByName("rconnect-room-entry") as DisplayObjectContainer,native);
         var sats:DisplayObjectContainer=w.vsats as DisplayObjectContainer;
         if(sats!=null&&sats.visible)inspect(sats.getChildByName("rconnect-room-entry-sats") as DisplayObjectContainer,native);
      }
      private function inspect(cover:DisplayObjectContainer,native:DisplayObject):void {
         if(cover==null||!cover.visible||cover.stage==null)return;coverFrames++;
         var asset:Object=cover.getChildByName("rconnect-native-loading");
         require(cover.numChildren==1&&asset!=null,"handoff contains only one native loading asset, no custom text");
         if(asset==null)return;
         require(getQualifiedClassName(asset)==getQualifiedClassName(native),"handoff artwork uses the native asset class");
         require(asset!==native&&native.parent!==cover,"native loader retains its original ownership");
         require(asset.visible,"native loading copy is visible");
         require(asset.progres.text==Object(native).progres.text,"native localized loading text agrees");
         require(asset.skill.currentFrame==Object(native).skill.currentFrame,"native illustration agrees");
         require(asset.story.visible==Object(native).story.visible,"native story visibility agrees");
      }
      public function complete():Object {
         mark("control-flags-ready-frame",{frameBound:true,x:mod.game.gg.X,y:mod.game.gg.Y});
         require(nativeFrames>0,"native loading was observed on the render boundary");
         active=false;
         return {bridgeAvailable:bridgeAvailable,adoptedPlan:adopted,requestedWall:beginWall,
            exitFirstFrameWall:exitWall,nativeEnterWall:enterWall,constructorBeforeWall:constructWall,
            landFirstObservedWall:landWall,nativeFrames:nativeFrames,coverFrames:coverFrames,
            maxRenderGap:maxGap,failures:errors,rows:rows,
            constructorEndMeasured:false,observedUiOnly:true};
      }
      public function dispose():void {
         active=false;mod.stage.removeEventListener(Event.ENTER_FRAME,frame);mod.stage.removeEventListener(Event.RENDER,render);
         if(bridgeAvailable&&cls.rconnectTravelBridge===wrapper)cls.rconnectTravelBridge=original;
      }
   }
}
