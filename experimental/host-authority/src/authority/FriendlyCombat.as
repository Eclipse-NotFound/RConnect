package authority {
   /** Player affiliation stays native; only explicit teammate eligibility changes. */
   public final class FriendlyCombat {
      public var enabled:Boolean=false;
      private var session:HostSession,oldHit:Function,oldSight:Function;
      public function FriendlyCombat(session:HostSession) {
         this.session=session;
         var Unit:Class=session.access.definition("fe.unit.Unit"),Mine:Class=session.access.definition("fe.unit.Mine");
         oldHit=Unit["rconnectHitPolicy"];oldSight=Mine["rconnectMineSight"];
         if(oldHit!=null || oldSight!=null)throw new Error("Friendly combat seams occupied");
         Unit["rconnectHitPolicy"]=allowed;Mine["rconnectMineSight"]=visible;
      }
      public function actor(source:Object):PlayerActor {
         if(source==null)return null;
         var owner:Object=NativeAccess.get(source,"rconnectOwner");if(owner!=null)source=owner;
         for each(var a:PlayerActor in session.actors)if(a.unit===source || a.unit.pet===source)return a;
         return null;
      }
      private function allowed(source:Object,target:Object,nativeAllowed:Boolean,kind:String):Boolean {
         var a:PlayerActor=actor(source),b:PlayerActor=actor(target);
         if(a==null || b==null)return nativeAllowed;
         if(a===b)return nativeAllowed;
         return enabled;
      }
      private function visible(mine:Object):Boolean {
         for each(var a:PlayerActor in session.actors)if(a.unit.loc===mine.loc && a.unit.hp>0 && !a.unit.disabled) {
            var seen:Boolean=Boolean(session.access.scope.run(a.context,function():Boolean{return a.unit.lookInvis(mine);}));
            if(seen)return true;
         }
         return false;
      }
      public function update():void {for each(var a:PlayerActor in session.actors)a.unit.isSats=enabled;}
      public function dispose():void {
         for each(var a:PlayerActor in session.actors)a.unit.isSats=false;
         session.access.definition("fe.unit.Unit")["rconnectHitPolicy"]=oldHit;
         session.access.definition("fe.unit.Mine")["rconnectMineSight"]=oldSight;
      }
   }
}
