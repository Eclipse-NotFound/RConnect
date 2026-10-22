package {
   public final class FakePaintTailApi {
      public var owner:Object,t:int=100,data:Array=[],ops:Array=[],starts:int=0,pauses:int=0,stops:int=0,fail:String="";
      public var countOverride:int=-1;
      public function now():int{return t;}
      public function wall():Number{return 10000+t;}
      public function claim(token:Object):Boolean {if(owner!=null)return false;owner=token;return true;}
      public function owns(token:Object):Boolean{return owner===token;}
      private function call(token:Object,name:String):void {
         if(owner!==token)throw new Error("foreign token");ops.push(name);t++;
         if(fail==name){fail="";throw undefined;}
      }
      public function release(token:Object):void{call(token,"release");owner=null;}
      public function clear(token:Object):void{call(token,"clear");}
      public function internalAllocs(token:Object,value:Boolean):void{call(token,"internalAllocs");}
      public function start(token:Object):void{starts++;call(token,"start");}
      public function pause(token:Object):void{pauses++;call(token,"pause");}
      public function stop(token:Object):void{stops++;call(token,"stop");}
      public function count(token:Object):Number{call(token,"count");return countOverride<0?data.length:countOverride;}
      public function samples(token:Object):Object{call(token,"samples");return data;}
      public function kind(token:Object,sample:Object):int{call(token,"kind");return sample.kind;}
      public function stack(token:Object,sample:Object):Object{call(token,"stack");return sample.frames;}
   }
}
