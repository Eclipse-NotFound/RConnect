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
 import fe.weapon.Bullet;
 import rconnect.game.WallImpactVisuals;
 import rconnect.game.WallBefore;
 import rconnect.net.RoomCodec;
 public class WallSurfaceChecks extends Sprite {
  private var assertions:Array=[],failed:int=0;
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
    // The same native readback/setter loss also exists in ordinary frontBmp.
    // Keep the previous 69 checks and compare against the complete old class.
    var smallLoc:Object=loc(4,4),smallOldLoc:Object=loc(4,4);
    var smallWall:WallImpactVisuals=new WallImpactVisuals(),smallOld:WallBefore=new WallBefore();
    smallLoc.grafon={loc:smallLoc,frontBmp:new BitmapData(160,160,true,0xff777777)};
    smallOldLoc.grafon={loc:smallOldLoc,frontBmp:new BitmapData(160,160,true,0xff777777)};
    smallWall.before(smallLoc);smallOld.before(smallOldLoc);
    var smallWords:Array=[];
    for(ci=0;ci<colors.length;ci++)smallWords.push(5*40+10+ci,Number(uint(colors[ci])));
    var smallPacket:Array=[{x:1,y:1,v:800,d:RoomCodec.pack(smallWords)}];
    smallWall.receive(smallLoc,smallPacket,false);smallOld.receive(smallOldLoc,smallPacket,false);
    var oldDifferent:int=0;
    for(ci=0;ci<colors.length;ci++) {
       check(smallLoc.grafon.frontBmp.getPixel32(50+ci,45)==uint(colors[ci]),
          "ordinary front bitmap exact received color "+uint(colors[ci]).toString(16));
       if(smallOldLoc.grafon.frontBmp.getPixel32(50+ci,45)!=uint(colors[ci]))oldDifferent++;
    }
    check(oldDifferent==5,"ordinary original direct setter reproduces all five semi-transparent losses");
    var smallSaved:Array=smallWall.checkpoint(smallLoc);
    check(smallSaved.length==1&&same(rconnect.net.WallCellCodec.unpack(smallSaved[0].d),smallWords),
       "ordinary checkpoint preserves exact logical colors independently of setters");
    smallWall.dirty=false;smallWall.receive(smallLoc,smallPacket,false);
    check(!smallWall.dirty,"ordinary duplicate version makes no pixel changes");
    var oldBitmap:BitmapData=smallLoc.grafon.frontBmp;
    smallLoc.grafon.frontBmp=new BitmapData(160,160,true,0xff777777);
    smallWall.before(smallLoc);oldBitmap.dispose();
    for(ci=0;ci<colors.length;ci++)
       check(smallLoc.grafon.frontBmp.getPixel32(50+ci,45)==uint(colors[ci]),
          "ordinary rebuilt bitmap exact replay color "+uint(colors[ci]).toString(16));
    check(smallLoc.grafon.frontBmp.getPixel32(49,45)==0xff777777&&smallLoc.grafon.frontBmp.getPixel32(56,45)==0xff777777,
       "ordinary color correction leaves neighboring background intact");
    edgeChecks();
    samePixelChecks();
   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}
   var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   fs.writeUTFBytes(JSON.stringify({assertions:assertions,passed:failed==0,count:assertions.length,failed:failed,diagnostic_only:true}));fs.close();NativeApplication.nativeApplication.exit(failed?1:0);
  }
  private function edgeRoom():Object {
   var l:Object=loc(2,2);for(var x:int=0;x<2;x++)for(var y:int=0;y<2;y++)l.space[x][y].phis=0;
   l.space[1][0].phis=1;
   l.grafon={loc:l,sceneLarge:false,rconnectRasterPending:false,frontBmp:new BitmapData(80,80,true,0)};
   seedEdges(l,false);return l;
  }
  private function seedEdges(l:Object,changed:Boolean):void {
   for each(var p:Array in EdgeObserved.POINTS)
    l.grafon.frontBmp.setPixel32(p[0],p[1],rconnect.game.NativeWallColor.setter(uint(p[changed?3:2])));
  }
  private function edgeEqual(l:Object,changed:Boolean):Boolean {
   for each(var p:Array in EdgeObserved.POINTS)if(l.grafon.frontBmp.getPixel32(p[0],p[1])!=uint(p[changed?3:2]))return false;
   return true;
  }
  private function hitEdge(w:Object,l:Object,color:uint=0):void {
   var b:Bullet=new Bullet(l,45,18);l.firstObj=b;
   if(color)l.grafon.frontBmp.setPixel32(38,0,rconnect.game.NativeWallColor.setter(color));
   else seedEdges(l,true);
   b.tilehit=true;w.observe(l);
  }
  private function edgeChecks():void {
   var s:Object=edgeRoom(),d:Object=edgeRoom(),c:Object=edgeRoom();
   var sw:WallImpactVisuals=new WallImpactVisuals(),dw:WallImpactVisuals=new WallImpactVisuals();
   var old:rconnect.game.WallControl=new rconnect.game.WallControl();sw.before(s);dw.before(d);old.before(c);
   check(edgeEqual(s,false)&&edgeEqual(d,false)&&edgeEqual(c,false),"86 exact 22 native observed baseline colors are representable");
   hitEdge(old,c);check(old.report(c,false)==null&&edgeEqual(c,true),"87 accurate22 full class drops all 22 actual edge changes in passable cell");
   hitEdge(sw,s);var report:Object=sw.report(s,false),words:Array=report==null?[]:rconnect.net.WallCellCodec.unpack(report.cells[0].d);
   check(report!=null&&report.cells.length==1&&report.cells[0].x==0&&report.cells[0].y==0&&words.length==44,"88 actual contact capture emits exactly the 22 sparse edge pixels");
   var receipt:Object=dw.settle(d,"peer",report);
   check(receipt!=null&&receipt.cells.length==1,"89 passable foreground cell follows existing ACK envelope");
   for(var i:int=0;i<22;i++) {
    var p:Array=EdgeObserved.POINTS[i];
    check(d.grafon.frontBmp.getPixel32(p[0],p[1])==uint(p[3]),"edge observed exact native color "+i);
   }
   sw.acknowledge(s,receipt);
   check(sw.report(s,false)==null&&edgeEqual(s,true),"112 same packet ACK drains pending without changing local native colors");
   var snap:Array=sw.snapshot(s,false),up:Array=sw.updates(s);
   check(snap!=null&&snap.length==1&&up!=null&&up.length==1&&same(rconnect.net.WallCellCodec.unpack(snap[0].d),words),"113 fast and cumulative paths retain exact air-cell words");
   sw.sentUpdates(s,up);check(sw.updates(s)==null,"114 sent revision is not resent on fast path");
   var saved:Array=sw.checkpoint(s),fresh:BitmapData=new BitmapData(80,80,true,0),oldB:BitmapData=s.grafon.frontBmp;
   s.grafon.frontBmp=fresh;seedEdges(s,false);sw.before(s);oldB.dispose();
   check(edgeEqual(s,true)&&s.grafon.frontBmp.getPixel32(37,0)==0,"115 entry redraw restores only supported foreground without painting neighbor air");
   // One erased pixel and one nonzero coating share one packet. The alpha-zero
   // value must survive logical storage so a native redraw does not heal it.
   var erase:Array=[{x:0,y:0,v:500,d:RoomCodec.pack([38,0,39,Number(uint(0xff121212)),0+40,Number(uint(0xff123456))])}];
   dw.receive(d,erase,false);
   check(d.grafon.frontBmp.getPixel32(38,0)==0&&d.grafon.frontBmp.getPixel32(39,0)==0xff121212&&d.grafon.frontBmp.getPixel32(0,1)==0,"116 exact transparent erase accepted while unsupported nonzero pixel remains blank");
   var savedD:Array=dw.checkpoint(d);d.grafon.frontBmp.fillRect(d.grafon.frontBmp.rect,0);seedEdges(d,false);dw.redraw(d);
   check(d.grafon.frontBmp.getPixel32(38,0)==0&&d.grafon.frontBmp.getPixel32(39,0)==0xff121212&&d.grafon.frontBmp.getPixel32(0,1)==0,"117 replay preserves erase and cannot materialize skipped opaque ink");
   // Native terrain removal clears the actual support mask. Keep logical state
   // and ACK semantics, but neither old receive nor any replay can create alpha.
   d.space[1][0].phis=0;d.grafon.frontBmp.fillRect(d.grafon.frontBmp.rect,0);dw.redraw(d);
   check(d.grafon.frontBmp.getColorBoundsRect(0xffffffff,0,false).isEmpty(),"118 destroyed supporting wall leaves no replayed foreground");
   dw.settle(d,"late",report);dw.restore(d,savedD);
   check(d.grafon.frontBmp.getColorBoundsRect(0xffffffff,0,false).isEmpty(),"119 old report and restored checkpoint cannot revive cleared native mask");
   // A shared Grafon belongs to another room. Do not use its alpha or sceneLarge
   // to discard this old room's ordinary logical data or paint the other room.
   var other:Object=loc(),shared:Object=s.grafon;shared.loc=other;shared.sceneLarge=true;shared.frontBmp=new BitmapData(80,80,true,0xffabcdef);
   var away:Array=sw.checkpoint(s);sw.receive(s,[{x:0,y:0,v:600,d:RoomCodec.pack([38,Number(uint(0x7e14140e))])}],false);
   check(away.length==1&&shared.frontBmp.getPixel32(38,0)==0xffabcdef,"120 old-room checkpoint and receive never consult or paint foreign Grafon");
   shared.loc=s;shared.sceneLarge=false;shared.frontBmp=new BitmapData(80,80,true,0);seedEdges(s,false);sw.before(s);
   check(edgeEqual(s,true),"121 ordinary room return replays against its own newly rebuilt support");
   // Newer queued local ink remains protected while acknowledging an older hit.
   var q:Object=edgeRoom(),qw:WallImpactVisuals=new WallImpactVisuals();qw.before(q);
   hitEdge(qw,q,0x7e24241e);var first:Object=qw.report(q,false);
   hitEdge(qw,q,0x7e14140e);qw.acknowledge(q,{seq:first.seq,cells:first.cells});
   check(q.grafon.frontBmp.getPixel32(38,0)==0x7e14140e,"122 ACK for older edge hit cannot overwrite newer queued prediction");
   var second:Object=qw.report(q,false);qw.receive(q,wire(0,0,38,0x7e39392f,700),true);
   check(second!=null&&q.grafon.frontBmp.getPixel32(38,0)==0x7e14140e,"123 pending edge prediction blocks authoritative overwrite");
   qw.acknowledge(q,{seq:second.seq,cells:second.cells});qw.receive(q,wire(0,0,38,0x7e39392f,701),true);
   check(q.grafon.frontBmp.getPixel32(38,0)==0x7e39392f,"124 later authoritative edge color applies after ordinary ACK");
   // The comparison work remains local to actual contact bounds. An unrelated
   // distant bitmap change cannot become a wall event merely because air is allowed.
   var far:Object=loc(30,30);for(var xx:int=0;xx<30;xx++)for(var yy:int=0;yy<30;yy++)far.space[xx][yy].phis=0;
   far.grafon={loc:far,sceneLarge:false,frontBmp:new BitmapData(1200,1200,true,0)};
   var fw:WallImpactVisuals=new WallImpactVisuals();fw.before(far);far.grafon.frontBmp.setPixel32(1000,1000,0xff123456);
   var fb:Bullet=new Bullet(far,45,18);fb.tilehit=true;far.firstObj=fb;fw.observe(far);
   check(fw.report(far,false)==null,"125 new air-cell comparisons never scan unrelated far-room changes");
   var gl:Object=loc(),gg:Grafon=new Grafon(gl),gw:WallImpactVisuals=wall();gg.add(1960,1160);gl.space[50][30].phis=0;
   gg.hit(new Rectangle(2010,1205,1,1),0xffaabbcc);
   check(gw.report(gl,false)==null,"126 large-scene air-cell edge behavior remains outside this ordinary-only change");gw.networkActive=false;
   var incomingBefore:String=JSON.stringify(report);dw.settle(d,"late",report);
   check(JSON.stringify(report)==incomingBefore,"127 support mask never rewrites ACK or input payload colors");
   q.grafon.frontBmp.fillRect(q.grafon.frontBmp.rect,0);qw.redraw(q);qw.receive(q,wire(0,0,38,0x7e39392f,699),false);
   check(q.grafon.frontBmp.getPixel32(38,0)==0,"128 old authoritative version cannot restore opacity after clear");
   var unknown:Object=loc(2,2),uw:WallImpactVisuals=new WallImpactVisuals();unknown.space[0][0].phis=0;
   unknown.grafon={loc:other,sceneLarge:true,frontBmp:new BitmapData(80,80,true,0xffaabbcc)};
   uw.receive(unknown,wire(0,0,38,0xff112233,1),false);
   check(uw.checkpoint(unknown).length==1&&unknown.grafon.frontBmp.getPixel32(38,0)==0xffaabbcc,"129 unknown inactive room defers logical ink without sampling foreign large canvas");
   unknown.grafon={loc:unknown,sceneLarge:false,frontBmp:new BitmapData(80,80,true,0)};unknown.grafon.frontBmp.setPixel32(38,0,0xffeeeeee);uw.before(unknown);
   check(unknown.grafon.frontBmp.getPixel32(38,0)==0xff112233&&unknown.grafon.frontBmp.getPixel32(39,0)==0,"130 unknown room resolves ordinary mask only after actual first backdrop");
   var edgeBottom:Object=edgeRoom(),edgeDest:Object=edgeRoom(),bw:WallImpactVisuals=new WallImpactVisuals(),bdw:WallImpactVisuals=new WallImpactVisuals();
   for(var bi:int=0;bi<4;bi++){edgeBottom.grafon.frontBmp.setPixel32(60+bi,47,0xff667788);edgeDest.grafon.frontBmp.setPixel32(60+bi,47,0xff667788);}
   bw.before(edgeBottom);bdw.before(edgeDest);
   for(bi=0;bi<4;bi++)edgeBottom.grafon.frontBmp.setPixel32(60+bi,47,0xff112233);
   var lower:Bullet=new Bullet(edgeBottom,60,38);lower.tilehit=true;edgeBottom.firstObj=lower;bw.observe(edgeBottom);
   var bottomReport:Object=bw.report(edgeBottom,false);
   check(bottomReport!=null&&bottomReport.cells.length==1&&bottomReport.cells[0].x==1&&bottomReport.cells[0].y==1,"131 native lower foreground edge seven pixels beyond collision cell is captured without fixed padding rule");
   bdw.settle(edgeDest,"peer",bottomReport);var bottomOK:Boolean=true;
   for(bi=0;bi<4;bi++)if(edgeDest.grafon.frontBmp.getPixel32(60+bi,47)!=0xff112233)bottomOK=false;
   check(bottomOK&&edgeDest.grafon.frontBmp.getPixel32(59,47)==0,"132 adjacent lower edge replays only exact existing native support");
  }
  private function eraseEdge(w:Object,l:Object):void {
   // Actual BitmapData erase value, with the same bounded contact carrier used
   // by the retained component. This is not a claim that a native asset ran.
   l.grafon.frontBmp.setPixel32(38,0,0);
   var b:Bullet=new Bullet(l,45,18);b.tilehit=true;l.firstObj=b;w.observe(l);
  }
  private function checkpointColor(w:Object,l:Object,index:int):uint {
   for each(var c:Object in w.checkpoint(l))if(c.x==0&&c.y==0) {
    var words:Array=rconnect.net.WallCellCodec.unpack(c.d);
    for(var i:int=0;i<words.length;i+=2)if(words[i]==index)return uint(words[i+1]);
   }
   throw new Error("Expected checkpoint pixel was not retained");
  }
  private function samePixelChecks():void {
   // Joining ink was produced against the still-visible background first. The
   // owner then locally erases that SAME pixel before this report is settled.
   var j:Object=edgeRoom(),h:Object=edgeRoom();
   var jw:WallImpactVisuals=new WallImpactVisuals(),hw:WallImpactVisuals=new WallImpactVisuals();jw.before(j);hw.before(h);
   hitEdge(jw,j,0x7e14140e);var pending:Object=jw.report(j,false);
   eraseEdge(hw,h);var erased:Boolean=h.grafon.frontBmp.getPixel32(38,0)==0;
   var ack:Object=hw.settle(h,"joining",pending);jw.acknowledge(j,ack);
   check(erased&&ack!=null&&ack.cells.length==1&&checkpointColor(hw,h,38)==0x7e14140e&&
    j.grafon.frontBmp.getPixel32(38,0)==0x7e14140e,
    "133 same-pixel native erase precedes accepted later ink with unchanged logical ACK");
   check(h.grafon.frontBmp.getPixel32(38,0)==0x7e14140e&&j.grafon.frontBmp.getPixel32(38,0)==0x7e14140e,
    "134 same-pixel last-arrival ink converges after earlier native erase");
   // Existing last-arrival behavior in the complete accurate22 class on a
   // solid cell: this is the same merge contract the edge extension must keep.
   var cj:Object=edgeRoom(),ch:Object=edgeRoom();cj.space[0][0].phis=ch.space[0][0].phis=1;
   var cjw:rconnect.game.WallControl=new rconnect.game.WallControl(),chw:rconnect.game.WallControl=new rconnect.game.WallControl();
   cjw.before(cj);chw.before(ch);hitEdge(cjw,cj,0x7e14140e);var cp:Object=cjw.report(cj,false);eraseEdge(chw,ch);
   var ca:Object=chw.settle(ch,"joining",cp);cjw.acknowledge(cj,ca);
   check(ch.grafon.frontBmp.getPixel32(38,0)==0x7e14140e&&cj.grafon.frontBmp.getPixel32(38,0)==0x7e14140e,
    "135 full accurate22 solid-cell control retains same-pixel last-arrival contract");
   // The native structural path may modify the existing bitmap without any
   // redraw callback. A future support cache must not rely on redraw alone.
   var broken:Object=edgeRoom(),bw:WallImpactVisuals=new WallImpactVisuals();bw.before(broken);
   bw.receive(broken,wire(0,0,38,0x7e14140e,800),false);
   var sameBitmap:BitmapData=broken.grafon.frontBmp;
   broken.space[1][0].phis=0;sameBitmap.fillRect(sameBitmap.rect,0);
   bw.settle(broken,"late",pending);
   check(broken.grafon.frontBmp===sameBitmap&&sameBitmap.getPixel32(38,0)==0,
    "136 same-bitmap structural clear cannot be resurrected by late ink without a redraw call");
  }
 }
}
