package authority {
   import flash.media.SoundChannel;
   import flash.utils.Dictionary;
   /** Room-owned native sound events, independent of either user's volume.
    * No client attack or second world step is needed to reproduce them. */
   public final class SessionSound {
      private var access:NativeAccess,snd:Class,actors:Array;
      private var nextId:uint=0,events:Array=[],channels:Dictionary=new Dictionary(true),hums:Object={};
      private var lastTick:int=-1,room:String="",oldHum:Array;
      public var output:SoundPlayback;
      public var captured:uint=0,capturedStops:uint=0,capturedHums:uint=0;
      public function SessionSound(access:NativeAccess,actors:Array=null) {
         this.access=access;this.actors=actors;snd=access.definition("fe.Snd");output=new SoundPlayback(access);
         if(snd["rconnectPlaySound"]!=null || snd["rconnectHumSound"]!=null || snd["rconnectStopSound"]!=null)
            throw new Error("Native sound seam occupied");
         oldHum=snd["shumArr"];
         for each(var entry:Object in oldHum){if(entry.ch!=null)entry.ch.stop();entry.pl=false;entry.curVol=entry.maxVol=0;}
         snd["shumArr"]=[];
         snd["rconnectPlaySound"]=play;snd["rconnectHumSound"]=hum;snd["rconnectStopSound"]=stop;
      }
      private function play(name:String,x:Number,y:Number,start:Number,volume:Number):SoundChannel {
         if(actors==null) {
            if(NativeIntents.replaying>0)return null;
            return snd["rconnectNativeSound"](name,x,y,start,volume);
         }
         listener();
         var group:Object=snd["snd"][name],owner:int=access.world.gg===actors[1].unit?1:0;
         var event:Object={id:++nextId,name:name,x:x,y:y,start:start,volume:volume*(Math.random()*.1+.9),
            variant:group is Array?int(Math.random()*group.length):0,room:access.roomKey(),owner:owner};
         events.push(event);++captured;
         var audible:Boolean=event.room===access.keyFor(actors[0].unit.loc) && (x!=-1000 || owner==0);
         var channel:SoundChannel=output.start(event,audible);if(channel!=null)channels[channel]=event;return channel;
      }
      private function stop(channel:SoundChannel):void {
         if(actors==null)return;
         var event:Object=channels[channel];if(event==null)return;
         events.push({id:event.id,stop:true,room:event.room,owner:event.owner,x:event.x});
         output.stop(event.id);delete channels[channel];++capturedStops;
      }
      private function hum(name:String,volume:Number):void {
         if(actors==null){if(NativeIntents.replaying==0)snd["rconnectNativeHum"](name,volume);return;}
         var key:String=access.roomKey(),record:Object=hums[key];if(record==null)record=hums[key]={};
         record[name]=Math.max(Number(record[name] || 0),volume);++capturedHums;
      }
      public function snapshot(joinRoom:String,tick:uint,paused:Boolean):Object {
         var hostRoom:String=access.keyFor(actors[0].unit.loc);
         listener();
         var remote:Array=[];
         for each(var event:Object in events)if(event.room===joinRoom && (event.x!=-1000 || event.owner==1))remote.push(event);
         events=[];
         if(paused)hums={};
         var current:Object=hums[joinRoom],copy:Object={},name:String;
         if(current!=null)for(name in current)copy[name]=current[name];
         output.apply([],hums[hostRoom]==null?{}:hums[hostRoom]);
         if(tick!=lastTick && tick%5==0)for each(current in hums)for(name in current) {
            current[name]=Math.max(0,Number(current[name])-.2);if(current[name]==0)delete current[name];
         }
         lastTick=tick;return {events:remote,hum:copy};
      }
      private function listener():void {
         var key:String=access.keyFor(actors[0].unit.loc);
         if(room!==key){output.silence();room=key;}
      }
      public function apply(frame:Object):void {
         if(room!==frame.room){output.dispose();room=frame.room;}
         if(frame.audio!=null)output.apply(frame.audio.events,frame.audio.hum);
      }
      public function dispose():void {
         snd["rconnectPlaySound"]=snd["rconnectHumSound"]=snd["rconnectStopSound"]=null;
         output.dispose();snd["shumArr"]=oldHum;events=[];hums={};channels=new Dictionary(true);
      }
   }
}
