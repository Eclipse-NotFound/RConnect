package rconnect.game { public class FrameBefore {
public static function samePoint(a:Object,b:Object):Boolean {
         if(a===b)return true;
         if(a==null || b==null)return false;
         var fields:int=0,otherFields:int=0;
         for(var key:String in a) {
            fields++;
            var left:*=a[key],right:*=b[key];
            if(left is Array && right is Array) {
               if(left.length!=right.length)return false;
               for(var i:int=0;i<left.length;i++)if(left[i]!==right[i])return false;
            } else if(left!==right)return false;
         }
         for(key in b)otherFields++;
         return fields==otherFields;
      }
public static function after(frames:Array,stamp:Number):Array {
         var out:Array=[];
         for each(var point:Object in frames){Counter.before++;if(Number(point.at)>stamp)out.push(point);}
         return out;
      }
}}
