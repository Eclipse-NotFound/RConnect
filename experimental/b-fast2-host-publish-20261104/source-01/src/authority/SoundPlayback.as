package authority {
   import flash.events.Event;
   import flash.media.Sound;
   import flash.media.SoundChannel;
   import flash.media.SoundTransform;
   import flash.utils.Dictionary;
   /** Local sound output only. Sound identities and stop events come from the
    * executing host; each listener keeps their own mute, volume and pan. */
   public final class SoundPlayback {
      private var access:NativeAccess,snd:Class;
      private var channels:Object={},looping:Object={},live:Dictionary=new Dictionary(true);
      public var starts:uint=0,stops:uint=0,loops:uint=0;
      public function channelFor(id:uint):SoundChannel{return channels[id] as SoundChannel;}
      public function SoundPlayback(access:NativeAccess){this.access=access;snd=access.definition("fe.Snd");}
      private function resource(name:String,variant:int):Sound {
         var entry:Object=snd["snd"][name];return entry is Array?entry[variant] as Sound:entry as Sound;
      }
      private function transform(event:Object,audible:Boolean):SoundTransform {
         var pan:Number=event.x==-1000?0:(event.x-Number(snd["centrX"]))/Number(snd["widthX"]);
         var volume:Number=audible && snd["onSnd"] && !snd["off"]?Number(event.volume)*Number(snd["globalVol"]):0;
         return new SoundTransform(volume,Math.max(-1,Math.min(1,pan)));
      }
      public function start(event:Object,audible:Boolean=true):SoundChannel {
         if(channels[event.id]!=null)return channels[event.id];
         var sound:Sound=resource(event.name,event.variant);
         if(sound==null || sound.bytesTotal==0 || sound.bytesLoaded<sound.bytesTotal)return null;
         // Inaudible host channels still carry native preparation timing and
         // return the real SoundChannel expected by Weapon and Interact.
         var channel:SoundChannel=sound.play(event.start,0,transform(event,audible));
         if(channel!=null){channels[event.id]=channel;live[channel]=event.id;channel.addEventListener(Event.SOUND_COMPLETE,complete);++starts;}
         return channel;
      }
      private function complete(event:Event):void {
         var channel:SoundChannel=event.currentTarget as SoundChannel;
         delete channels[live[channel]];delete live[channel];channel.removeEventListener(Event.SOUND_COMPLETE,complete);
      }
      public function stop(id:uint):void {
         var channel:SoundChannel=channels[id];if(channel==null)return;
         channel.stop();channel.removeEventListener(Event.SOUND_COMPLETE,complete);delete live[channel];delete channels[id];++stops;
      }
      public function apply(events:Array,hum:Object):void {
         for each(var event:Object in events){if(event.stop)stop(event.id);else start(event);}
         var active:Object={},name:String;
         for(name in hum) {
            var volume:Number=Number(hum[name]),ch:SoundChannel=looping[name];
            if(volume<=0)continue;active[name]=true;
            var state:Object={x:-1000,volume:volume};
            if(ch==null) {
               var sound:Sound=resource(name,0);
               if(sound!=null){ch=sound.play(0,10000,transform(state,true));if(ch!=null){looping[name]=ch;++loops;}}
            }else ch.soundTransform=transform(state,true);
         }
         for(name in looping)if(!active[name]){looping[name].stop();delete looping[name];}
      }
      public function dispose():void {
         for(var id:String in channels)stop(uint(id));
         for(var name:String in looping)looping[name].stop();looping={};
      }
      public function silence():void {
         // Preserve the real channel clock used by native spinning weapons.
         for each(var channel:SoundChannel in channels)channel.soundTransform=new SoundTransform(0,0);
         for(var name:String in looping)looping[name].stop();looping={};
      }
   }
}
