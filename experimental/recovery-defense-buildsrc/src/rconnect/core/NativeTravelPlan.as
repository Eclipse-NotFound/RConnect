package rconnect.core {
   /** One in-flight native map build, independent of room ownership terms.
    * No native objects are discarded; no simulation or persistent state here. */
   public final class NativeTravelPlan {
      private var nonce:String,serial:int=0,remoteNonce:String="",retired:int=0;
      private var boundWorld:Object,boundGame:Object;
      private var adopted:Boolean=false;
      public var current:Object;
      public var started:Boolean=false;
      public var anchor:Object;
      public function NativeTravelPlan(sessionNonce:String) {nonce=sessionNonce;}
      public function get id():String {return current==null?"":String(current.travelId);}
      public function get consumed():Boolean {return adopted;}
      public static function valid(m:Object):Boolean {
         if(m==null || int(m.planVersion)!=1 || !(m.nonce is String) || String(m.nonce)=="" || String(m.nonce).length>128
            || Number(m.sequence)!=int(m.sequence) || int(m.sequence)<=0 || String(m.travelId)!=String(m.nonce)+":"+int(m.sequence))return false;
         var s:Object=m.info;if(s==null || !(s.curLandId is String) || s.curLandId=="" || s.curLandId.length>128
            || s.nativeCreate!==true || !(s.firstVisit is Boolean))return false;
         var n:Number=Number(s.constructorLevel);
         return s.constructorLevel!=null && isFinite(n) && n>=0 && n<=10000 && n==Math.floor(n)
            && (s.entryCoord==null || s.entryCoord is String && s.entryCoord.length<=128);
      }
      public function offer(info:Object,epoch:int,world:Object):Object {
         if(current!=null)throw new Error("Native travel already pending");
         current={type:"room",op:"prepare",planVersion:1,nonce:nonce,sequence:++serial,
            travelId:nonce+":"+serial,fromEpoch:epoch,info:info};
         if(!valid(current)){current=null;throw new Error("Invalid native travel decision");}
         boundWorld=world;boundGame=world.game;started=true;adopted=true;anchor=null;return current;
      }
      public function receive(msg:Object,world:Object,epoch:int):Boolean {
         if(!valid(msg))throw new Error("Invalid native travel plan");
         if(remoteNonce!="" && remoteNonce!=String(msg.nonce))throw new Error("Native travel session changed without reset");
         if(int(msg.sequence)<=retired)return false;
         if(current!=null) {
            if(id==String(msg.travelId))return false;
            throw new Error("Native travel cannot overtake an active entry");
         }
         if(epoch>0 && int(msg.fromEpoch)!=epoch)throw new Error("Native travel source epoch differs");
         remoteNonce=String(msg.nonce);current=msg;boundWorld=world;boundGame=world.game;started=false;adopted=false;anchor=null;return true;
      }
      public function markStarted(world:Object):void {
         if(current==null || started || !matchesWorld(world))throw new Error("Invalid native travel start");
         started=true;
      }
      public function adopt(world:Object,nativeGame:Object):Object {
         if(current==null || !started || adopted)return null;
         if(!matchesWorld(world) || nativeGame!==boundGame || String(nativeGame.curLandId)!=String(current.info.curLandId))
            throw new Error("Native travel world or target changed");
         adopted=true;return current.info;
      }
      public function matchesWorld(world:Object):Boolean {
         return current==null || boundWorld===world && world!=null && boundGame===world.game;
      }
      public function captureAnchor(info:Object):Object {
         if(current==null)return null;
         if(anchor!=null)return anchor;
         if(info==null || String(info.curLandId)!=String(current.info.curLandId)
            || info.x==null || info.y==null || !isFinite(Number(info.x)) || !isFinite(Number(info.y)))throw new Error("Native entry anchor unavailable");
         anchor={travelId:id,roomKey:String(info.roomKey),landX:info.landX,landY:info.landY,landZ:info.landZ,x:Number(info.x),y:Number(info.y)};
         return anchor;
      }
      public function acceptAnchor(value:Object):void {
         if(current==null || value==null || String(value.travelId)!=id
            || !(value.roomKey is String) || value.x==null || value.y==null || !isFinite(Number(value.x)) || !isFinite(Number(value.y)))
            throw new Error("Invalid native entry anchor");
         if(anchor==null)anchor={travelId:id,roomKey:value.roomKey,landX:value.landX,landY:value.landY,landZ:value.landZ,x:Number(value.x),y:Number(value.y)};
         else if(anchor.roomKey!==value.roomKey || anchor.x!==Number(value.x) || anchor.y!==Number(value.y))
            throw new Error("Native entry anchor changed");
      }
      public function retiredToken(token:*):Boolean {
         var value:String=String(token||""),prefix:String=remoteNonce!=""?remoteNonce:nonce;
         if(value.indexOf(prefix+":")!=0)return false;
         var n:Number=Number(value.substr(prefix.length+1));
         return isFinite(n) && n>=1 && n==Math.floor(n) && n<=retired;
      }
      public function accepts(token:*):Boolean {return current==null?String(token||"")=="":String(token)==id;}
      public function finish(token:String):void {
         if(current==null || token!=id)throw new Error("Wrong native travel completion");
         retired=Math.max(retired,int(current.sequence));current=null;boundWorld=null;boundGame=null;started=false;adopted=false;anchor=null;
      }
      public function cancel():void {if(current!=null)finish(id);}
      public function reset():void {current=null;boundWorld=null;boundGame=null;started=false;adopted=false;anchor=null;remoteNonce="";retired=0;}
   }
}
