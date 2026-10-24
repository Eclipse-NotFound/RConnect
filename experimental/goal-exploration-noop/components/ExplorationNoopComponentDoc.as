package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.UncaughtErrorEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.Dictionary;

   public class ExplorationNoopComponentDoc extends Sprite {
      private var assertions:Array=[],reports:Array=[];
      private var writing:Boolean=false;
      public function ExplorationNoopComponentDoc() {
         loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR,uncaught);
         if(stage!=null)run();else addEventListener(Event.ADDED_TO_STAGE,added);
      }
      private function added(e:Event):void {removeEventListener(Event.ADDED_TO_STAGE,added);run();}
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});}
      private function uncaught(e:UncaughtErrorEvent):void {e.preventDefault();check(false,"uncaught "+String(e.error));finish();}
      private function rows(light:String="5",bits:String="1"):Array {
         var tile:String=light+bits+"000000000000000";return [tile+tile,tile+tile];
      }
      private function observe(f:ExplorationFixture,out:Array,label:String):void {
         f.render();out.push({label:label,view:f.view(),packet:f.packetView()});
      }
      private function exercise(candidate:Boolean):Array {
         var f:ExplorationFixture=new ExplorationFixture(candidate),out:Array=[],prefix:String=candidate?"candidate ":"control ";
         var before:int,oldData:Array,roomA:Object=f.mod.game.loc;
         try {
            check(!f.sync.receive(f.message(rows(),"stale")),prefix+"unconfirmed epoch rejects merge");
            check(f.apiState.calls==0,prefix+"unconfirmed packet does not call merge");
            observe(f,out,"unconfirmed");
            check(f.sync.receive(f.delta([[1,rows()[1]]])),prefix+"full baseline is decoded before confirmation");
            check(f.apiState.calls==1,prefix+"first confirmation applies once");
            oldData=f.apiState.references[0];observe(f,out,"first-confirmation");

            before=f.apiState.calls;check(f.sync.receive(f.message(rows())),prefix+"duplicate full accepted");
            check(f.apiState.calls-before==(candidate?0:1),prefix+"duplicate full only candidate skips empty merge");
            observe(f,out,"duplicate-full");
            before=f.apiState.calls;check(f.sync.receive(f.message(rows("0","0"))),prefix+"lower light accepted");
            check(f.apiState.calls-before==(candidate?0:1),prefix+"lower light keeps monotone history without merge");
            observe(f,out,"lower-light");
            before=f.apiState.calls;check(f.sync.receive(f.delta([[0,rows("0","0")[0]]])),prefix+"unchanged delta accepted");
            check(f.apiState.calls-before==(candidate?0:1),prefix+"unchanged delta only candidate skips empty merge");
            observe(f,out,"unchanged-delta");

            before=f.apiState.calls;check(f.sync.receive(f.message(rows("5","2"))),prefix+"new bit accepted");
            check(f.apiState.calls==before+1,prefix+"new bit still merges");
            check(JSON.stringify(oldData)==JSON.stringify(rows()),prefix+"previous memory input array remains immutable");
            observe(f,out,"new-bit");
            before=f.apiState.calls;check(f.sync.receive(f.message(rows("a","2"))),prefix+"brighter light accepted");
            check(f.apiState.calls==before+1,prefix+"brighter light still merges");observe(f,out,"brighter-light");

            f.sync.setEnabled(false);before=f.apiState.calls;
            check(!f.sync.receive(f.message(rows("f","4"))),prefix+"disabled receive rejects new knowledge");
            check(f.apiState.calls==before,prefix+"disabled receive no merge");observe(f,out,"disabled");
            f.sync.setEnabled(true);
            check(f.sync.receive(f.delta([[1,rows("a","8")[1]]])),prefix+"disabled packet still advanced delta baseline");
            check(f.apiState.calls==before+1,prefix+"reenabled changed knowledge merges");observe(f,out,"reenabled");

            f.replaceAPI("ok");f.advance();f.render();
            check(f.apiState.calls==1,prefix+"new API receives retained memory once");observe(f,out,"api-replaced");
            f.replaceAPI("false-once");f.advance();
            check(f.sync.receive(f.message(rows("0","0"))),prefix+"API false does not reject accepted network packet");
            check(f.apiState.calls==1,prefix+"API false attempt recorded");f.render();
            check(f.apiState.calls==2,prefix+"API false is retried by render");observe(f,out,"false-retried");
            f.replaceAPI("throw-once");f.advance();
            check(f.sync.receive(f.message(rows("0","0"))),prefix+"API exception remains optional");
            check(f.apiState.calls==1,prefix+"throwing merge attempted");
            observe(f,out,"throw-native-fallback");f.advance();f.render();
            check(f.apiState.calls==2,prefix+"same API rediscovers after throw and retries");observe(f,out,"throw-retried");

            f.apiState.mode="inactive";observe(f,out,"inactive-native-fallback");
            check(f.mod.game.loc.space[1][1].visi==0 && f.mod.game.loc.space[1][1].t_visi==0,
               prefix+"visual fallback leaves native visibility and interaction unchanged");
            f.apiState.mode="ok";
            var roomB:Object=f.room("B");f.enter(roomB);f.renew();
            check(f.sync.receive(f.message(rows("3","4"))),prefix+"new room receives its own history");observe(f,out,"room-B");
            f.enter(roomA);f.renew();before=f.apiState.calls;f.render();
            check(f.apiState.calls==before,prefix+"revisit keeps existing successful API application");observe(f,out,"room-A-revisit");
            before=f.apiState.calls;check(f.sync.receive(f.message(rows("0","0"))),prefix+"revisit confirmed duplicate accepted");
            check(f.apiState.calls-before==(candidate?0:1),prefix+"revisit duplicate only candidate skips merge");observe(f,out,"room-A-confirmed");

            var stale:String=f.token.epoch;f.sync.resetLink();f.renew();
            check(!f.sync.receive(f.delta([[0,rows()[0]]])),prefix+"reset rejects delta without baseline");
            check(!f.sync.receive(f.message(rows(),stale)),prefix+"reset rejects old local epoch");
            before=f.apiState.calls;check(f.sync.receive(f.message(rows("0","0"))),prefix+"new handshake accepts retained room");
            check(f.apiState.calls-before==(candidate?0:1),prefix+"link reset retains acquired display");observe(f,out,"link-reset");

            f.mod.game.loc.keyStage=2;f.renew();before=f.apiState.calls;
            check(f.sync.receive(f.message(rows("2","1"))),prefix+"same object changed key accepted as new context");
            check(f.apiState.calls==before+1,prefix+"different key cannot retain API marker");observe(f,out,"key-changed");
            f.enter(f.room("A"));f.renew();before=f.apiState.calls;
            check(f.sync.receive(f.message(rows("2","1"))),prefix+"new room identity accepted");
            check(f.apiState.calls==before+1,prefix+"same key new identity cannot retain marker");observe(f,out,"identity-changed");

            f.mod.game.world.game={};f.apiState.rooms=new Dictionary();f.renew();before=f.apiState.calls;
            check(f.sync.receive(f.message(rows("2","1"))),prefix+"new game accepts fresh history");
            check(f.apiState.calls==before+1,prefix+"new game clears previous success marker");observe(f,out,"game-changed");
            reports.push({candidate:candidate,observations:out});
         } catch(error:*) {check(false,prefix+"unexpected error "+String(error));}
         finally {f.close();}
         return out;
      }
      private function run():void {
         var old:Array=exercise(false),current:Array=exercise(true);
         check(old.length==21 && current.length==21,"all 21 scenario boundaries observed on both real classes");
         for(var i:int=0;i<Math.min(old.length,current.length);i++)
            check(JSON.stringify(old[i])===JSON.stringify(current[i]),"same network/display/visibility result: "+old[i].label);
         finish();
      }
      private function finish():void {
         if(writing)return;writing=true;var failed:int=0;
         for each(var row:Object in assertions)if(!row.passed)failed++;
         var stream:FileStream=new FileStream();
         try {stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,
               reports:reports,nativeGame:false,realRV:false,performanceQualified:false}));}
         finally {stream.close();}
         NativeApplication.nativeApplication.exit(failed==0?0:1);
      }
   }
}
