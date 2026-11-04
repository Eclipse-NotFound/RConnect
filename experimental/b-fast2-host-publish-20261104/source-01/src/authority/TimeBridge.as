package authority {
   import flash.display.DisplayObjectContainer;
   import flash.utils.getTimer;
   /** One host clock for both players and occupied rooms. No local join clock. */
   public final class TimeBridge {
      private var api:Object,access:NativeAccess,host:HostSession,settings:Object,source:Object;
      private var oldHit:Function,ending:Boolean=false,credit:Number=0,slowCredit:Number=0;
      private var cooldowns:Array=[0,0];
      public var phase:String="idle",cycle:uint=0,recorded:int=0,replayed:int=0,initiator:int=-1;
      public var hits:DeferredHits;
      public var history:TimeHistory;
      public function TimeBridge(main:Object,access:NativeAccess,session:String,role:String) {
         this.access=access;
         var root:DisplayObjectContainer=main as DisplayObjectContainer;
         var carrier:Object=root==null?null:root.getChildByName("SandyAuthorityAPI");
         var entry:Object=NativeAccess.get(carrier,"authorityAPI");
         if(entry==null || entry.version!==1 || !(entry.attach is Function))throw new Error("Pinned independent Sandevistan B API unavailable");
         api=entry.attach({version:1,session:session,role:role,submit:RConnectMod.instance.requestTimeAction});
         if(api==null || api.version!==1 || !(api.profile is Function) || !(api.present is Function) || !(api.detach is Function))throw new Error("Sandevistan B API mismatch");
         Log.write("time-attached",{role:role,version:api.version});
      }
      public function bind(value:HostSession):void {
         host=value;hits=new DeferredHits(host);
         var unit:Class=access.definition("fe.unit.Unit");oldHit=unit["rconnectDeferDamage"];
         if(oldHit!=null)throw new Error("Native deferred damage seam already occupied");
         unit["rconnectDeferDamage"]=defer;
      }
      public function execute(actor:PlayerActor):Boolean {
         if(host==null || host.pause.paused || actor.unit.hp<=0)return false;
         if(phase=="record") {if(actor.id!=initiator)return false;ending=true;return true;}
         if(phase!="idle" || cooldowns[actor.id]>0)return false;
         settings=api.profile();
         if(!isFinite(settings.duration) || settings.duration<30 || settings.duration>3600 ||
            !isFinite(settings.slowFactor) || settings.slowFactor<1 || settings.slowFactor>20 ||
            !isFinite(settings.replaySpeed) || settings.replaySpeed<1 || settings.replaySpeed>120)
            throw new Error("Invalid shared time-control configuration");
         initiator=actor.id;phase="record";++cycle;recorded=replayed=0;credit=slowCredit=0;ending=false;hits.clear();
         if(history!=null)history.dispose();history=new TimeHistory(host);
         Log.write("time-started",snapshot(false));return true;
      }
      /** Called only by the host's unpaused native Land step. */
      public function beginTick():Boolean {
         if(phase=="idle") {for(var i:int=0;i<2;i++)if(cooldowns[i]>0)--cooldowns[i];return true;}
         if(phase=="record")for each(var actor:PlayerActor in host.actors)if(actor.unit.hp<=0)ending=true;
         if(phase=="record" && (ending || recorded>=int(settings.duration))) {
            phase="replay";history.begin();Log.write("time-replay-started",snapshot(false));
         }
         if(phase=="replay") {
            for each(var input:Commands in host.inputs)input.consume(getTimer());
            credit+=Number(settings.replaySpeed);
            var count:int=int(credit);credit-=count;
            for(i=0;i<count && replayed<recorded;i++) {
               ++replayed;history.position(replayed);history.advanceEffects();hits.through(replayed);history.commit();
            }
            if(replayed>=recorded) {
               history.dispose();host.fullScene();
               cooldowns[initiator]=int(settings.cooldown);phase="idle";
               Log.write("time-replay-complete",snapshot(false));hits.clear();
            }else history.draw();
            return false;
         }
         ++recorded;slowCredit+=1/Number(settings.slowFactor);
         if(slowCredit+0.000001>=1){slowCredit-=1;return true;}return false;
      }
      public function withSource(value:Object,operation:Function):* {
         var saved:Object=source;source=value;try{return operation();}finally{source=saved;}
      }
      private function defer(target:Object,amount:Number,type:int,bullet:Object,periodic:Boolean):Boolean {
         return phase=="record" && hits.add(Math.max(1,recorded),target,amount,type,bullet,periodic,source);
      }
      public function snapshot(paused:Boolean,player:int=0):Object {
         return {phase:phase,cycle:cycle,initiator:initiator,recorded:recorded,replayed:replayed,
            left:phase=="record"?Math.max(0,int(settings.duration)-recorded):0,cooldown:cooldowns[player],paused:paused,
            queued:hits==null?0:hits.queued,applied:hits==null?0:hits.applied,discarded:hits==null?0:hits.discarded,pending:hits==null?0:hits.pending};
      }
      public function present(state:Object):void {if(state!=null)api.present(state);}
      public function requestEnd():void {if(phase=="record")ending=true;}
      public function capture():void {if(phase=="record" && recorded>0)history.capture(recorded);}
      public function dispose():void {
         if(host!=null)access.definition("fe.unit.Unit")["rconnectDeferDamage"]=oldHit;
         if(history!=null){history.dispose();history=null;}
         if(hits!=null)hits.clear();host=null;source=null;phase="idle";
         if(api!=null){api.detach();api=null;}
      }
   }
}
