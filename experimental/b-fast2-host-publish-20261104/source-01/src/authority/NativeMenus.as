package authority {
 import fe.inter.AuthorityMenus;
 import fe.inter.AuthorityPip;
 import fe.inter.PipBuck;
 /** One adapter for original menu commits. Selection remains local; resource
  * mutations always re-enter the original handlers in the owner's scope. */
 public final class NativeMenus {
  private var access:NativeAccess,input:InputSource,host:HostSession,previous:Function;
  public function NativeMenus(access:NativeAccess,input:InputSource=null,host:HostSession=null) {
   this.access=access;this.input=input;this.host=host;
   var type:Class=access.definition("fe.inter.PipBuck");previous=type["rconnectMenu"];
   if(previous!=null)throw new Error("Native menu seam already occupied");
   type["rconnectMenu"]=receive;
  }
  private function receive(target:Object,key:String,args:Array):Boolean {
   if(AuthorityMenus.replaying>0 || NativeIntents.replaying>0)return false;
   var p:PipBuck=access.world.pip as PipBuck;
   if(target!==p && target!==access.world.stand && !AuthorityMenus.belongs(target,p))return false;
   if(key=="menuVendor")args=[args[0],AuthorityMenus.basket(target)];
   if(key=="menuAppearance")args=[PlainData.copy(access.world.app.save())];
   if(key=="menuQuest") {
    if(host!=null)return false;
    access.world.gui.infoText("剧情任务由宿主带队处理。");return true;
   }
   if(!NativeIntents.valid(key,args))throw new Error("Invalid native menu request "+key);
   if(input!=null)input.enqueue({type:"native",key:key,args:args});
   else if(host!=null && key!="menuClose" && key!="menuStandClose") {
    for each(var actor:PlayerActor in host.actors)if(actor.context.pip===p) {
     access.scope.run(actor.context,function():void {NativeIntents.execute(actor,key,args);});
     // Other staged selections are retained until a commit. That commit
     // regenerates its prices/stock, even if the other player traded first.
     break;
    }
   }
   return key!="menuClose" && key!="menuStandClose";
  }
  public function dispose():void {access.definition("fe.inter.PipBuck")["rconnectMenu"]=previous;}
 }
}
