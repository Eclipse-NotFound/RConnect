package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.filesystem.*;
   import rconnect.game.SecurityAccessState;
   public class SecurityAccessChecks extends Sprite {
      private var rows:Array=[];
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});trace((ok?"PASS ":"FAIL ")+label);}
      private function receipt(id:int,actor:int,shared:Boolean,skill:int=0,room:String="mane//0,0,0",unit:String="U1",terminal:String="B1"):Object {
         return {id:id,actor:actor,shared:shared,skill:skill,room:room,units:[unit],terminal:terminal};
      }
      public function SecurityAccessChecks() {
         try {run();}catch(e:Error){check(false,e+" "+e.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function run():void {
         var s:SecurityAccessState=new SecurityAccessState(),room:String="mane//0,0,0";
         check(!s.protects(room,"U1",0),"unhacked host has no permission");
         check(s.add(receipt(1,0,false)),"personal host grant accepted");
         check(s.protects(room,"U1",0) && !s.protects(room,"U1",7),"personal grant isolates host and join");
         check(s.terminalOpen(room,"B1",0) && !s.terminalOpen(room,"B1",7),"personal lock stays locked for teammate");
         check(!s.protects("mane/background/0,0,0","U1",0),"hidden background room is a distinct scope");
         check(!s.protects(room,"U2",0),"later spawned turret is not silently hacked");
         var rev:int=s.revision;
         check(!s.add(receipt(1,7,true,2)) && s.revision==rev,"duplicate receipt cannot widen scope or upgrade skill");
         check(s.add(receipt(2,7,false,1)),"other player may hack independently");
         check(s.protects(room,"U1",0) && s.protects(room,"U1",7),"two personal grants preserve both permissions");
         check(s.get(room,"U1").skill==1,"native security upgrade retained");
         check(s.add(receipt(3,7,true,2,room,"U2","B2")),"new shared grant accepted");
         check(s.protects(room,"U2",0) && s.protects(room,"U2",7),"shared grant protects both roles");
         check(s.protects(room,"U2",23),"shared permission belongs to party");
         check(!s.protects(room,"U2",-1),"NPC is never assigned player permission");
         check(s.get(room,"U1").skill==1,"later terminal does not alter earlier native skill result");
         var wire:Array=s.exportReceipts(),copy:SecurityAccessState=new SecurityAccessState();
         for each(var r:Object in wire)copy.add(r);
         check(copy.protects(room,"U1",7) && copy.protects(room,"U2",0),"state transfer preserves personal and shared grants");
         wire[0].shared=true;wire[0].units.push("U99");
         check(!copy.protects(room,"U99",0) && !s.protects(room,"U99",0),"caller mutations cannot rewrite either ledger");
         r=receipt(4,0,false,0,room,"U3","B3");s.add(r);r.shared=true;
         check(!s.protects(room,"U3",7),"changing preference/message later cannot widen an earned personal grant");
         check(s.protects(room,"U2",7),"old shared grant survives subsequent personal hacks");
         var ordered:SecurityAccessState=new SecurityAccessState();
         ordered.add(receipt(8,7,false,0));ordered.add(receipt(7,0,false,2));
         check(ordered.get(room,"U1").skill==0,"reordered old receipt cannot replace the newest native hack effect");
         check(ordered.protects(room,"U1",0) && ordered.protects(room,"U1",7),"different skill effects never revoke either player's access");
         var bad:Array=[null,{},receipt(0,0,true),receipt(5,-1,true),receipt(5,0,true,3),receipt(5,0,true,0,""),receipt(5,0,true,0,room,"X1"),receipt(5,0,true,0,room,"U1","__proto__")];
         var duplicate:Object=receipt(5,0,true);duplicate.units=["U1","U1"];bad.push(duplicate);
         var spoof:Object=receipt(5,0,true);spoof.shared="true";bad.push(spoof);
         var fractional:Object=receipt(5,0,true);fractional.actor=0.5;bad.push(fractional);
         for(var i:int=0;i<bad.length;i++)check(!s.add(bad[i]),"malformed receipt rejected "+i);
         var empty:Object=receipt(5,0,true);empty.units=[];
         check(s.add(empty) && s.terminalOpen(room,"B1",0),"valid empty room terminal still records completion");
         s.reset();check(s.exportReceipts().length==0 && !s.protects(room,"U1",0),"new expedition/session clears old IDs");
      }
   }
}
