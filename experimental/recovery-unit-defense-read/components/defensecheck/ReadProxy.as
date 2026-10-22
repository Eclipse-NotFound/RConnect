package defensecheck {
   import flash.utils.Proxy;
   import flash.utils.flash_proxy;
   public dynamic class ReadProxy extends Proxy {
      public var traceCalls:Array=[];
      public var values:Object;
      public var mode:String;
      public function ReadProxy(values:Object,mode:String="normal") {this.values=values;this.mode=mode;}
      override flash_proxy function hasProperty(name:*):Boolean {
         var key:String=String(name);traceCalls.push("has:"+key);
         if(mode=="has-throws" && key=="armor")throw new Error("fixture has armor");
         if(mode=="missing" && key=="armor")return false;
         return key in values;
      }
      override flash_proxy function getProperty(name:*):* {
         var key:String=String(name);traceCalls.push("get:"+key);
         if(mode=="get-throws" && key=="armor")throw new Error("fixture get armor");
         if(mode=="undefined" && key=="armor")return undefined;
         return values[key];
      }
   }
}
