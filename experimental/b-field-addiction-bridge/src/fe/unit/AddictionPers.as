package fe.unit {
 import addiction.Runtime;import flash.utils.describeType;
 public dynamic class AddictionPers extends Pers {
  public var controller:Runtime;
  public function AddictionPers(old:Pers,runtime:Runtime) {
   super();
   for each(var v:XML in describeType(old).variable)this[String(v.@name)]=old[String(v.@name)];
   for(var k:String in old)this[k]=old[k];
   rep1=old.rep1;rep2=old.rep2;rep3=old.rep3;rep4=old.rep4;
   xml_head=old.xml_head;xml_tors=old.xml_tors;xml_legs=old.xml_legs;xml_blood=old.xml_blood;xml_mana=old.xml_mana;
   controller=runtime;
  }
  override public function setParameters():* {
   // Joining replicas receive the host's final fields. UI refreshes must not
   // recalculate those values using a second, local addiction clock.
   if(controller&&!controller.parametersAllowed())return;
   var effect:Object=controller?controller.beforeParameters():null;
   try{super.setParameters();}finally{if(controller)controller.afterParameters(effect);}
  }
  override public function save():Object {
   var data:Object=super.save();if(controller)controller.nativeSave(data);return data;
  }
 }
}
