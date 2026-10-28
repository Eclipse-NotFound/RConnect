package authority {
   import flash.display.DisplayObjectContainer;
   /** Independent mod leases share B's actor scope and reliable input queue. */
   public final class AddonsBridge {
      private var access:NativeAccess,host:HostSession,apis:Object={},bound:Object={},inputValidators:Object={};
      private var order:Array=[];
      public function AddonsBridge(main:Object,access:NativeAccess,session:String,role:String,config:Object) {
         this.access=access;
         var container:DisplayObjectContainer=main as DisplayObjectContainer;
         try {
            for each(var spec:Array in [["addiction","AddictionAuthorityAPI"],["fa","FAAuthorityAPI"]]) {
               var id:String=spec[0];if(config[id]==null)continue;
               var carrier:Object=container==null?null:container.getChildByName(spec[1]);
               var entry:Object=NativeAccess.get(carrier,"authorityAPI");
               if(entry==null || entry.version!==1 || !(entry.attach is Function))throw new Error("Independent B addon unavailable: "+id);
               if(id=="fa" && !(entry.validInput is Function))throw new Error("B addon input contract unavailable: "+id);
               if(entry.validInput is Function)inputValidators[id]=entry.validInput;
               var api:Object=entry.attach({version:1,session:session,role:role,withPlayer:withPlayer,
                  submit:RConnectMod.instance.requestAddonAction,rebindContext:rebindContext,allowHarm:allowHarm});
               apis[id]=api;order.push(id);bound[id]={};
               for each(var method:String in ["register","profile","snapshot","present","execute","carryState","detach"])
                  if(api==null || api.version!==1 || !(api[method] is Function))throw new Error("B addon API mismatch: "+id+"."+method);
            }
         }catch(error:*) {dispose();throw error;}
      }
      public function profile():Object {
         var out:Object={};for each(var id:String in order)out[id]=apis[id].profile();return out;
      }
      public function bind(session:HostSession,remote:Object):void {
         host=session;
         var local:Object=profile();
         for each(var actor:PlayerActor in host.actors)ensure(actor,actor.id==0?local:remote);
      }
      public function ensure(actor:PlayerActor,initial:Object=null):void {
         var key:String=String(actor.id);
         for each(var id:String in order) {
            var record:Object=bound[id][key];
            if(record!=null && record.unit===actor.unit && record.epoch==actor.epoch)continue;
            var api:Object=apis[id],saved:Object=initial==null?null:initial[id];
            // A new epoch is a rebinding, not a second character import.
            withPlayer(key,actor.unit.loc,function():void {api.register(key,actor.unit,actor.epoch,saved);rebindContext(key);});
            bound[id][key]={unit:actor.unit,epoch:actor.epoch};
         }
      }
      private function actorFor(key:String):PlayerActor {
         if(host!=null)for each(var actor:PlayerActor in host.actors)if(String(actor.id)==key)return actor;
         throw new Error("Addon requested an unknown B actor");
      }
      private function allowHarm(source:Object,target:Object):Boolean {
         return host!=null && host.combat!=null && host.combat.enabled && source!==target &&
            (source===host.actors[0].unit || source===host.actors[1].unit) && (target===host.actors[0].unit || target===host.actors[1].unit);
      }
      private function rebindContext(key:String):void {
         var actor:PlayerActor=actorFor(key),ctx:Object=actor.context,g:Object=actor.unit;
         ctx.gg=g;ctx.pers=g.pers;ctx.invent=g.invent;
         if(ctx.stand!=null)ctx.stand.inv=g.invent;
         if(access.world.gg===g){access.world.pers=g.pers;access.world.invent=g.invent;}
      }
      private function withPlayer(key:String,room:Object,operation:Function):* {
         var actor:PlayerActor=actorFor(key);
         try{return access.scope.runRoom(actor.context,room==null?actor.unit.loc:room,operation);}
         finally {
            // A registering addon may replace Pers/Invent. NativeScope restores
            // the caller's references; repair only the same actor's root view.
            if(access.world.gg===actor.unit){access.world.pers=actor.context.pers;access.world.invent=actor.context.invent;}
         }
      }
      public function input():Object {
         var out:Object={};for each(var id:String in order)if(apis[id].input is Function)out[id]=apis[id].input();return out;
      }
      public function acceptsInput(value:Object):Boolean {
         if(!validInput(value))return false;
         if(value==null)return true;
         // Keep each mod's settings contract in that mod. Reject malformed
         // controls before accepting the packet, not during a player step.
         for(var id:String in value) {
            var validate:Function=inputValidators[id] as Function;
            if(validate==null)return false;
            try {if(validate(value[id])!==true)return false;}catch(error:*){return false;}
         }
         return true;
      }
      public static function blocksInput(value:Object):Boolean {
         if(value==null)return false;for each(var state:Object in value)if(state!=null && state.overlay===true)return true;return false;
      }
      public function beforePlayer(actor:PlayerActor,input:Object):void {
         for each(var id:String in order)if(apis[id].beforePlayer is Function)
            apis[id].beforePlayer(String(actor.id),actor.unit,actor.epoch,input.addons==null?null:input.addons[id]);
      }
      public function afterPlayer(actor:PlayerActor):void {
         for each(var id:String in order)if(apis[id].afterPlayer is Function)apis[id].afterPlayer(String(actor.id));
      }
      public function execute(actor:PlayerActor,action:Object):Boolean {
         return validAction(action) && apis[action.addon]!=null && apis[action.addon].execute(String(actor.id),action);
      }
      public function snapshot(id:int):Object {
         var out:Object={};for each(var name:String in order)out[name]=apis[name].snapshot(String(id));return out;
      }
      public function present(state:Object):void {
         if(state==null)return;for each(var id:String in order)if(state[id]!=null)apis[id].present(state[id]);
      }
      public function carryState(game:Object):void {for each(var id:String in order)apis[id].carryState(game);}
      public function dispose():void {
         for(var i:int=order.length-1;i>=0;i--){var api:Object=apis[order[i]];if(api!=null && api.detach is Function)api.detach();}
         apis={};bound={};inputValidators={};order=[];host=null;
      }
      public static function validInput(value:Object):Boolean {
         if(value==null)return true;
         for(var key:String in value)if(key!="fa")return false;
         if(value.fa!=null && (!(value.fa.overlay is Boolean) || value.fa.settings==null))return false;
         return bounded(value,8192);
      }
      public static function validAction(value:Object):Boolean {
         if(value==null || !(value.args is Array) || value.args.length>2 || !bounded(value,4096))return false;
         var key:String=value.key,args:Array=value.args;
         if(value.addon=="fa") {
            if(["grenade","bayonet","bipod","optic","grenadeMode","leaveGrenadeMode"].indexOf(key)>=0)return args.length==0;
            return key=="modify" && args.length==2 && identifier(args[0]) && args[1]!=null;
         }
         if(value.addon=="addiction") {
            if(key=="cancelAuto")return args.length==0;
            if(key=="treat")return args.length==1 && identifier(args[0]);
            return key=="dose" && args.length==2 && identifier(args[0]) && args[1] is Number && args[1]==int(args[1]) && args[1]>=1 && args[1]<=1000;
         }
         return false;
      }
      private static function identifier(value:*):Boolean{return value is String && value.length>0 && value.length<=80;}
      private static function bounded(value:Object,limit:int):Boolean {try{return JSON.stringify(value).length<=limit;}catch(error:*){return false;}return false;}
   }
}
