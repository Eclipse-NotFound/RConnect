package {
 import flash.system.ApplicationDomain;

 /** Deterministic contract checks against the class in the loaded product.
  * Synthesizes flat-ground confirmations/intents, never a second predictor.
  * Numeric time inputs make the 150 ms boundary independent of AIR load. */
 public final class BPredictChecks {
  public static function run(domain:ApplicationDomain,check:Function):void {
   var Type:Class=domain.getDefinition("authority.MovementPrediction") as Class;
   var f:Object=fixture(Type),p:Object=f.predictor,before:String=JSON.stringify(f.frame);
   var safe:Object=p.sample(80,f.frame,4,false);
   check(safe!=null && safe.x>100 && safe.x<=124,"prediction hold: actual product computes an initial bounded safe preview",{x:safe==null?null:safe.x});
   if(safe==null)return;
   var frozen:String=JSON.stringify(safe),applications:uint=p.applications;
   var expired:Object=p.sample(171,f.frame,4,false),later:Object=p.sample(1000,f.frame,4,false);
   check(expired!=null && JSON.stringify(expired)==frozen && later!=null && JSON.stringify(later)==frozen,
    "prediction hold: beyond 150 ms retains exactly the earlier safe picture without retreat or extension");
   check(p.applications==applications,"prediction hold: expired repeated samples execute no new prediction",{before:applications,after:p.applications});
   check(JSON.stringify(f.frame)==before,"prediction hold: native confirmation remains immutable");

   f=fixture(Type);p=f.predictor;
   check(p.sample(171,f.frame,4,false)==null && p.sample(1000,f.frame,4,false)==null && p.applications==0,
    "prediction hold: no earlier safe sample means no picture can be invented after timeout");

   // These intents arrive after the safe prediction window has elapsed.
   // Native braking/reversal inside the ordinary window remains out of scope.
   for each(var buttons:int in [0,1]) {
    f=fixture(Type);p=f.predictor;safe=p.sample(80,f.frame,4,false);frozen=JSON.stringify(safe);applications=p.applications;
    p.record(intent(2,buttons),180);
    var stopped:Object=p.sample(190,f.frame,4,false),repeated:Object=p.sample(1000,f.frame,4,false);
    check(stopped!=null && repeated!=null && JSON.stringify(stopped)==frozen && JSON.stringify(repeated)==frozen && p.applications==applications,
     "prediction hold: expired "+(buttons==0?"release":"reversal")+" input cannot advance the held picture");
   }

   // Every old safety guard must run before the new hold path. Restore the
   // original display afterwards: a rejected old picture must stay discarded.
   for each(var reason:String in ["local-pause","pause-epoch","position-epoch","room-epoch","room","terrain","no-display"]) {
    f=fixture(Type);p=f.predictor;p.sample(80,f.frame,4,false);
    var display:Object=copy(f.frame),terrain:uint=4,paused:Boolean=false;
    if(reason=="local-pause")paused=true;
    else if(reason=="pause-epoch")display.pauseEpoch++;
    else if(reason=="position-epoch")display.players[1].positionEpoch++;
    else if(reason=="room-epoch")display.players[1].roomEpoch++;
    else if(reason=="room")display.room="another-room";
    else if(reason=="terrain")terrain=5;
    else display=null;
    check(p.sample(190,display,terrain,paused)==null,"prediction hold: "+reason+" immediately discards expired preview");
    check(p.sample(200,f.frame,4,false)==null,"prediction hold: "+reason+" invalidation cannot revive an old preview");
   }

   f=fixture(Type);p=f.predictor;p.sample(80,f.frame,4,false);
   p.record(intent(2,10),90); // Actual public FIRE bit (8) plus RIGHT (2).
   check(p.sample(100,f.frame,4,false)==null,"prediction hold: unsafe attack rejects even before timeout");
   p.record(intent(3,2),180);
   check(p.sample(200,f.frame,4,false)==null,"prediction hold: later safe input cannot revive a picture cancelled by attack");

   for each(reason in ["paused","no-motion","new-position-epoch","new-room-epoch"]) {
    f=fixture(Type);p=f.predictor;p.sample(80,f.frame,4,false);
    var next:Object=copy(f.frame);next.tick++;next.time+=33;
    if(reason=="paused")next.paused=true;
    else if(reason=="no-motion")next.players[1].motion=null;
    else if(reason=="new-position-epoch")next.players[1].positionEpoch++;
    else next.players[1].roomEpoch++;
    p.confirm(next,200);
    check(p.sample(200,next,4,false)==null && p.sample(400,next,4,false)==null,
     "prediction hold: confirming "+reason+" discards previous preview");
   }

   f=fixture(Type);p=f.predictor;p.sample(80,f.frame,4,false);p.clear();
   check(p.sample(190,f.frame,4,false)==null,"prediction hold: explicit clear discards cached preview");

   f=fixture(Type);p=f.predictor;safe=p.sample(80,f.frame,4,false);
   p.record(intent(2,2),90);
   next=frame(500,2);next.tick=33;next.time=1100;p.confirm(next,100);
   var fresh:Object=p.sample(120,next,4,false);
   check(fresh!=null && fresh.x>=500 && fresh.x<=524 && fresh.x!=safe.x,
    "prediction hold: a new confirmation takes priority and updates the predicted X",{oldX:safe.x,newX:fresh==null?null:fresh.x});
   check(next.players[1].x==500 && next.players[1].native.X==500 && next.players[1].visual.m[4]==500,
    "prediction hold: fresh preview does not rewrite the new authoritative position");

   // Even with a valid new anchor, a new confirmation may not reuse the
   // preceding confirmation's held picture before it has its own safe sample.
   f=fixture(Type);p=f.predictor;p.sample(80,f.frame,4,false);p.record(intent(2,2),90);
   next=frame(500,2);next.tick=33;next.time=1100;p.confirm(next,100);
   check(p.sample(251,next,4,false)==null,"prediction hold: confirm clears held state even when no fresh sample was requested");
  }

  private static function fixture(Type:Class):Object {
   var p:Object=new Type(),f:Object=frame(100,1);
   p.record(intent(1,2),0);p.confirm(f,20);return {predictor:p,frame:f};
  }
  private static function intent(seq:uint,buttons:int):Object {
   return {room:"flat",roomEpoch:1,epoch:1,weaponEpoch:1,seq:seq,buttons:buttons,actions:[],pause:false,pauseMenus:false,pauseSats:false};
  }
  private static function frame(x:Number,ack:uint):Object {
   var state:Object={room:"flat",roomEpoch:1,epoch:1,weaponEpoch:1,positionEpoch:1,ack:ack,x:x,
    motion:{x:x,dx:2,walk:1,max:2,speed:2,accel:.5,brake:.2,friction:1,left:x-24,right:x+24},
    native:{X:x,X1:x-10,X2:x+10,eyeX:x},visual:{x:x,m:[1,0,0,1,x,200]},
    weapon:{id:"lmg",x:x,visual:{x:x,m:[1,0,0,1,x,190]}}};
   return {room:"flat",pauseEpoch:1,paused:false,tick:30,time:1000,players:[{},state],scene:{terrainRevision:4}};
  }
  private static function copy(value:Object):Object{return JSON.parse(JSON.stringify(value));}
 }
}
