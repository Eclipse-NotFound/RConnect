package fe.unit {
 import addiction.Runtime;import flash.utils.describeType;
 public class AddictionInvent extends Invent {
  public var controller:Runtime;
  public function AddictionInvent(old:Invent,runtime:Runtime) {
   super(old.owner,{weapons:[],armors:[],items:{},fav:[]});
   for each(var v:XML in describeType(old).variable) this[String(v.@name)]=old[String(v.@name)];
   controller=runtime;
  }
  override public function usePotion(id:String=null,organ:int=0):Boolean {
   if(controller && controller.handles(id))return controller.dose(id,1);
   return super.usePotion(id,organ);
  }
 }
}
