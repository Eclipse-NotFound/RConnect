package {
   import flash.display.DisplayObject;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;
   import rconnect.game.GameBridge;
   /** Optional aggregate-only observer. No production hook and no pixel read. */
   public class DensityTrajectoryTotals {
      private static const LIMIT:int=1024,POINT_LIMIT:int=64;
      private var sourceSeen:Dictionary=new Dictionary(true),sourceRows:Array=[];
      private var displaySeen:Dictionary=new Dictionary(true),displayRows:Array=[];
      private var streams:Object={},streamCount:int=0,overflow:int=0,sourceFrames:int=0,packets:int=0;
      public function source(guns:Array):void {
         sourceFrames++;var now:int=getTimer();
         for each(var gun:Object in guns) {
            var b:Object=GameBridge.probe(gun,"b");if(b==null || sourceSeen[b]!=null)continue;
            if(sourceRows.length>=LIMIT){overflow++;continue;}
            var row:Object={bullet:b,first:now,last:now,frames:0,positions:0,visualFrames:0,visualPositions:0,
               x:NaN,y:NaN,vx:NaN,vy:NaN,contactFirst:Boolean(GameBridge.probe(b,"babah")),ended:0};
            sourceSeen[b]=row;sourceRows.push(row);
         }
         for each(row in sourceRows) {
            if(row.ended>0)continue;b=row.bullet;
            var v:DisplayObject=GameBridge.probe(b,"vis") as DisplayObject;
            row.frames++;row.last=now;
            if(row.positions==0 || row.x!=Number(b.X) || row.y!=Number(b.Y))row.positions++;
            row.x=Number(b.X);row.y=Number(b.Y);
            if(v!=null && v.stage!=null && v.visible && v.alpha>0) {
               row.visualFrames++;if(row.visualPositions==0 || row.vx!=v.x || row.vy!=v.y)row.visualPositions++;
               row.vx=v.x;row.vy=v.y;
            }
            if(!Boolean(GameBridge.probe(b,"in_chain"))){row.ended=now;row.bullet=null;}
         }
      }
      public function display(v:DisplayObject):void {
         var row:Object=displaySeen[v],now:int=getTimer();
         if(row==null) {
            if(displayRows.length>=LIMIT){overflow++;return;}
            row={first:now,last:now,frames:0,positions:0,x:NaN,y:NaN};displaySeen[v]=row;displayRows.push(row);
         }
         row.frames++;row.last=now;
         if(row.positions==0 || Math.abs(v.x-row.x)+Math.abs(v.y-row.y)>.1)row.positions++;
         row.x=v.x;row.y=v.y;
      }
      public function receive(p:Object):void {
         if(p==null)return;
         if(p.units is Array){packets++;units(p.units);}
         if(p.enemyMotion is Array){packets++;units(p.enemyMotion);}
      }
      private function units(list:Array):void {
         for each(var unit:Object in list) {
            if(unit.weapons is Array)guns(String(unit.k),unit.weapons);
            if(unit.effects is Array)guns(String(unit.k),unit.effects);
         }
      }
      private function guns(owner:String,list:Array):void {
         for each(var gun:Object in list)if(gun.events is Array)for each(var event:Object in gun.events) {
            var f:Object=event.flight;if(f==null)continue;
            var key:String=owner+"/"+String(gun.id)+"/"+String(gun.variant)+"/"+String(gun.stream)+"/"+String(event.seq);
            var row:Object=streams[key],now:int=getTimer();
            if(row==null) {
               if(streamCount>=LIMIT){overflow++;continue;}
               row={first:now,last:now,points:{},count:0,endAtFirst:Number(f.end)>0,hasEnd:false,
                  bornAt:Number(f.bornAt),stopAt:Number(f.stopAt)};streams[key]=row;streamCount++;
            }
            row.last=now;row.hasEnd=row.hasEnd || Number(f.end)>0;
            if(f.frames is Array)for each(var point:Object in f.frames) {
               var stamp:String=String(point.at);
               if(row.points[stamp]==null && row.count>=POINT_LIMIT){overflow++;continue;}
               if(row.points[stamp]==null)row.count++;
               row.points[stamp]={x:Number(point.x),y:Number(point.y)};
            }
         }
      }
      public function flush(host:Boolean,phase:int,reason:String):void {
         var src:Object={observed:sourceRows.length,multiPositionFrames:0,multiVisiblePositionFrames:0,
            firstObservedAtContact:0,ended:0,openAtBoundary:0,lifetimeMs:[0,0,0,0],coverage:"gun.b once per native RENDER; unobserved/overwritten births unknown"};
         for each(var row:Object in sourceRows) {
            if(row.frames>=2 && row.positions>=2)src.multiPositionFrames++;
            if(row.visualFrames>=2 && row.visualPositions>=2)src.multiVisiblePositionFrames++;
            if(row.contactFirst)src.firstObservedAtContact++;
            if(row.ended>0)src.ended++;else src.openAtBoundary++;
            bucket(src.lifetimeMs,row.last-row.first);
         }
         var rx:Object={streams:streamCount,multiPositionFrames:0,zeroFrames:0,oneFrame:0,
            endedInFirstPacket:0,receivedEnd:0,packets:packets};
         for each(row in streams) {
            if(row.count==0)rx.zeroFrames++;if(row.count==1)rx.oneFrame++;
            var first:Object=null,moved:Boolean=false;
            for each(var point:Object in row.points){if(first==null)first=point;else if(point.x!=first.x || point.y!=first.y)moved=true;}
            if(row.count>=2 && moved)rx.multiPositionFrames++;
            if(row.endAtFirst)rx.endedInFirstPacket++;if(row.hasEnd)rx.receivedEnd++;
         }
         var view:Object={instances:displayRows.length,multiPositionFrames:0,oneFrame:0,lifetimeMs:[0,0,0,0]};
         for each(row in displayRows) {
            if(row.frames>=2 && row.positions>=2)view.multiPositionFrames++;if(row.frames==1)view.oneFrame++;
            bucket(view.lifetimeMs,row.last-row.first);
         }
         Log.d("DENSITY TRAJECTORY TOTALS "+JSON.stringify({role:host?"host":"join",phase:phase,reason:reason,
            diagnostic_only:true,sourceRenderFrames:sourceFrames,source:src,received:rx,display:view,
            perProjectileCorrelation:"unknown; source/display do not expose wire stream/seq",overflow:overflow,
            complete:overflow==0,lifetimeBinsMs:["0","1..50","51..200",">200"],phaseBoundaryCensoring:true}));
         sourceSeen=new Dictionary(true);sourceRows=[];displaySeen=new Dictionary(true);displayRows=[];
         streams={};streamCount=overflow=sourceFrames=packets=0;
      }
      private static function bucket(values:Array,age:int):void {values[age==0?0:(age<=50?1:(age<=200?2:3))]++;}
   }
}
