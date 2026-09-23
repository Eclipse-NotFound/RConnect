package
{
   import rconnect.game.TerrainSync;
   /** Receipt ordering and authority tests; native bullet/graphics run separately. */
   public class TerrainRegression
   {
      public static function run(check:Function):void
      {
         var host:Object=room(20,16),sender:TerrainSync=new TerrainSync();
         sender.hostPatch(host);
         for each(var column:Array in host.space) for each(var t:Object in column) {t.hp=0;t.phis=0;t.front="";t.opac=0;}
         var seen:Object={},count:int=0,bounded:Boolean=true;
         for(var round:int=0;round<3;round++)
            for each(var p:Object in sender.hostPatch(host))
            {
               var k:String=p.x+","+p.y;if(!seen[k]){seen[k]=true;count++;}
            }
         check(count==320,"terrain patch rotation covers all 320 changed tiles");

         host=room(3,2);var local:Object=room(3,2),client:TerrainSync=new TerrainSync();sender=new TerrainSync();
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
