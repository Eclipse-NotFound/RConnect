package {
   import rconnect.game.ExplorationSync;
   /** Independent copies of the original nibble union and native encoding. */
   public class ExplorationEncodingRegression {
      private static const HEX:String="0123456789abcdef";
      private static function originalUnion(a:Array,b:Array):Array {
         if(a==null)return b.concat();
         var out:Array=[];
         for(var y:int=0;y<b.length;y++) {
            var row:Array=[];
            for(var i:int=0;i<String(b[y]).length;i++) {
               var av:int=HEX.indexOf(a[y].charAt(i)),bv:int=HEX.indexOf(b[y].charAt(i));
               row.push(HEX.charAt(i%17==0?Math.max(av,bv):av|bv));
            }
            out.push(row.join(""));
         }
         return out;
      }
      private static function originalNative(loc:Object):Array {
         var result:Array=[];
         for(var y:int=0;y<loc.spaceY;y++) {
            var row:Array=[];
            for(var x:int=0;x<loc.spaceX;x++) {
               var v:Number=Number(loc.space[x][y].visi);
               var light:int=isNaN(v)?0:Math.max(0,Math.min(15,Math.round(v*15)));
               row.push(HEX.charAt(light)+(light>0?"ffffffffffffffff":"0000000000000000"));
            }
            result.push(row.join(""));
         }
         return result;
      }
      private static function same(a:Array,b:Array):Boolean {return JSON.stringify(a)===JSON.stringify(b);}
      private static function row(seed:int):String {
         var result:String="";
         for(var i:int=0;i<17*5;i++)result+=HEX.charAt((seed+i*7)%16);
         return result;
      }
      public static function run(check:Function,loc:Object):void {
         var cache:Array=[],cases:int=0,errors:int=0,hits:int=0;
         for(var a:int=0;a<16;a++)for(var b:int=0;b<16;b++) {
            var left:Array=[row(a),row((a+3)%16)],right:Array=[row(b),row((b+5)%16)];
            var expected:Array=originalUnion(left,right),actual:Array=ExplorationSync.unionRows(left,right,cache);
            cases++;if(!same(expected,actual))errors++;
            var first:Object=cache[0];actual[0]="caller changed result";
            actual=ExplorationSync.unionRows(left,right,cache);
            cases++;if(!same(expected,actual))errors++;
            if(first!=null && cache[0]===first)hits++;
            left[0]=row((a+1)%16);right[1]=row((b+1)%16);
            cases++;if(!same(originalUnion(left,right),ExplorationSync.unionRows(left,right,cache)))errors++;
         }
         check(errors==0,"exploration encoding matches original for "+cases+" cached, changing and caller-mutated row pairs");
         check(hits>200,"unchanged row pairs reuse the cached result without retaining caller arrays");
         var one:Array=[row(3)];
         check(same(ExplorationSync.unionRows(null,one,cache),one)&&cache.length==0,"new exploration history clears prior row cache");
         ExplorationSync.unionRows([row(1),row(2)],[row(3),row(4)],cache);
         check(same(ExplorationSync.unionRows([row(6)],one,cache),originalUnion([row(6)],one))&&cache.length==1,
            "changed room dimensions cannot reuse stale rows");
         check(same(ExplorationSync.nativeRows(loc),originalNative(loc)),"native exploration encoding matches original across the actual room");
         var values:Array=[NaN,Infinity,-Infinity,-1,0,.001,.033,.034,.5,.999,1,2],space:Array=[];
         for(var i:int=0;i<=15;i++)values.push(i/15);
         for each(var value:Number in values)space.push([{visi:value}]);
         var fixture:Object={spaceX:space.length,spaceY:1,space:space};
         check(same(ExplorationSync.nativeRows(fixture),originalNative(fixture)),"native tile strings preserve all brightness levels rounding and non-finite inputs");
      }
   }
}
