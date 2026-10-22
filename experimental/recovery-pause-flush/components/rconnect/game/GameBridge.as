package rconnect.game {
   import pausecheck.Probe;
   public class GameBridge {
      public var coopPaused:Boolean=false,transitioning:Boolean=false,dead:Boolean=false;
      public var world:Object={allStat:1,pip:{active:false},sats:{active:false},
         stand:{active:false},vstand:{visible:false},gui:{guiPause:false},mm:{active:false}};
      public var gg:Object={},loc:Object={};
      public var captures:int=0,enemies:int=0,loot:int=0,walls:int=0,commits:int=0;
      public var stamp:int=12345,endpoint:Number=305;
      public static function probe(o:Object,k:String):*{return o==null?null:o[k];}
      public function setCoopPaused(v:Boolean):void{coopPaused=v;Probe.events.push(v?"pause-on":"pause-off");}
      public function isTransitioning():Boolean{return transitioning;}
      public function isPlayerDead():Boolean{return dead;}
      public function readSnapshot():Object{captures++;Probe.events.push("capture");return {x:1,sampleTime:stamp};}
      public function readEnemyMotion():Array{enemies++;return [{x:endpoint,sampleTime:stamp,effects:[{seq:enemies}]}];}
      public function readLootSync(activeOnly:Boolean=false):Array{loot++;return [{x:2,sampleTime:stamp}];}
      public function readWallPaintUpdates():Array{walls++;return [{v:walls}];}
      public function wallPaintUpdatesSent(a:Array):void{commits++;Probe.events.push("wall-commit");}
   }
}
