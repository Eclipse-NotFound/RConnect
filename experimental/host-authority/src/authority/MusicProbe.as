package authority {
   /** Actual native soundtrack resources across separate rooms and reunion. */
   public final class MusicProbe extends Probe {
      private var ready:Boolean=false,peerReady:Boolean=false,begin:int=-1,ending:int=-1;
      private var home:Object,back:Object,homeY:Number,backY:Number,emptyHome:int,emptyBack:int;
      private var checks:Array=[],expectedCount:int=0,observedCount:int=0;
      public function MusicProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function input(frame:Object,session:HostSession):Object {frame.buttons=0;frame.actions=[];return frame;}
      override public function message(value:Object):void {
         if(host && value.type=="music-ready")peerReady=true;
         if(!host && value.type=="music-expect")checks.push(value);
         if(!host && value.type=="music-end"){ending=value.tick;expectedCount=value.count;}
      }
      private function confirmed(frame:Object):void {
         if(checks.length==0 || frame.tick<checks[0].tick)return;
         var expectation:Object=checks.shift(),snd:Class=access.definition("fe.Snd");++observedCount;
         check(frame.audio.music.track==expectation.track && snd["musicName"]==expectation.track && snd["musicCh"]!=null,
            "join plays the native track for its occupied room: "+expectation.label,
            {expected:expectation.track,confirmed:frame.audio.music.track,playing:snd["musicName"]});
         check(Math.abs(Number(snd["musicVol"])-.13)<.0001 && Math.abs(snd["musicCh"].soundTransform.volume-.13)<.001,
            "host room/music changes preserve join's own volume: "+expectation.label);
      }
      private function expect(session:HostSession,name:String,label:String):void {
         ++expectedCount;session.link.send({type:"music-expect",track:name,label:label,tick:session.runtime.tick+1});
      }
      private function move(session:HostSession,id:int,room:Object,y:Number):void {
         session.runtime.transfers.relocate(session.actors[id],room,400+id*120,y);
         session.runtime.rooms.occupied();session.runtime.rooms.showHost();
      }
      private function battle(session:HostSession,id:int,name:String,duration:int):void {
         access.scope.run(session.actors[id].context,function():void {access.definition("fe.Snd")["combatMusic"](name,2,duration);});
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;var snd:Class=access.definition("fe.Snd");
         if(!host) {
            if(replica==null || replica.displayFrame==null)return;
            if(!ready) {
               ready=true;replica.confirmed=confirmed;snd["musicVol"]=.13;snd["onMusic"]=true;snd["updateMusicVol"]();
               RConnectMod.instance.link.send({type:"music-ready"});
            }
            if(ending>=0 && replica.displayFrame.tick>=ending) {
               check(observedCount==expectedCount && observedCount>=6 && checks.length==0,
                  "all split, reunion and combat-expiry soundtrack transitions were observed",{expected:expectedCount,observed:observedCount});finish();
            }return;
         }
         if(session==null || !session.active)return;
         if(!ready) {
            ready=true;
            for each(var column:Array in access.world.land.locs)for each(var row:Array in column)
               if(row!=null && row[0]!=null && row[1]!=null && !row[0].sky && !row[1].sky){home=row[0];back=row[1];break;}
            if(home==null)throw new Error("Music probe needs a native foreground/background pair");
            homeY=ProbeArena.floor(home);backY=ProbeArena.floor(back);
            for each(var actor:PlayerActor in session.actors){actor.unit.invulner=true;move(session,actor.id,home,homeY);}
            snd["musicVol"]=.61;snd["onMusic"]=true;snd["updateMusicVol"]();
         }
         if(begin<0 && peerReady)begin=session.runtime.tick;
         if(begin<0)return;var elapsed:int=session.runtime.tick-begin;
         if(elapsed==5){battle(session,1,"combat_1",120);expect(session,"combat_1","shared combat");}
         if(elapsed==8)check(snd["musicName"]=="combat_1","same-room combat changes host native music too");
         if(elapsed==20){move(session,1,back,backY);expect(session,String(back.sndMusic),"join separates");}
         if(elapsed==30){battle(session,1,"boss_1",60);expect(session,"boss_1","remote room combat");}
         if(elapsed==33)check(snd["musicName"]=="combat_1","background-room combat cannot replace host soundtrack");
         if(elapsed==40){emptyHome=session.sound.music.forPlayer(0).remaining;move(session,0,back,backY);}
         if(elapsed==43)check(snd["musicName"]=="boss_1","host hears the destination room when joining later");
         if(elapsed==55) {
            move(session,0,home,homeY);
            check(session.sound.music.forPlayer(0).remaining==emptyHome,"unoccupied foreground room retains combat music timer");
         }
         if(elapsed==60){emptyBack=session.sound.music.forPlayer(1).remaining;move(session,1,home,homeY);expect(session,"combat_1","join returns home");}
         if(elapsed==75) {
            move(session,0,back,backY);move(session,1,back,backY);
            check(session.sound.music.forPlayer(1).remaining==emptyBack,"unoccupied background room retains combat music timer");
            expect(session,"boss_1","both revisit retained room");
         }
         if(elapsed==85){snd["musicVol"]=0;snd["onMusic"]=false;snd["updateMusicVol"]();expect(session,"boss_1","host mutes only itself");}
         if(elapsed==86)check(snd["musicCh"]!=null && snd["musicCh"].soundTransform.volume==0,"host native music volume can be muted during combat");
         if(elapsed==90){snd["musicVol"]=.61;snd["onMusic"]=true;snd["updateMusicVol"]();}
         if(elapsed==115)expect(session,String(back.sndMusic),"combat expires");
         if(elapsed==120)check(snd["musicName"]==back.sndMusic && session.sound.music.forPlayer(0).remaining==0,
            "reunited room advances its music timer once and returns to native ambient music");
         if(elapsed>=145){session.link.send({type:"music-end",tick:session.runtime.tick,count:expectedCount});finish();}
      }
   }
}
