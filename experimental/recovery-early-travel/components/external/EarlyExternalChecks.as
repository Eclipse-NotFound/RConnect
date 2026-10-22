package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   /** Exact MapGeneration acquire/release method bodies; carrier is a contract
    * fake, not a substitute for the separately authorized Sandevistan tests. */
   public class EarlyExternalChecks extends Sprite {
      private var rows:Array=[],p:NativeMapLeaseProbe,w:Object,c:Object,s:Object,calls:Array,lookup:Object;
      public function EarlyExternalChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      private function setup():void {
         w={game:{},onPause:false,pip:{active:false},sats:{active:false},stand:{active:false},gui:{guiPause:false}};
         calls=[];var owner:Object=null,id:String="";
         c={version:1,contract:"sandy-travel-hold/1",phase:"idle",debugTest:false,refuse:false};
         c.query=function(a:Object,b:Object):Object {return {version:1,contract:c.contract,phase:c.phase,debugTest:c.debugTest};};
         c.acquire=function(o:Object,a:Object,b:Object,t:String):Boolean {
            calls.push(["acquire",o,t,a,b]);if(c.refuse)return false;owner=o;id=t;return true;
         };
         c.release=function(o:Object,t:String):Boolean {calls.push(["release",o,t]);return o===owner && t==id;};
         lookup={value:c};s={mod:{game:{world:w,roomHold:false,main:{getChildByName:function(n:String):Object{return lookup.value;}}}}};
         p=new NativeMapLeaseProbe(s);
      }
      private function run():void {
         setup();check(p.acquireEarly("a"),"matching version/contract and idle state acquires");
         check(p.acquireEarly("a") && calls.length==1,"same local lease is idempotent");
         check(!p.acquireEarly("b") && calls.length==1,"different id cannot steal existing lease");
         var first:Object=c;lookup.value={};check(p.releaseEarly("a") && calls[1][0]=="release","release uses acquired object despite later named-carrier replacement");
         check(calls[0][1]===calls[1][1] && calls[1][2]=="a","release preserves private owner and exact id");
         setup();lookup.value=null;check(!p.acquireEarly("a") && calls.length==0,"missing carrier fails closed, not interpreted as no installed mod");
         setup();c.version=2;check(!p.acquireEarly("a"),"unknown interface version fails closed");
         setup();c.contract="other";check(!p.acquireEarly("a"),"wrong interface contract fails closed");
         setup();c.query=function(a:Object,b:Object):Object{return null;};check(!p.acquireEarly("a"),"unknown native identity fails closed");
         setup();c.phase="active";check(!p.acquireEarly("a") && calls.length==0,"active player recording is not carried across maps");
         setup();c.phase="replay";check(!p.acquireEarly("a"),"replay rejects optimization");
         setup();c.debugTest=true;check(!p.acquireEarly("a"),"automatic test ownership rejects optimization");
         setup();c.refuse=true;check(!p.acquireEarly("a") && calls.length==1,"atomic acquisition rejection after idle query is honored");
         setup();c.acquire=function(...args):Boolean{throw new Error("fixture");};check(!p.acquireEarly("a"),"carrier exception cannot grant optimization");
         setup();w.onPause=true;check(!p.acquireEarly("a"),"unowned native pause is not an eligible start");
         setup();w.pip.active=true;check(!p.acquireEarly("a"),"active Pip menu is not eligible");
         setup();w.sats.active=true;check(!p.acquireEarly("a"),"active SATS is not eligible");
         setup();check(p.acquireEarly("a"),"replacement-world case starts with owned lease");
         w.game={};c.release=function(o:Object,t:String):Boolean{return false;};
         check(p.releaseEarly("a") && w.onPause===false,"native identity replacement may retire lease without writing pause");
         setup();p.acquireEarly("a");s.mod.game.world={game:{},onPause:true};
         c.release=function(o:Object,t:String):Boolean{return false;};
         check(p.releaseEarly("a") && s.mod.game.world.onPause===true,"whole World replacement retires auto-cleared lease without transplanting pause");
         setup();p.acquireEarly("a");s.mod.game.world=null;c.release=function(o:Object,t:String):Boolean{return false;};
         check(!p.releaseEarly("a"),"unreadable current World does not falsely confirm an auto-cleared lease");
         setup();p.acquireEarly("a");c.release=function(o:Object,t:String):Boolean{throw new Error("release fixture");};
         check(!p.releaseEarly("a") && !p.acquireEarly("b"),"release exception retains ownership and blocks another lease");
      }
      private function begin(e:Event):void {
         try{run();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var r:Object in rows)if(!r.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
