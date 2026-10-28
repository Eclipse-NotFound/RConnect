package rconnect.game {
   /** Session-scoped grants. A grant remembers its original scope; changing the
    * host preference never revokes an already earned permission. */
   public class SecurityAccessState {
      private var grants:Object={};
      private var receipts:Object={};
      public var revision:int=0;
      public function reset():void {grants={};receipts={};revision=0;}
      private function key(room:String,unit:String):String {return room+"|"+unit;}
      public function add(receipt:Object):Boolean {
         if(!valid(receipt) || receipts[String(receipt.id)]!=null)return false;
         // Store an owned copy: subsequent message/UI mutations cannot change a grant.
         var r:Object=JSON.parse(JSON.stringify(receipt));
         receipts[String(r.id)]=r;
         revision++;
         for each(var unit:String in r.units) {
            var k:String=key(r.room,unit),g:Object=grants[k];
            if(g==null)g=grants[k]={shared:false,players:{},skill:-1,last:0,version:0};
            g.shared=g.shared || r.shared===true;
            g.players[String(r.actor)]=true;
            // Native hack effects follow the most recent activation; access is
            // monotonic even when the later hacker has a different skill.
            if(int(r.id)>int(g.last)){g.skill=int(r.skill);g.last=int(r.id);}
            g.version=revision;
         }
         return true;
      }
      public function get(room:String,unit:String):Object {return grants[key(room,unit)];}
      public function protects(room:String,unit:String,player:int):Boolean {
         var g:Object=get(room,unit);
         return player>=0 && g!=null && (g.shared===true || g.players[String(player)]===true);
      }
      public function terminalOpen(room:String,terminal:String,player:int):Boolean {
         for each(var r:Object in receipts)
            if(r.room==room && r.terminal==terminal && (r.shared===true || int(r.actor)==player))return true;
         return false;
      }
      public function exportReceipts():Array {
         var list:Array=[];for each(var r:Object in receipts)list.push(JSON.parse(JSON.stringify(r)));
         list.sortOn("id",Array.NUMERIC);return list;
      }
      public static function valid(r:Object):Boolean {
         if(r==null || !(r.id is Number) || r.id<1 || r.id!=int(r.id)
            || !(r.actor is Number) || r.actor<0 || r.actor>65535 || r.actor!=int(r.actor)
            || !(r.room is String) || r.room.length==0 || r.room.length>256
            || !(r.terminal is String) || !/^B[1-9][0-9]*$/.test(r.terminal)
            || !(r.shared is Boolean) || !(r.skill is Number) || r.skill<0 || r.skill>2 || r.skill!=int(r.skill)
            || !(r.units is Array) || r.units.length>512)return false;
         var seen:Object={};
         for each(var k:* in r.units) {
            if(!(k is String) || !/^U[1-9][0-9]*$/.test(k) || seen[k])return false;
            seen[k]=true;
         }
         return true;
      }
   }
}
