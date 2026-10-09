package {
   import flash.display.Sprite;
   import flash.geom.ColorTransform;
   import rconnect.game.PlayerBodyEffects;

   /** Original array-based channel algorithm against actual AIR transforms. */
   public class BodyTintRegression {
      private static function colors(v:Sprite):Array {
         var c:ColorTransform=v.transform.colorTransform;
         return [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
            c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];
      }
      private static function clamp(n:*,lo:Number,hi:Number,fallback:Number=0):Number {
         return Math.max(lo,Math.min(hi,n!=null && isFinite(Number(n))?Number(n):fallback));
      }
      private static function reference(v:Sprite,a:Array,enemy:Boolean):void {
         if(a==null || a.length!=8)return;
         if(enemy) {
            a=a.concat();var current:Array=colors(v);a[3]=current[3];a[7]=current[7];
         }
         var values:Array=[];
         for(var i:int=0;i<8;i++)values.push(i<4?clamp(a[i],-16,16,1):clamp(a[i],-4096,4096));
         v.transform.colorTransform=new ColorTransform(values[0],values[1],values[2],values[3],
            values[4],values[5],values[6],values[7]);
      }
      public static function run(check:Function):void {
         var values:Array=[null,undefined,NaN,Infinity,-Infinity,-5000,-17,-1,0,.35,1,16,17,4096,5000,"0.5"];
         var good:Boolean=true,immutable:Boolean=true,count:int=0;
         var actual:Sprite=new Sprite(),expected:Sprite=new Sprite(),unit:Object={vis:actual};
         var effects:PlayerBodyEffects=new PlayerBodyEffects();
         for(var mode:int=0;mode<2;mode++)for(var seed:int=0;seed<128;seed++) {
            var source:Array=[];
            for(var channel:int=0;channel<8;channel++)source.push(values[(seed+channel*3)%values.length]);
            if(seed%29==0)source=[];
            if(seed%31==0)source=null;
            var before:String=JSON.stringify(source);
            actual.transform.colorTransform=expected.transform.colorTransform=
               new ColorTransform(1,.5,1.5,(seed%7)/6,seed,-seed,seed%9,seed-64);
            reference(expected,source,mode==0);
            effects.apply(unit,{player:mode==1,c:source},false);
            var a:Array=colors(actual),b:Array=colors(expected);
            for(channel=0;channel<8;channel++){good=good && a[channel]===b[channel];count++;}
            immutable=immutable && JSON.stringify(source)==before;
         }
         check(good,"body tint matches original native channels in "+count+" comparisons including enemy alpha");
         check(immutable,"body tint never changes incoming color arrays");
         effects.reset();
      }
   }
}
