package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import fe.World;
 import lad.OrdinaryRasterHarness;
 public class OrdinaryRasterChecks extends Sprite {
  private var rows:Array=[],h:OrdinaryRasterHarness,g:FixtureGrafon,w:Object,loc:Object,bo:Object,t:Object;
  public function OrdinaryRasterChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
  private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
  private function setup():void {
   h=new OrdinaryRasterHarness();g=new FixtureGrafon();
   bo={id:'light1',slot:1,vis:{color:0xffeeee00},light:{color:0xff00eeee},erase:{frame:1}};
   loc={spaceX:48,spaceY:25,active:true,backobjs:[bo],grafon:g};
   var land:Object={act:{rnd:true},loc:loc};loc.land=land;
   var player:Object={loc:loc};loc.gg=player;g.loc=loc;
   w={t_exit:19,allStat:1,game:{},gg:player,land:land,loc:loc,grafon:g,verror:{visible:false},cam:{setZoom:function():void{}}};
   World.w=w;t=null;
  }
  private function omitted():void {t=h.beginOrdinaryRaster(w,g,loc,true);g.paint(t.omit);h.completeOrdinaryRaster(t,true);}
  private function exercise():void {
   setup();var original:Object=bo.vis;var light:Object=bo.light;var erase:Object=bo.erase;
   t=h.beginOrdinaryRaster(w,g,loc,true);
   check(t!=null && t.lamps.length==1 && t.omit[bo]===true,'eligible first raster obtains exact lamp set');
   check(bo.vis===original && bo.light===light && bo.erase===erase,'prepare retains all original object references');
   g.paint(t.omit);h.completeOrdinaryRaster(t,true);
   check(t.complete && t.redrawComplete==11,'only one completed original draw qualifies ticket');
   check(h.eligibleSet(loc,[{bo:bo}]),'exact discovered set accepts omitted raster');
   check(g.sceneRedraws==11 && g.pixels().getPixel32(1,1)==0xff112233,'accepted helper does not invoke extra BAKE');
   h.completeOrdinaryRaster(t,true);
   check(h.pending()===t && t.complete && g.sceneRedraws==11,'duplicate completion is idempotent and does not redraw');

   setup();omitted();g.pixels().setPixel32(4,0,0xffff0044);original=bo.vis;
   h.cancel();
   check(h.pending()==null && bo.vis===original,'completed cancellation releases ticket and retains object reference');
   check(g.sceneRedraws==13,'fallback uses original two-pass BAKE');
   check(g.pixels().getPixel32(1,1)==0xffeeee00 && g.pixels().getPixel32(1,2)==0xff00eeee && g.pixels().getPixel32(1,3)==0,'fallback restores vis light and erase contributions');
   check(g.pixels().getPixel32(4,0)==0xffff0044,'same-frame mark survives real BitmapData comparison and restoration');
   check(g.pixels(1).getPixel32(1,1)==0xffeeee00 && g.pixels(2).getPixel32(1,1)==0xffeeee00 && g.pixels(3).getPixel32(1,2)==0xff00eeee,'all four BAKE surfaces receive restored lamp pixels');
   h.cancel();check(g.sceneRedraws==13,'duplicate cancellation is inert');

   setup();omitted();bo.vis={color:0xff4466aa};original=bo.vis;
   check(!h.eligibleSet(loc,[]),'discovered-set mismatch rejects optimization');
   check(bo.vis===original && g.pixels().getPixel32(1,1)==0xff4466aa,'fallback restores current references and current lamp appearance');

   setup();t=h.beginOrdinaryRaster(w,g,loc,true);h.cancel();
   check(t.cancelled && h.pending()===t && bo.vis!=null,'cancellation during native draw waits without stripping references');
   g.paint(t.omit);h.completeOrdinaryRaster(t,true);
   check(h.pending()==null && g.sceneRedraws==13 && g.pixels().getPixel32(1,1)==0xffeeee00,'cancelled draw restores native pixels after completion');

   setup();t=h.beginOrdinaryRaster(w,g,loc,true);g.paint(t.omit);h.enabled=false;h.completeOrdinaryRaster(t,true);
   check(h.pending()==null && g.pixels().getPixel32(1,1)==0xffeeee00,'disabled runtime restores omitted pixels');

   setup();omitted();bo.vis={color:0xff334488};g.drawLoc(loc);var count:int=g.sceneRedraws;
   check(!h.eligibleSet(loc,[{bo:bo}]),'intervening full redraw invalidates omitted-raster optimization');
   check(g.sceneRedraws==count && g.pixels().getPixel32(1,1)==0xff334488,'completed native redraw is neither repeated nor rolled back');

   setup();omitted();var oldG:FixtureGrafon=g;World.w={};h.cancel();
   check(h.pending()==null && oldG.sceneRedraws==11 && bo.vis!=null,'world replacement discards ticket without repainting another world');

   setup();t=h.beginOrdinaryRaster(w,g,loc,true);h.completeOrdinaryRaster(t,false);
   check(h.pending()==null && bo.vis!=null && g.sceneRedraws==10,'failed native draw preserves original error outcome and references');

   setup();omitted();original=bo.vis;light=bo.light;erase=bo.erase;g.failNext=true;var caught:Boolean=false;
   try{h.cancel();}catch(expected:*){caught=true;}
   check(caught && h.pending()==null,'BAKE failure propagates rather than claiming successful restoration');
   check(bo.vis===original && bo.light===light && bo.erase===erase,'BAKE failure finally restores all temporarily cleared references');

   setup();check(h.beginOrdinaryRaster(w,g,loc,false)==null,'revisit is excluded');
   setup();w.t_exit=0;check(h.beginOrdinaryRaster(w,g,loc,true)==null,'ordinary doorway is excluded');
   setup();g.sceneLarge=true;check(h.beginOrdinaryRaster(w,g,loc,true)==null,'merged large scene is excluded');
   setup();h.enabled=false;check(h.beginOrdinaryRaster(w,g,loc,true)==null,'disabled lighting is excluded');
   setup();loc.land.act.rnd=false;check(h.beginOrdinaryRaster(w,g,loc,true)==null,'nonrandom scripted map is excluded');
   setup();loc.spaceX=49;check(h.beginOrdinaryRaster(w,g,loc,true)==null,'oversize room is excluded');
   setup();loc.active=false;check(h.beginOrdinaryRaster(w,g,loc,true)==null,'inactive room is excluded');
   setup();w.gg={loc:loc};check(h.beginOrdinaryRaster(w,g,loc,true)==null,'mismatched native player identity is excluded');
   setup();h.attachIdentity(loc);check(h.beginOrdinaryRaster(w,g,loc,true)==null,'already attached room is excluded');
   setup();h.attachIdentity(null,loc);check(h.beginOrdinaryRaster(w,g,loc,true)==null,'previous failed room is excluded');
   setup();loc.backobjs=[];check(h.beginOrdinaryRaster(w,g,loc,true)==null,'zero lamps leaves original path unchanged');
   setup();loc.backobjs=[bo,bo];check(h.beginOrdinaryRaster(w,g,loc,true)==null && h.pending()==null,'duplicate native object identity is rejected before ownership');
  }
  private function begin(event:Event):void {
   removeEventListener(Event.ADDED_TO_STAGE,begin);
   try{exercise();}catch(error:*){check(false,'uncaught '+error);}
   var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
   var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath('result.json'),FileMode.WRITE);
   f.writeUTFBytes(JSON.stringify({assertions:rows,failed:failed,passed:failed==0}));f.close();
   NativeApplication.nativeApplication.exit(failed==0?0:1);
  }
 }
}
