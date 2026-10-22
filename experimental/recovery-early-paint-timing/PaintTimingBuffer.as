package {
   import flash.utils.Dictionary;

   /** External diagnostic driver helper, not a gameplay class. At most 32
    * ensure-work completions per begin/finish transaction, never per-frame I/O.
    * begin and finish must be called by the existing external travel fixture. */
   public final class PaintTimingBuffer {
      private static const LIMIT:int=32;
      private var nativeClass:Object,own:Function;
      private var expectedWorld:Object,expectedGame:Object,expectedRenderer:Object;
      private var token:String="",rows:Array=[],locations:Dictionary;
      private var locationSerial:int=0,overflow:Boolean=false,faults:int=0;
      private var nativeFaultStart:uint=0,ownDetached:Boolean=false;
      public function PaintTimingBuffer(grafonClass:Object) {
         nativeClass=grafonClass;own=receive;
      }
      public function begin(transaction:String,world:Object,game:Object,renderer:Object):void {
         if(token!="" || transaction=="" || world==null || game==null || renderer==null)
            throw new Error("Invalid paint-timing transaction");
         if(!("rconnectPaintTimingBridge" in nativeClass) || !("rconnectPaintTimingFaults" in nativeClass)
            || nativeClass.rconnectPaintTimingBridge!=null)
            throw new Error("Paint-timing bridge is unavailable or already owned");
         token=transaction;expectedWorld=world;expectedGame=game;expectedRenderer=renderer;
         rows=[];locations=new Dictionary(true);locationSerial=0;overflow=false;faults=0;
         nativeFaultStart=uint(nativeClass.rconnectPaintTimingFaults);ownDetached=false;
         nativeClass.rconnectPaintTimingBridge=own;
      }
      private function detach():void {
         if(nativeClass.rconnectPaintTimingBridge===own){nativeClass.rconnectPaintTimingBridge=null;ownDetached=true;}
      }
      private function receive(renderer:Object,world:Object,game:Object,loc:Object,value:Object):void {
         try {
            if(token=="")return;
            // Call 33 records no row, marks incompleteness, and unsubscribes.
            // It does not truncate a supposedly valid trace silently.
            if(rows.length>=LIMIT){overflow=true;detach();return;}
            if(value==null || value.phase!=="ensure-work")throw new Error("Unexpected paint-timing record");
            var location:int=0;
            if(loc!=null) {
               if(locations[loc]===undefined)locations[loc]=++locationSerial;
               location=int(locations[loc]);
            }
            rows.push({transaction:token,sequence:rows.length+1,location:location,
               sameWorld:world===expectedWorld&&value.sameWorld===true,
               sameGame:game===expectedGame&&value.sameGame===true,
               sameRenderer:renderer===expectedRenderer&&value.worldRendererAtStart===true&&value.worldRendererAtEnd===true,
               sameLoc:value.sameLoc===true&&value.worldLocAtStart===true&&value.worldLocAtEnd===true,
               phase:String(value.phase),preload:value.preload===true,initial:value.initial===true,
               started:int(value.started),finished:int(value.finished),
               startedWall:Number(value.startedWall),finishedWall:Number(value.finishedWall),
               completed:value.completed===true,residentBefore:int(value.residentBefore),residentAfter:int(value.residentAfter),
               left:Number(value.left),top:Number(value.top),width:Number(value.width),height:Number(value.height)});
         }catch(ignored:*){faults++;detach();}
      }
      public function finish():Object {
         var slot:Function=nativeClass.rconnectPaintTimingBridge;
         var ownershipPreserved:Boolean=slot===own||(ownDetached&&slot==null);
         var nativeFaults:uint=uint(uint(nativeClass.rconnectPaintTimingFaults)-nativeFaultStart);
         detach();
         var result:Object={diagnosticOnly:true,transaction:token,limit:LIMIT,
            overflow:overflow,faults:faults,nativeFaults:nativeFaults,ownershipPreserved:ownershipPreserved,rows:rows};
         token="";expectedWorld=expectedGame=expectedRenderer=null;locations=null;rows=[];
         return result;
      }
   }
}
