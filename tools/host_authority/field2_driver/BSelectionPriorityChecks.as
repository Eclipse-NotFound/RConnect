package {
   import flash.system.ApplicationDomain;
   /** Real native Box constructors assign fractional cursor priorities. The
    * isolated scene contains no simulated or replicated gameplay objects. */
   public final class BSelectionPriorityChecks {
      public static function run(mod:Object,domain:ApplicationDomain,check:Function):void {
         var w:Object=mod.access.world,room:Object=w.loc;
         var Box:Class=mod.access.definition("fe.loc.Box"),Scene:Class=domain.getDefinition("authority.ReplicaScene") as Class;
         var boxes:Array=[],scene:Object=new Scene(mod.access),low:Object=null,high:Object=null;
         var old:Object=room.celObj,dist:Number=room.celDist,cx:Number=w.celX,cy:Number=w.celY;
         var pointX:Number=Math.max(160,Math.min(room.limX-160,w.gg.X+80));
         var pointY:Number=Math.max(160,Math.min(room.limY-1,w.gg.Y)),details:Array=[];
         var tileFields:Array=["front","phis","opac","door","mat","hp","thre"],savedTiles:Array=[],counts:Object={};
         var flags:Object={isRelight:room.isRelight,isRebuild:room.isRebuild,relight_t:room.relight_t};
         var ids:Array=["case","door1b","term1"],id:String,field:String;
         // initDoor writes the real grid during construction, before addObj.
         // Preserve references (especially tile.door), not scalar-only copies.
         for(var tx:int=0;tx<room.spaceX;tx++)for(var ty:int=0;ty<room.spaceY;ty++) {
            var tile:Object=room.space[tx][ty],saved:Object={tile:tile,values:{}};
            for each(field in tileFields)saved.values[field]=tile[field];savedTiles.push(saved);
         }
         for each(id in ids)if(room.land.kolAll!=null)counts[id]={had:room.land.kolAll.hasOwnProperty(id),value:room.land.kolAll[id]};
         try {
            // These three assets already appear in the real interaction
            // drivers. Keep their authored dimensions and native priorities.
            for each(id in ids) {
               var object:Object=new Box(room,id,pointX,pointY,<obj set="1" cont="empty" lock="0" mine="0"/>);boxes.push(object);
               details.push({id:id,priority:object.prior,w:object.scX,h:object.scY});
            }
            for(var i:int=0;i<boxes.length && low==null;i++)for(var j:int=i+1;j<boxes.length;j++) {
               var a:Object=boxes[i],b:Object=boxes[j];
               if(int(a.prior)==int(b.prior) && a.prior!=b.prior) {
                  low=a.prior<b.prior?a:b;high=a.prior>b.prior?a:b;break;
               }
            }
            check(low!=null,"cursor priority: native Box assets have distinct fractional priorities in the same band",details);
            if(low!=null) {
               var x1:Number=Math.max(low.X1,high.X1),x2:Number=Math.min(low.X2,high.X2);
               var y1:Number=Math.max(low.Y1,high.Y1),y2:Number=Math.min(low.Y2,high.Y2);
               check(x1<x2 && y1<y2,"cursor priority: authored Box hit rectangles genuinely overlap");
               var x:Number=(x1+x2)/2,y:Number=(y1+y2)/2;
               scene.room=room;
               for each(var order:Array in [[low,high],[high,low]]) {
                  low.onCursor=7.25;high.onCursor=4.5;
                  var selected:Object=scene.selection(order,x,y);
                  check(selected===high,"cursor priority: readonly hover chooses native higher fraction in either order",
                     {first:order[0].prior,second:order[1].prior,selected:selected==null?null:selected.prior,expected:high.prior});
                  check(low.onCursor==7.25 && high.onCursor==4.5,"cursor priority: readonly selection leaves native marks untouched");
                  w.celX=x;w.celY=y;scene.pointer(order);
                  check(room.celObj===high && low.onCursor===low.prior && high.onCursor===high.prior,
                     "cursor priority: native UI pointer keeps complete fractional marks in either order");
               }
            }
         } finally {
            room.celObj=old;room.celDist=dist;w.celX=cx;w.celY=cy;
            for each(var box:Object in boxes)box.remVisual();
            for each(saved in savedTiles)for each(field in tileFields)saved.tile[field]=saved.values[field];
            for(field in flags)room[field]=flags[field];
            for(id in counts)if(counts[id].had)room.land.kolAll[id]=counts[id].value;else delete room.land.kolAll[id];
         }
      }
   }
}
