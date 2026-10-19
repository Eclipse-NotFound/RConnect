package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.EventDispatcher;
   import flash.filesystem.*;
   import flash.utils.*;
   import rconnect.core.SecurityTerminals;
   import rconnect.net.*;

   /** Actual controller/ledger with a lossy, FIFO test link and empty rooms.
    * No game assets, native turret AI or damage are represented by this test. */
   public class SecurityHandshakeChecks extends Sprite {
      private var rows:Array=[],host:Object,join:Object,hs:Object,js:Object;
      private var h:SecurityTestLink=new SecurityTestLink(),j:SecurityTestLink=new SecurityTestLink();
      private var helloCount:int,phaseAt:int=getTimer();
      public function SecurityHandshakeChecks() {
         try {
            h.id=1;j.id=0;h.other=j;j.other=h;h.dropStates=1;
            host=model(true,h);join=model(false,j);
            hs=new SecurityTerminals(host);js=new SecurityTerminals(join);
            host.stage.dispatchEvent(new Event(Event.ENTER_FRAME));join.stage.dispatchEvent(new Event(Event.ENTER_FRAME));
            activate("B1");
            setTimeout(first,100);
         }catch(e:Error){fail(e);}
      }
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});trace((ok?"PASS ":"FAIL ")+label);}
      private function model(isHost:Boolean,link:SecurityTestLink):Object {
         var f:Object={rconnectSecurity:null},cfg:Object={value:"0"};
         cfg.getValue=function(k:String):String{return cfg.value;};
         cfg.setValue=function(k:String,v:String):void{cfg.value=v;};cfg.save=function():void{};
         var game:Object={gg:{},loc:{units:[],objs:[]},roomHold:false};
         game.isTransitioning=function():Boolean{return false;};
         game.roomKey=function(o:Object=null):String{return "mane//0,0,0";};
         game.securityObjectKey=function(o:Object):String{return o.key;};
         return {stage:new EventDispatcher(),factory:f,config:cfg,game:game,
            main:{loaderInfo:{applicationDomain:{getDefinition:function(n:String):Object{return f;}}}},
            session:{mode:isHost?"hosting":"connected",myId:isHost?0:1,server:{},link:link,
               peers:isHost?[{link:link}]:[],rooms:{epoch:1,ready:true,busy:false,authority:isHost}}};
      }
      private function activate(key:String):void {
         var box:Object={key:key},inter:Object={lock:0,allact:"hack_robot",prob:null,owner:box};box.inter=inter;
         inter.setAct=function(n:String,v:int):void{inter.lock=0;};
         join.game.loc.objs.push(box);
         check(join.factory.rconnectSecurity("terminal",inter,0)===true,"native terminal callback handled "+key);
      }
      private function latest():Object {
         var state:Object=null;for each(var p:Object in h.sent)if(p.op=="state")state=p;return state;
      }
      private function count(op:String):int {var n:int=0;for each(var p:Object in j.sent)if(p.op==op)n++;return n;}
      private function first():void {
         try {
            var s:Object=latest();
            if((s==null || s.receipts.length!=1) && getTimer()-phaseAt<8000){setTimeout(first,100);return;}
            check(h.dropped==1,"first state was actually discarded");
            check(s!=null && s.receipts.length==1 && s.receipts[0].terminal=="B1" && s.receipts[0].actor==1
               && s.receipts[0].shared===false,"hack completed before first state is eventually recorded with host scope");
            check(count("hello")>=2,"initial state loss triggers a retry");
            check(count("request")==1,"pending initial hack is sent once");
            helloCount=count("hello");setTimeout(quiet,1500);
         }catch(e:Error){fail(e);}
      }
      private function quiet():void {
         try {
            check(count("hello")==helloCount,"state retries stop after confirmation");
            host.session.rooms.epoch=2;join.session.rooms.epoch=2;h.dropStates=1;
            host.game.loc={units:[],objs:[]};join.game.loc={units:[],objs:[]};
            host.stage.dispatchEvent(new Event(Event.ENTER_FRAME));join.stage.dispatchEvent(new Event(Event.ENTER_FRAME));
            phaseAt=getTimer();activate("B2");activate("B3");setTimeout(second,100);
         }catch(e:Error){fail(e);}
      }
      private function second():void {
         try {
            var s:Object=latest();
            if((s==null || s.epoch!=2 || s.receipts.length!=2) && getTimer()-phaseAt<8000){setTimeout(second,100);return;}
            check(h.dropped==2,"new-map first state was also discarded");
            check(s!=null && s.epoch==2 && s.receipts.length==2
               && s.receipts[0].terminal=="B2" && s.receipts[1].terminal=="B3",
               "new-map confirmation clears old grants and preserves queued request order");
            j.dispatchEvent(new NetMessageEvent(TcpLink.MESSAGE,{type:"security-terminals",op:"state",epoch:1,
               policyRevision:999,shared:true,receipts:[]}));
            check(js.shared===false,"delayed old-map state cannot change current policy");
            phaseAt=getTimer();check(hs.setShared(true),"host can change future scope");setTimeout(changed,100);
         }catch(e:Error){fail(e);}
      }
      private function changed():void {
         try {
            var s:Object=latest();
            if(js.shared!==true && getTimer()-phaseAt<8000){setTimeout(changed,100);return;}
            check(js.shared===true,"new host preference reaches joining player");
            check(s.receipts.length==2 && s.receipts[0].shared===false && s.receipts[1].shared===false,
               "policy switch does not widen earlier individual grants");
            check(!js.setShared(false),"joining player cannot replace host setting");
            join.session.mode="offline";join.stage.dispatchEvent(new Event(Event.ENTER_FRAME));
            check(join.factory.rconnectSecurity==null,"offline removes native callback");finish();
         }catch(e:Error){fail(e);}
      }
      private function fail(e:Error):void {check(false,e.getStackTrace());finish();}
      private function finish():void {
         var failures:int=0;for each(var row:Object in rows)if(!row.passed)failures++;
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failures==0,failed:failures,assertions:rows,
            hostPackets:h.sent,joinPackets:j.sent,native_game_test:false}));fs.close();
         NativeApplication.nativeApplication.exit(failures?1:0);
      }
   }
}
