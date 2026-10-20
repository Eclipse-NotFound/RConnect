package {
   import fe.loc.Tile;
   import rconnect.game.RoomTerrainView;
   import flash.display.BitmapData;
   public class RoomTerrainViewChecks {
      private static function room():Object {
         var r:Object={spaceX:2,spaceY:2,space:[],backobjs:[],isRebuild:false,isRecalc:false,
            cTransform:null,cTransformFon:null,backwall:"wall",backform:0,darkness:12,transpFon:false,
            tipWater:0,gas:0,homeStable:false,black:true,lightOn:0,limX:80,limY:80,color:""};
         r.grafon={loc:r};
         for(var x:int=0;x<2;x++) {r.space[x]=[];for(var y:int=0;y<2;y++)r.space[x][y]=new Tile(x,y);}
         return r;
      }
      public static function run(check:Function):void {
         var r:Object=room(),view:RoomTerrainView=new RoomTerrainView(r),t:Tile=r.space[1][1];
         t.hp=17;t.visi=.75;t.t_visi=.5;t.kont1=4;t.pont2=3;
         check(view.unchanged(r),"health, visibility and derived contours alone do not discard terrain raster");
         var refreshed:int=0,g:Object=r.grafon;
         g.lightBmp=new BitmapData(3,3,true,0);g.visLight={visible:false};
         g.setLight=function():void{refreshed++;};g.warShadow=function():void{refreshed++;};
         g.drawAllObjs=function():void{refreshed++;};
         view.refresh({black:true,cam:{setLoc:function(loc:Object):void{refreshed++;}},
            gui:{setAll:function():void{refreshed++;}}});
         check(t.kont1==0 && t.pont2==0 && t.hp==17 && t.visi==.75 && refreshed==5,
            "reuse retains local regional contours, incoming gameplay values and native non-raster refreshes");
         g.lightBmp.dispose();
         var changes:Array=[["phis",1],["shelf",true],["phY1",11],["zForm",2],["water",1],
            ["front","new-wall"],["back","new-back"],["zad","new-rear"],["vid",2],["vid2",3],
            ["fRear",true],["vRear",true],["v2Rear",true],["opac",.5],["floor",4],["door",{}]];
         for each(var change:Array in changes) {
            r=room();view=new RoomTerrainView(r);r.space[1][1][change[0]]=change[1];
            check(!view.unchanged(r),"native rendering change requires complete redraw: "+change[0]);
         }
         r=room();view=new RoomTerrainView(r);r.darkness++;
         check(!view.unchanged(r),"whole-room light style changes require redraw");
         r=room();view=new RoomTerrainView(r);r.backobjs.push({});
         check(!view.unchanged(r),"added backdrop cannot reuse the old raster");
         r=room();var b:Object={X:2,Y:3,vis:{}};r.backobjs.push(b);view=new RoomTerrainView(r);b.X=9;
         check(!view.unchanged(r),"moving existing backdrop cannot reuse the old raster");
         r=room();r.isRebuild=true;view=new RoomTerrainView(r);r.isRebuild=false;
         check(!view.unchanged(r),"pending terrain rebuild at capture never qualifies");
         r=room();view=new RoomTerrainView(r);r.isRecalc=true;
         check(!view.unchanged(r),"pending terrain recalculation after restore never qualifies");
         r=room();view=new RoomTerrainView(r);r.grafon.loc=room();
         check(!view.unchanged(r),"shared renderer pointing at another room cannot be reused");
         r=room();r.space[1][1]={};view=new RoomTerrainView(r);
         check(!view.unchanged(r),"non-native tile selects full redraw");
      }
   }
}
