package authority {
   import flash.utils.Dictionary;
   /** Soundtrack ownership follows rooms; native Snd still plays/fades music.
    * Background rooms never change the host listener's music channel. */
   public final class SessionMusic {
      private var access:NativeAccess,snd:Class,actors:Array;
      private var rooms:Dictionary=new Dictionary(true),personal:Object={};
      private var lastTrack:String=null,lastRoom:String=null;
      public var changes:uint=0;
      public function SessionMusic(access:NativeAccess,actors:Array) {
         this.access=access;this.actors=actors;snd=access.definition("fe.Snd");
         if(snd["rconnectPlayMusic"]!=null || snd["rconnectCombatMusic"]!=null)throw new Error("Native music seam occupied");
         if(actors!=null) {
            var original:RoomMusic=state(access.world.loc);
            original.ambient=access.world.currentMusic;original.track=snd["musicName"];
            original.priority=snd["currentMusicPrior"];original.remaining=snd["t_combat"];
         }
         snd["rconnectPlayMusic"]=request;snd["rconnectCombatMusic"]=combat;
      }
      private function state(room:Object):RoomMusic {
         if(rooms[room]==null)rooms[room]=new RoomMusic(String(room.sndMusic));return rooms[room];
      }
      private function request(name:String,count:int):void {
         // Native options call playMusic(null) to restart a muted channel.
         // It changes this listener only and must not become a world command.
         if(name==null){snd["rconnectNativeMusic"](null,count);return;}
         if(actors==null)return;
         if(name=="harddie") {
            for each(var actor:PlayerActor in actors)if(access.world.gg===actor.unit) {
               var individual:RoomMusic=new RoomMusic(name);individual.loops=count;
               personal[actor.id]={epoch:actor.epoch,music:individual};return;
            }
         }
         state(access.world.loc).request(name,count);
      }
      private function combat(name:String,priority:int,duration:int):void {
         if(actors!=null)state(access.world.loc).combat(name,priority,duration);
      }
      public function step(room:Object):void {state(room).step();}
      public function forPlayer(id:int):Object {
         var actor:PlayerActor=actors[id],record:Object=personal[id];
         if(record!=null && (record.epoch!=actor.epoch || actor.unit.hp>0)){delete personal[id];record=null;}
         var music:RoomMusic=record==null?state(actor.unit.loc):record.music;
         var result:Object=music.snapshot();result.room=access.keyFor(actor.unit.loc);return result;
      }
      public function apply(value:Object):void {
         if(value==null)return;
         access.world.currentMusic=value.ambient;
         if(lastTrack!==value.track || lastRoom!==value.room) {
            snd["rconnectNativeMusic"](String(value.track),int(value.loops));
            lastTrack=value.track;lastRoom=value.room;++changes;
         }
         // The native fader uses this timer, but its single-player countdown
         // is inactive while the optional B hook owns room progression.
         snd["currentMusicPrior"]=int(value.priority);snd["t_combat"]=int(value.remaining);
      }
      public function dispose():void {
         snd["rconnectPlayMusic"]=snd["rconnectCombatMusic"]=null;
         rooms=new Dictionary(true);personal={};snd["t_combat"]=0;snd["currentMusicPrior"]=0;
         if(access.world.loc!=null) {
            access.world.currentMusic=access.world.loc.sndMusic;
            snd["rconnectNativeMusic"](access.world.currentMusic);
         }
      }
   }
}
