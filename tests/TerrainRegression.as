package
{
   import rconnect.game.TerrainSync;
   /** Receipt ordering and authority tests; native bullet/graphics run separately. */
   public class TerrainRegression
   {
      public static function run(check:Function,terrainClass:Class=null):void
      {
         if(terrainClass==null) terrainClass=TerrainSync;
         var host:Object=room(20,16),sender:Object=new terrainClass();
         sender.hostPatch(host);
         for each(var column:Array in host.space) for each(var t:Object in column) {t.hp=0;t.phis=0;t.front="";t.opac=0;}
         var seen:Object={},count:int=0,bounded:Boolean=true;
         for(var round:int=0;round<3;round++)
            for each(var p:Object in sender.hostPatch(host))
            {
               var k:String=p.x+","+p.y;if(!seen[k]){seen[k]=true;count++;}
            }
         check(count==320,"terrain patch rotation covers all 320 changed tiles");

         host=room(3,2);var local:Object=room(3,2),client:Object=new terrainClass();sender=new terrainClass();
         sender.hostPatch(host);client.report(local);
         local.space[1][1].hp=40;
         client.apply(local,[{x:1,y:1,p:1,h:60,o:1}],true);
         var first:Object=client.report(local);
         check(local.space[1][1].hp==40 && first.tiles[0].damage==20,"arrival before report preserves predicted tile damage");
         var receipt:Object=sender.settle(host,"peer",first);
         sender.settle(host,"peer",first);
         check(host.calls==1 && host.space[1][1].hp==40,"duplicate terrain report settles native damage once");
         local.space[1][1].hp=25;
         client.apply(local,[{x:1,y:1,p:1,h:60,o:1}],true);
         client.acknowledge(local,receipt);
         var second:Object=client.report(local);
         check(local.space[1][1].hp==25 && second.tiles[0].damage==15,"receipt preserves subsequent unconfirmed hits");
         client.acknowledge(local,sender.settle(host,"peer",second));
         check(host.space[1][1].hp==25 && local.space[1][1].hp==25 && client.report(local)==null,"confirmed terrain converges without feedback damage");
         host.space[0][0].indestruct=true;
         sender.settle(host,"forged",{epoch:1,seq:1,tiles:[{x:0,y:0,damage:1000,destroy:true}]});
         check(host.space[0][0].hp==60 && host.space[0][0].phis==1,"host rejects damage to indestructible terrain");
         local.space[1][1].hp=10;var stale:Object=client.report(local),next:Object=room(3,2);
         client.report(next);client.acknowledge(next,{epoch:stale.epoch,seq:stale.seq,tiles:[{x:1,y:1,p:0,h:0,o:0}]});
         check(next.space[1][1].hp==60 && client.report(next)==null,"room change discards pending damage and stale receipts");
         var shaped:Object=next.space[2][1];shaped.setZForm=function(n:int):void {shaped.zForm=n;shaped.phY1=(1+n/4)*40;shaped.opac=0;};
         client.apply(next,[{x:2,y:1,zf:2,o:0.4}],true);
         check(shaped.phY1==60 && shaped.opac==0.4,"terrain shape recomputes collision bounds and final opacity");

         host=room(20,16);local=room(20,16);sender=new terrainClass();client=new terrainClass();
         sender.hostPatch(host);client.report(local);
         local.space[0][0].hp=50;first=client.report(local);
         receipt=sender.settle(host,"peer",first); // Receipt still in flight.
         for each(column in local.space)for each(t in column)t.hp-=15;
         var closing:Array=client.finishReports(local),settled:int=0;
         for each(var batch:Object in closing){sender.settle(host,"peer",batch);settled+=batch.tiles.length;}
         check(closing.length==3 && settled==320 && host.space[0][0].hp==35 && host.space[19][15].hp==45,
            "room closing drains all later wall hits despite an in-flight receipt");
         client.acknowledge(local,receipt);
         check(client.finishReports(local).length==0 && client.report(local)==null,
            "late receipt after room closing cannot replay or lose wall damage");

         host=room(3,4);sender=new terrainClass();client=new terrainClass();
         check(sender.hostPatch(host)==null && client.report(host)==null,"initial rectangular terrain has no changes");
         var quiet:Boolean=true;
         for(round=0;round<40;round++) quiet=quiet && sender.hostPatch(host)==null && client.report(host)==null;
         check(quiet,"repeated unchanged terrain scans do not send changes");
         host.space[2][3].front="B";
         var patch:Array=sender.hostPatch(host);
         check(patch.length==1 && patch[0].x==2 && patch[0].y==3 && patch[0].f=="B" && client.report(host)==null,
            "visual-only change is broadcast without a damage report");
         host.space[2][3].front="A";
         check(sender.hostPatch(host)==null && client.report(host)==null,"returning to baseline removes the terrain patch");

         // A flat x * currentHeight + y cache aliases other cells after resize.
         host=room(3,4);sender=new terrainClass();
         for(var x:int=0;x<3;x++)for(var y:int=0;y<4;y++)host.space[x][y].hp=60+x*10+y;
         sender.hostPatch(host);host.spaceY=2;
         check(sender.hostPatch(host)==null,"shrinking a rectangular room keeps each existing cell's baseline");
         host.spaceX=1;
         check(sender.hostPatch(host)==null,"shrinking room width does not invent tile changes");
         host.spaceY=4;host.spaceX=3;
         check(sender.hostPatch(host)==null,"restoring room dimensions keeps the original coordinate baseline");
         host.spaceY=5;
         for(x=0;x<3;x++)host.space[x][4]=room(1,1).space[0][0];
         patch=sender.hostPatch(host);
         var addedOnly:Boolean=patch!=null && patch.length==3;
         for each(p in patch)addedOnly=addedOnly && p.y==4;
         check(addedOnly,"room extension emits only newly added coordinates");

         host=room(2,3);sender=new terrainClass();sender.hostPatch(host);
         host.space[1][2].vid=null;patch=sender.hostPatch(host);
         check(patch!=null && patch.length==1 && patch[0].v===null,"null differs from a previously missing tile field");
         delete host.space[1][2].vid;
         check(sender.hostPatch(host)==null,"removing an optional field returns to the missing-field baseline");
         host.space[1][2].vid=NaN;
         check(sender.hostPatch(host).length==1 && sender.hostPatch(host).length==1,"NaN preserves strict native field comparison");
         delete host.space[1][2].vid;host.space[1][2]=null;
         check(sender.hostPatch(host)==null,"a missing tile is skipped without inventing a destruction request");
      }

      /** Fixed damage / receipt / visual history, independent of frame timing. */
      public static function replay(terrainClass:Class):Array
      {
         var host:Object=room(7,5),local:Object=room(7,5),out:Array=[];
         var sender:Object=new terrainClass(),client:Object=new terrainClass(),waiting:Array=[];
         sender.hostPatch(host);client.report(local);
         for(var tick:int=0;tick<180;tick++)
         {
            var x:int=(tick*3)%7,y:int=(tick*7)%5,t:Object=local.space[x][y];
            if(tick%2==0 && t.phis>0) {t.hp-=7;if(t.hp<=0){t.phis=0;t.opac=0;t.front="";}}
            if(tick%11==0)host.space[(x+1)%7][y].back="background-"+int(tick/11);
            var patch:Array=sender.hostPatch(host);client.apply(local,patch,true);
            var request:Object=client.report(local);
            if(request!=null)
            {
               var receipt:Object=sender.settle(host,"peer",request);
               out.push({tick:tick,request:request,receipt:receipt,
                  duplicate:sender.settle(host,"peer",request)});
               waiting.push(receipt);
            }
            if(tick%4==3 && waiting.length)client.acknowledge(local,waiting.shift());
            out.push({tick:tick,patch:patch,calls:host.calls});
         }
         for each(var batch:Object in client.finishReports(local))out.push({closing:sender.settle(host,"peer",batch)});
         // Flush host state after ordered room close; late receipts are harmless.
         for each(receipt in waiting)client.acknowledge(local,receipt);
         client.apply(local,sender.hostPatch(host),false);
         out.push({host:host.space,local:local.space,calls:host.calls,late:client.report(local)});
         return out;
      }

      private static function room(width:int,height:int):Object
      {
         var r:Object={spaceX:width,spaceY:height,space:[],calls:0};
         for(var x:int=0;x<width;x++)
         {
            r.space[x]=[];
            for(var y:int=0;y<height;y++) r.space[x][y]={X:x,Y:y,phis:1,front:"A",back:"",zad:"",zForm:0,water:0,stair:0,hp:60,opac:1,indestruct:false,door:null};
         }
         r.hitTile=function(t:Object,d:int,x:Number,y:Number):void {r.calls++;t.hp-=d;if(t.hp<=0){t.phis=0;t.opac=0;t.front="";}};
         r.dieTile=function(t:Object):void {r.calls++;t.phis=0;t.opac=0;t.front="";};
         return r;
      }
   }
}
