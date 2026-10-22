package pausecheck {
   public class FakeConfig {
      public var values:Object={pauseMenus:"1",pauseSats:"1"};
      public function getValue(k:String):String{return values[k];}
      public function setValue(k:String,v:String):void{values[k]=v;}
      public function save():void{}
   }
}
