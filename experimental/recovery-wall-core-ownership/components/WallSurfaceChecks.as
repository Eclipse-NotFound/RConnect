package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.BitmapData;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.geom.Rectangle;
 import flash.system.ApplicationDomain;
 import fe.graph.Grafon;
 import rconnect.game.WallImpactVisuals;
 import rconnect.game.WallBefore;
 import rconnect.net.RoomCodec;
 public class WallSurfaceChecks extends Sprite {
  private var assertions:Array=[],failed:int=0;
  private var ownershipObservations:Array=[];
  public function WallSurfaceChecks(){addEventListener(Event.ADDED_TO_STAGE,run);}
  private function check(value:Boolean,label:String):void{assertions.push({label:label,passed:value});if(!value)failed++;}
  private function loc(w:int=80,h:int=60):Object {
   var o:Object={spaceX:w,spaceY:h,space:[],firstObj:null};for(var x:int=0;x<w;x++){o.space[x]=[];for(var y:int=0;y<h;y++)o.space[x][y]={phis:1,hp:100};}return o;
  }
  private function wall():WallImpactVisuals{var w:WallImpactVisuals=new WallImpactVisuals({loaderInfo:{applicationDomain:ApplicationDomain.currentDomain}});w.networkActive=true;return w;}
  private function wire(x:int,y:int,offset:int,color:uint,v:int=100):Array{return [{x:x,y:y,v:v,d:RoomCodec.pack([offset,Number(color)])}];}
  private function pixels(s:Object,x:int,y:int):uint{return BitmapData(s.nativeBuffers[0]).getPixel32(x-s.x,y-s.y);}
  private function same(a:*,b:*):Boolean {
   if(a===b)return true;if(a==null||b==null||typeof a!=typeof b)return false;if(typeof a!="object")return false;
   if((a is Array)!=(b is Array))return false;if(a is Array&&a.length!=b.length)return false;
   var k:String,n:int=0,m:int=0;for(k in a){n++;if(!b.hasOwnProperty(k)||!same(a[k],b[k]))return false;}for(k in b)m++;return n==m;
  }
  // The production WallSurfaceBridge / WallImpactVisuals / codecs are complete
  // recovery18 classes. Grafon's existing fixture preserves the native
  // before -> native draw -> after -> raster call order. Only native decal
  // rendering is represented by its existing fillRect/tint fixture.
  // Values and chunk geometry below are from run 386a671a97, hit 7.
  private function ownershipCase(core:uint,peer:uint,label:String):void {
   var local:Object=loc(80,120),graph:Grafon=new Grafon(local),visual:WallImpactVisuals=wall();
   graph.rectX=400;graph.rectY=400;
   var area:Rectangle=new Rectangle(664,4463,1,1),wrong:uint=0xff676861;
   graph.hit(area,wrong); // No resident buffer: mark birth, no invented pixels.
   var gutter:BitmapData=graph.rebuild(new Rectangle(280,4120,400,400),null,wrong);
   var first:uint=ownershipColor(visual,local),request:Object=visual.report(local,false);
   if(peer!=0) {
    // ACK explicitly releases existing prediction protection. The later
    // receive is a genuine new accepted peer write, even if its color equals
    // the former gutter sample; it must keep the existing authority barrier.
    visual.acknowledge(local,{seq:request.seq,cells:request.cells});
    visual.receive(local,wire(16,111,23*40+24,peer,900),true);
   }
   var listener:Function=Grafon.rconnectWallBridge;
   var observed:Object={nativeBeforeRaster:0,replayedAfterRaster:0,calls:0};
   Grafon.rconnectWallBridge=function(...args):Object {
    var isRaster:Boolean=args[0]=="raster";
    var target:BitmapData=args[3] as BitmapData;
    if(isRaster) {observed.nativeBeforeRaster=target.getPixel32(664-int(args[4]),4463-int(args[5]));observed.calls++;}
    var answer:Object=listener.apply(null,args);
    if(isRaster)observed.replayedAfterRaster=target.getPixel32(664-int(args[4]),4463-int(args[5]));
    return answer;
   };
   var finalCore:BitmapData;
   try {finalCore=graph.rebuild(new Rectangle(600,4120,400,400),null,core);}
   finally {Grafon.rconnectWallBridge=listener;}
   var finalColor:uint=finalCore.getPixel32(64,343),logical:uint=ownershipColor(visual,local);
   check(first==wrong&&observed.calls==1&&uint(observed.nativeBeforeRaster)==core,
      "ownership precondition: "+label+" has actual core before production raster");
   if(peer==0)
    check(finalColor==core&&logical==core,"ownership desired: "+label+" survives replay and becomes logical color");
   else
    check(finalColor==peer&&logical==peer&&visual.report(local,false)==null,
       "ownership existing barrier: "+label+" survives older native reconstruction");
   ownershipObservations.push({label:label,worldX:664,worldY:4463,firstGutter:first,
      nativeBeforeRaster:observed.nativeBeforeRaster,replayedAfterRaster:observed.replayedAfterRaster,
      finalCore:finalColor,logical:logical,peer:peer,nativeCore:core});
   gutter.dispose();finalCore.dispose();visual.networkActive=false;
  }
  private function ownershipColor(w:WallImpactVisuals,l:Object):uint {
   for each(var c:Object in w.checkpoint(l))if(int(c.x)==16&&int(c.y)==111) {
    var words:Array=rconnect.net.WallCellCodec.unpack(c.d);
    for(var i:int=0;i<words.length;i+=2)if(int(words[i])==23*40+24)return uint(words[i+1]);
   }
   return 0;
  }
  private function run(e:Event):void {
   removeEventListener(Event.ADDED_TO_STAGE,run);
   try {
    var l:Object=loc(),g:Grafon=new Grafon(l),w:WallImpactVisuals=wall();
    var a:Object=g.add(1960,1160),b:Object=g.add(2000,1160),mark:Object;
    w.before(l);var scratch:BitmapData=g.frontBmp;
    mark=g.hit(new Rectangle(2010,1205,2,2),0xffaa1122);
    check(g.frontBmp===scratch&&g.sceneX==0&&g.sceneY==0,"native finally restores scratch and origin");
    check(g.calls==2&&g.historyCount()==1,"native hit executes once per intersecting chunk, without extra draw");
    check(pixels(a,2010,1205)==0xffaa1122&&pixels(b,2010,1205)==0xffaa1122,"actual overlapping gutter buffers contain native pixels");
    var report:Object=w.report(l,false);
    check(report!=null&&report.cells.length==1&&report.cells[0].x==50&&report.cells[0].y==30,"global cell beyond both ordinary bounds is captured");
    var dest:Object=loc(),dg:Grafon=new Grafon(dest),remote:WallImpactVisuals=wall();
    var da:Object=dg.add(1960,1160),db:Object=dg.add(2000,1160);
    var receipt:Object=remote.settle(dest,"peer",report);
    check(receipt!=null,"existing sparse request format is accepted at large coordinates");
    check(pixels(da,2010,1205)==0xffaa1122&&pixels(db,2010,1205)==0xffaa1122,"received pixels reach all overlapping real buffers");
    check(da.revision==1&&db.revision==1,"only actually changed buffers advance revision once");
    check(dg.frontBmp.getPixel32(0,0)==0&&remote.dirty,"receive leaves scratch untouched and requests SATS refresh");
    remote.dirty=false;remote.settle(dest,"peer",report);
    check(da.revision==1&&!remote.dirty,"duplicate request is idempotent");
    remote.receive(dest,wire(50,30,5*40+10,0xff00ff00,1),false);
    remote.receive(dest,wire(50,30,5*40+10,0xff0000ff,0),false);
    check(pixels(da,2010,1205)==0xff00ff00,"older authoritative cell cannot undo a newer receive");
    var before:uint=pixels(da,2010,1205);
    remote.receive(dest,wire(80,30,0,0xffcc0000),false);
    check(pixels(da,2010,1205)==before,"out-of-room coordinate still rejects before painting");
    var bad:Array=wire(50,30,5*40+10,0xffcc0000,101);bad.push({x:51,y:30,v:101,d:"bad"});remote.receive(dest,bad,false);
    check(pixels(da,2010,1205)==before,"malformed later cell rejects entire batch atomically");
    dg.drop();var rebuilt:BitmapData=dg.rebuild(new Rectangle(1960,1160,80,80));
    check(rebuilt.getPixel32(50,45)==0xff00ff00,"future nonresident chunk raster receives stored sparse pixels");
    check(rebuilt.getPixel32(49,45)==0xff555555,"replay does not overwrite adjacent background texture");rebuilt.dispose();
    // Bind source again: a new bridge represents this instance, not another game.
    var sl:Object=loc(),sg:Grafon=new Grafon(sl),sw:WallImpactVisuals=wall();
    var sa:Object=sg.add(1960,1160);sg.hit(new Rectangle(2010,1205,1,1),0xffaa0000);
    var pending:Object=sw.report(sl,false);
    sw.receive(sl,wire(50,30,5*40+10,0xff00aa00,100),true);
    check(pixels(sa,2010,1205)==0xffaa0000,"pending local predicted pixel remains protected");
    sw.receive(sl,wire(50,30,5*40+11,0xff0000aa,100),true);
    check(pixels(sa,2011,1205)==0xff0000aa,"disjoint authoritative pixel merges beside prediction");
    sw.acknowledge(sl,{seq:pending.seq,cells:pending.cells});
    sw.receive(sl,wire(50,30,5*40+10,0xff00aa00,101),true);
    check(pixels(sa,2010,1205)==0xff00aa00,"accepted ACK releases prediction for later authoritative color");
    sg.drop();rebuilt=sg.rebuild(new Rectangle(1960,1160,80,80));
    check(rebuilt.getPixel32(50,45)==0xff00aa00,"replaying older local native mark cannot overwrite later peer pixels");
    check(sw.report(sl,false)==null,"known native mark reconstruction does not create a new network hit");rebuilt.dispose();
    // New native mark outside all resident chunks: deferred first real paint.
    var ol:Object=loc(),og:Grafon=new Grafon(ol),ow:WallImpactVisuals=wall();
    og.hit(new Rectangle(2010,1205,4,1),0xff224466);
    check(og.calls==0&&ow.report(ol,false)==null,"offscreen native mark has no invented pixels before actual raster");
    var left:Rectangle=new Rectangle(1960,1160,52,80),right:Rectangle=new Rectangle(2012,1160,28,80);
    rebuilt=og.rebuild(new Rectangle(1960,1160,80,80),[left],0xffaabbcc);rebuilt.dispose();
    var first:Object=ow.report(ol,false);check(first!=null,"first real selected style pass captures deferred mark");ow.acknowledge(ol,{seq:first.seq,cells:first.cells});
    rebuilt=og.rebuild(new Rectangle(1960,1160,80,80),[right],0xff112233);rebuilt.dispose();
    var second:Object=ow.report(ol,false);check(second!=null,"unseen remainder captures its own actual style");ow.acknowledge(ol,{seq:second.seq,cells:second.cells});
    rebuilt=og.rebuild(new Rectangle(1960,1160,80,80),null,0xff000000);
    check(rebuilt.getPixel32(50,45)==0xffaabbcc&&rebuilt.getPixel32(52,45)==0xff112233,"mixed-style accepted regions retain distinct actual pixel colors");
    check(ow.report(ol,false)==null,"camera re-render does not requeue covered deferred mark");rebuilt.dispose();
    // An unseen OLD local mark cannot win over a later accepted peer pixel.
    var previousBridge:Function=Grafon.rconnectWallBridge;
    var dl:Object=loc(),dd:Grafon=new Grafon(dl),dw:WallImpactVisuals=wall();
    dd.hit(new Rectangle(2010,1205,2,1),0xffaa0000);
    dw.receive(dl,wire(50,30,5*40+10,0xff00aa00,200),true);
    rebuilt=dd.rebuild(new Rectangle(1960,1160,80,80));
    check(rebuilt.getPixel32(50,45)==0xff00aa00&&rebuilt.getPixel32(51,45)==0xffaa0000,"deferred old local mark preserves newer received pixel while keeping unseen remainder");rebuilt.dispose();
    var delayed:Object=dw.report(dl,false),delayedWords:Array=delayed==null?[]:rconnect.net.WallCellCodec.unpack(delayed.cells[0].d);
    check(delayedWords.length==2&&delayedWords[0]==5*40+11,"deferred old mark queues only previously unobserved remainder");
    if(delayed!=null)dw.acknowledge(dl,{seq:delayed.seq,cells:delayed.cells});
    dw.receive(dl,wire(50,30,5*40+14,0xff990099,201),true);
    dd.hit(new Rectangle(2014,1205,1,1),0xffeeee00);
    dw.receive(dl,wire(50,30,5*40+14,0xff990099,202),true);
    rebuilt=dd.rebuild(new Rectangle(1960,1160,80,80));
    check(rebuilt.getPixel32(54,45)==0xff990099&&dw.report(dl,false)==null,"later accepted equal-color pixel also defeats older unpainted local mark");rebuilt.dispose();
    var ds:Object=dd.add(1960,1160);dw.redraw(dl);
    dd.hit(new Rectangle(2010,1205,1,1),0xffbb4400);var freshPending:Object=dw.report(dl,false);
    dw.receive(dl,wire(50,30,5*40+10,0xff0044bb,203),true);
    check(freshPending!=null&&pixels(ds,2010,1205)==0xffbb4400,"later native pending hit remains protected under original ACK rule");
    dw.acknowledge(dl,{seq:freshPending.seq,cells:freshPending.cells});
    dw.receive(dl,wire(50,30,5*40+10,0xff0044bb,204),true);
    check(pixels(ds,2010,1205)==0xff0044bb,"later native protection ends only after original ACK acceptance");
    // Return static listener to the earlier fixture before its reset/revisit.
    Grafon.rconnectWallBridge=previousBridge;
    var clips:Array=og.baseClips(new Rectangle(0,0,20,20),[{clips:[new Rectangle(5,5,10,10)]}]),area:Number=0;
    for each(var cr:Rectangle in clips){area+=cr.width*cr.height;check(!cr.intersects(new Rectangle(5,5,10,10)),"base style clip excludes selected overlay");}
    check(area==300,"base style remainder preserves exact selected pixel area");
    var saved:Array=ow.checkpoint(ol);ow.reset();
    check(ow.checkpoint(ol).length==0,"reset clears old room logical marks");
    ow.restore(ol,saved);rebuilt=og.rebuild(new Rectangle(1960,1160,80,80));
    check(rebuilt.getPixel32(50,45)==0xffaabbcc,"checkpoint restores large sparse marks after ownership/lifetime reset");rebuilt.dispose();
    ol.space[50][30].phis=0;rebuilt=og.rebuild(new Rectangle(1960,1160,80,80));
    check(rebuilt.getPixel32(50,45)!=0xffaabbcc,"destroyed tile does not receive retained coating");rebuilt.dispose();
    // A pending first raster accepts logical data but never writes old residents.
    var pl:Object=loc(),pg:Grafon=new Grafon(pl),pw:WallImpactVisuals=wall(),ps:Object=pg.add(1960,1160);
    pg.rconnectRasterPending=true;pw.receive(pl,wire(50,30,5*40+10,0xffabcdef),false);
    check(pixels(ps,2010,1205)==0xff555555,"pending first raster does not modify stale resident buffers");
    rebuilt=pg.rebuild(new Rectangle(1960,1160,80,80));check(rebuilt.getPixel32(50,45)==0xffabcdef,"actual first raster paints accepted state even before pending flag clears");rebuilt.dispose();
    // Saved unknown mark remains baseline; remote logical pixels still win.
    pg.seed(new Rectangle(2010,1205,1,1),0xffff0000);rebuilt=pg.rebuild(new Rectangle(1960,1160,80,80));
    check(rebuilt.getPixel32(50,45)==0xffabcdef&&pw.report(pl,false)==null,"unobserved saved history is not reclassified as local hit");rebuilt.dispose();
    // Reset during an observation invalidates that token without touching native.
    pg.rconnectRasterPending=false;var pm:Object=pg.hit(new Rectangle(20,20,1,1),0xff990000);
    var token:Object=pg.beforeToken(pm,new Rectangle(20,20,1,1));pw.reset();pg.frontBmp.setPixel32(20,20,0xff990000);pg.afterToken(pm,new Rectangle(20,20,1,1),token);
    check(pw.checkpoint(pl).length==0,"reset rejects stale in-flight native observation token");
    var throwing:Function=Grafon.rconnectWallBridge;Grafon.rconnectWallBridge=function(...args):Object{throw new Error("fixture listener failure");};
    pg.hit(new Rectangle(2010,1205,1,1),0xff333333);
    check(pixels(ps,2010,1205)==0xff333333&&pg.sceneX==0&&pg.sceneY==0,"listener failure cannot block native draw or origin restoration");
    Grafon.rconnectWallBridge=throwing;pg.throwDraw=true;var caught:Boolean=false,pgScratch:BitmapData=pg.frontBmp;
    try{pg.hit(new Rectangle(2011,1205,1,1),0xff444444);}catch(nativeError:Error){caught=true;}
    check(caught&&pg.frontBmp===pgScratch&&pg.sceneX==0&&pg.sceneY==0,"native draw failure still propagates and restores native state");pg.throwDraw=false;
    Grafon.rconnectWallBridge=null;var calls:int=pg.calls;pg.hit(new Rectangle(2012,1205,1,1),0xff555555);
    check(pg.calls==calls+1,"no-listener path performs the original draw exactly once");
    // Connection lifecycle uses the existing Session flag; no callback offline.
    var cl:Object=loc(),cg:Grafon=new Grafon(cl),cw:WallImpactVisuals=new WallImpactVisuals({loaderInfo:{applicationDomain:ApplicationDomain.currentDomain}});
    var cs:Object=cg.add(1960,1160);cg.hit(new Rectangle(2010,1205,1,1),0xff110000);
    check(Grafon.rconnectWallBridge==null&&cw.report(cl,false)==null,"offline bridge does not register or collect native paint");
    cw.networkActive=true;cg.rconnectRasterPending=true;cg.hit(new Rectangle(2011,1205,1,1),0xff220000);
    var enableReport:Object=cw.report(cl,false);
    check(enableReport!=null,"enable captures first actual native hit even while initial raster pending");
    if(enableReport!=null)cw.acknowledge(cl,{seq:enableReport.seq,cells:enableReport.cells});
    cw.networkActive=false;
    check(Grafon.rconnectWallBridge==null,"disconnect removes only its own installed callback");
    var other:WallImpactVisuals=wall(),owner:Function=Grafon.rconnectWallBridge;
    cw.networkActive=true;other.networkActive=false;
    check(Grafon.rconnectWallBridge!==owner&&Grafon.rconnectWallBridge!=null,"old owner disable cannot remove later owner's listener");
    cg.rconnectRasterPending=false;cg.drop();rebuilt=cg.rebuild(new Rectangle(1960,1160,80,80));rebuilt.dispose();
    check(cw.report(cl,false)==null,"reenable treats previously existing native history as baseline");
    cw.reset();var replacement:Object=loc(),replacementGrafon:Grafon=new Grafon(replacement);replacementGrafon.add(1960,1160);
    replacementGrafon.hit(new Rectangle(2010,1205,1,1),0xff330000);
    check(cw.report(replacement,false)!=null,"world reset keeps enabled binding and captures new Grafon's first hit without before");
    var rl:Object=loc(),rg:Grafon=new Grafon(rl),rw:WallImpactVisuals=wall();rg.hit(new Rectangle(2010,1205,1,1),0xff440000);
    rw.restore(rl,[]);rebuilt=rg.rebuild(new Rectangle(1960,1160,80,80));rebuilt.dispose();
    check(rw.report(rl,false)==null,"checkpoint restore invalidates previous deferred observation lifetime");
    rw.networkActive=false;cw.networkActive=false;
    // Full before/after production classes retain ordinary-room semantics.
    var lo:Object=loc(4,4),ln:Object=loc(4,4),old:WallBefore=new WallBefore(),nw:WallImpactVisuals=new WallImpactVisuals();
    lo.grafon={loc:lo,frontBmp:new BitmapData(160,160,true,0xff777777)};ln.grafon={loc:ln,frontBmp:new BitmapData(160,160,true,0xff777777)};
    old.before(lo);nw.before(ln);lo.grafon.frontBmp.setPixel32(25,26,0xff123456);ln.grafon.frontBmp.setPixel32(25,26,0xff123456);lo.space[0][0].hp--;ln.space[0][0].hp--;
    old.observe(lo,[{x:0,y:0}]);nw.observe(ln,[{x:0,y:0}]);check(same(old.report(lo,false),nw.report(ln,false)),"ordinary-room native diff reports remain field-for-field identical");
    old.receive(lo,wire(1,1,0,0xff987654),false);nw.receive(ln,wire(1,1,0,0xff987654),false);
    check(lo.grafon.frontBmp.compare(ln.grafon.frontBmp)===0,"ordinary-room receive pixels remain exact");
    check(same(old.checkpoint(lo),nw.checkpoint(ln)),"ordinary-room checkpoint data remains exact");
    // Added after all 54 original checks. These are native getVector colors
    // observed in f80b01a647, not expected values manufactured by a setter.
    var colorLoc:Object=loc(),colorGrafon:Grafon=new Grafon(colorLoc),colorWall:WallImpactVisuals=wall();
    var colorA:Object=colorGrafon.add(1960,1160),colorB:Object=colorGrafon.add(2000,1160);
    var colors:Array=[0xf664625b,0xf6817f77,0xee595953,0xff43433c,0xe64d4d48,0xe6524d4b];
    var colorWords:Array=[],ci:int;
    for(ci=0;ci<colors.length;ci++)colorWords.push(5*40+10+ci,Number(uint(colors[ci])));
    var colorPacket:Array=[{x:50,y:30,v:300,d:RoomCodec.pack(colorWords)}];
    var packetBefore:String=JSON.stringify(colorPacket);
    colorWall.receive(colorLoc,colorPacket,false);
    for(ci=0;ci<colors.length;ci++)
       check(pixels(colorA,2010+ci,1205)==uint(colors[ci])&&pixels(colorB,2010+ci,1205)==uint(colors[ci]),
          "exact observed color in both overlapping buffers "+uint(colors[ci]).toString(16));
    var logical:Array=colorWall.checkpoint(colorLoc);
    check(logical.length==1&&same(rconnect.net.WallCellCodec.unpack(logical[0].d),colorWords)&&
       JSON.stringify(colorPacket)==packetBefore,"setter conversion changes neither checkpoint nor input wire colors");
    var revisionA:int=int(colorA.revision),revisionB:int=int(colorB.revision);
    colorWall.dirty=false;colorWall.receive(colorLoc,colorPacket,false);
    check(revisionA==1&&revisionB==1&&colorA.revision==revisionA&&colorB.revision==revisionB&&!colorWall.dirty,
       "exact corrected colors do not cause duplicate receive writes or revision churn");
    colorGrafon.drop();rebuilt=colorGrafon.rebuild(new Rectangle(1960,1160,80,80));
    for(ci=0;ci<colors.length;ci++)
       check(rebuilt.getPixel32(50+ci,45)==uint(colors[ci]),"exact observed color after nonresident replay "+uint(colors[ci]).toString(16));
    check(rebuilt.getPixel32(49,45)==0xff555555&&rebuilt.getPixel32(56,45)==0xff555555,
       "color conversion does not paint neighboring native background pixels");rebuilt.dispose();
    colorWall.networkActive=false;
    // These are additional counterexamples, not replacements for the 69 checks.
    ownershipCase(0xff666861,0,"observed differing core");
    ownershipCase(0xff555555,0,"core unchanged from native baseline");
    ownershipCase(0xff666861,0xff334455,"newer different peer ink");
    ownershipCase(0xff666861,0xff676861,"newer equal-color peer ink");
   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}
   var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   fs.writeUTFBytes(JSON.stringify({assertions:assertions,passed:failed==0,count:assertions.length,failed:failed,diagnostic_only:true,ownershipObservations:ownershipObservations}));fs.close();NativeApplication.nativeApplication.exit(failed?1:0);
  }
 }
}
