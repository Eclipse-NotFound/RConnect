package {
   public class LookupUnit {
      public var tag:String,X:Number,Y:Number;
      public var onRead:Function;
      private var identifier:String;
      public function LookupUnit(tag:String,id:String,x:Number=0,y:Number=0) {
         this.tag=tag;identifier=id;X=x;Y=y;
      }
      public function get id():String {
         var callback:Function=onRead;onRead=null;
         if(callback!=null)callback();
         return identifier;
      }
   }
}
