package fe.serv {
   public class RConnectSecurityInteractionAccess {
      public static function capture(o:Object):Object {
         var i:Interact=o as Interact;if(i==null)return null;
         return {lock:o.lock,lockAtt:o.lockAtt,lockHP:o.lockHP,saveLock:i.saveLock};
      }
      public static function restore(o:Object,s:Object):void {
         var i:Interact=o as Interact;if(i==null || s==null)return;
         o.lock=s.lock;o.lockAtt=s.lockAtt;o.lockHP=s.lockHP;i.saveLock=s.saveLock;
         o.update();
      }
   }
}
