package authority {
   import fe.inter.AuthoritySats;
   public class InputSource {
      public var seq:int=0,action:int=0;
      public var scene:ReplicaScene;
      public var settings:Object={allowGrab:false,struggle:true,thrownDamage:false,follow:false};
      private var satsActive:Boolean=false;
      private var pending:Array=[];
      private var flight:Array=[];
      public function acknowledge(id:int):void {while(flight.length>0 && flight[0].id<=id)flight.shift();}
      public function enqueue(value:Object):void {if(pending.length>=48)throw new Error("Too many pending UI actions");pending.push(value);}
      public function frame(world:Object,session:String,player:int,room:String):Object {
         var c:Object=world.ctr,b:int=0,a:Array=[];
         if(player==1)localSelector(world);
         for(var i:int=0;i<Commands.HELD.length;i++)if(c[Commands.HELD[i]])b|=1<<i;
         if(c.keyReload){a.push({id:++action,type:"reload"});c.keyReload=false;}
         for each(var key:String in Commands.ONCE)if(c[key]){a.push({id:++action,type:"control",key:key});c[key]=false;}
         if(player==1 && satsActive && !world.sats.active && scene!=null) {
            a.push({id:++action,type:"sats",plan:AuthoritySats.plan(world.sats.que,scene.keyFor)});world.sats.clearAll();
         }
         satsActive=world.sats.active;
         while(pending.length>0 && a.length<16) {var request:Object=pending.shift();request.id=++action;a.push(request);}
         if(flight.length+a.length>64)throw new Error("Native action confirmation backlog");
         flight=flight.concat(a);a=flight.slice(0,16);
         if(SharedPause.requested(world))b=0;
         return {type:"input",session:session,player:player,room:room,roomEpoch:1,epoch:1,weaponEpoch:1,
            seq:++seq,buttons:b,aimX:Number(world.celX),aimY:Number(world.celY),actions:a,settings:settings,pause:SharedPause.requested(world)};
      }
      public function localSelector(world:Object):void {
         var g:Object=world.gg,c:Object=world.ctr,gui:Object=world.gui;
         if(!SharedPause.requested(world) && g.ggControl && !g.autoAttack && g.t_work<=0) {
            if(c.keyScrDown || c.keyScrUp)gui.showSelector(c.keyScrDown?1:-1,c.keyRun?1:0);
            c.keyScrDown=c.keyScrUp=false;
         }
         if(!gui.vis.selector.visible)return;
         if(c.keyTele){gui.unshowSelector(0);c.keyTele=false;}
         else if(c.keyAttack){gui.unshowSelector(1);c.keyAttack=false;}
         for(var i:int=1;i<=12;i++)if(c["keyWeapon"+i])gui.unshowSelector(0);
      }
   }
}
