package authority {
   import flash.display.DisplayObjectContainer;
   /** B owns scheduling; MSW owns its original weapon and optical algorithms. */
   public final class WeaponBridge {
      private var api:Object,access:NativeAccess,host:HostSession;
      public function WeaponBridge(main:Object,access:NativeAccess,session:String,role:String) {
         this.access=access;
         var container:DisplayObjectContainer=main as DisplayObjectContainer;
         var carrier:Object=container==null?null:container.getChildByName("MSWAuthorityAPI");
         var entry:Object=NativeAccess.get(carrier,"authorityAPI");
         if(entry==null || entry.version!==1 || !(entry.attach is Function))throw new Error("Pinned independent MSW B API unavailable");
         api=entry.attach({version:1,role:role,session:session,withPlayer:withPlayer,allowHarm:allowHarm,
            submit:RConnectMod.instance.requestWeaponAction,keyFor:keyFor,resolve:resolve});
         if(api==null || api.version!==1 || !(api.beforePlayer is Function) || !(api.afterRoom is Function) || !(api.detach is Function))throw new Error("MSW B API mismatch");
         Log.write("weapons-attached",{role:role,version:api.version});
      }
      public function bind(session:HostSession,remote:Object):void {
         host=session;
         api.register("0",host.actors[0].unit,host.actors[0].epoch,api.profile());
         api.register("1",host.actors[1].unit,host.actors[1].epoch,remote);
      }
      private function withPlayer(key:String,room:Object,operation:Function):* {
         if(host!=null)for each(var a:PlayerActor in host.actors)if(String(a.id)==key)return access.scope.runRoom(a.context,room,operation);
         throw new Error("MSW requested an unknown native actor");
      }
      private function allowHarm(source:Object,target:Object):Boolean {
         return host!=null && host.combat.enabled && source!==target &&
            (source===host.actors[0].unit || source===host.actors[1].unit) && (target===host.actors[0].unit || target===host.actors[1].unit);
      }
      private function keyFor(unit:Object):uint{return host==null?0:host.sceneId(unit);}
      private function resolve(key:uint):Object {
         if(host!=null && host.actors.length>0)return host.actors[0].resolveTarget(key);
         var r:ClientReplica=RConnectMod.instance.replica;
         if(r==null)return null;
         if(r.scene.units[key]!=null)return r.scene.units[key].unit;
         for each(var unit:Object in access.world.loc.units)if(r.scene.keyFor(unit)==key)return unit;
         return null;
      }
      public function profile():Object{return api.profile();}
      public function input():Object{return api.input();}
      public function beforePlayer(a:PlayerActor,input:Object):void {api.beforePlayer(String(a.id),a.unit,a.epoch,input.msw);}
      public function afterPlayer(a:PlayerActor):void {api.afterPlayer(String(a.id));}
      public function beforeObjects(room:Object,tick:uint):void {api.beforeObjects(room,tick);}
      public function afterRoom(room:Object,tick:uint):void {api.afterRoom(room,tick);}
      public function execute(a:PlayerActor,action:String):Boolean{return api.execute(String(a.id),action);}
      public function enterWorld(land:Object):void{api.enterWorld(land);}
      public function carryState(game:Object):void{api.carryState(game);}
      public function snapshot(id:int):Object{return api.snapshot(String(id));}
      public function present(state:Object):void{api.present(state);}
      public function inspect():Object{return api.inspect();}
      public function inspectTarget(unit:Object):Object{return api.inspectTarget(unit);}
      public function dispose():void{if(api!=null){api.detach();api=null;}host=null;}
      public static function validInput(value:Object):Boolean {
         if(value==null)return true;
         if(!(value.heldW is Boolean) || !(value.heldShift is Boolean) || !(value.overlay is Boolean) || value.settings==null || value.viewport==null)return false;
         var v:Object=value.viewport;
         if(!(v.width is Number) || !(v.height is Number) || !(v.scale is Number) || !isFinite(v.width) || !isFinite(v.height) || !isFinite(v.scale))return false;
         try{return JSON.stringify(value).length<=32768;}catch(e:*){return false;}
         return false;
      }
   }
}
