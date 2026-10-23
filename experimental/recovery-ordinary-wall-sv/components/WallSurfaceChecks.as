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
 import rconnect.game.NativeWallColor;
 import rconnect.net.WallCellCodec;
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
  private function ordinaryWire(x:int,y:int,offset:int,color:uint,v:int=100,sv:int=0):Array{return [{x:x,y:y,v:v,sv:sv,full:false,d:RoomCodec.pack([offset,Number(color)])}];}
  private function small(base:uint=0xff777777):Object {
   var l:Object=loc(2,2);l.grafon={loc:l,sceneLarge:false,frontBmp:new BitmapData(80,80,true,base)};return l;
  }
  private function ink(w:WallImpactVisuals,l:Object,color:uint,x:int=38,y:int=0):void {
   w.before(l);var bullet:Bullet=new Bullet(l,x,y);l.firstObj=bullet;
   BitmapData(l.grafon.frontBmp).setPixel32(x,y,NativeWallColor.setter(color));bullet.tilehit=true;w.observe(l);
  }
  private function full(v:int,sv:int,color:uint=0,x:int=0,y:int=0):Object {
   var values:Object={};for(var i:int=0;i<1600;i++)values[String(i)]=color;
   return {x:x,y:y,v:v,sv:sv,full:true,d:WallCellCodec.pack(values)};
  }
  private function pixel(l:Object,x:int=38,y:int=0):uint{return BitmapData(l.grafon.frontBmp).getPixel32(x,y);}
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
    old.observe(lo,[{x:0,y:0}]);nw.observe(ln,[{x:0,y:0}]);var beforeOrd:Object=old.report(lo,false),afterOrd:Object=nw.report(ln,false);
    check(beforeOrd.cells[0].d==afterOrd.cells[0].d&&afterOrd.cells[0].sv==0&&afterOrd.cells[0].full===false,"ordinary-room native diff colors unchanged with explicit structure generation");
    old.receive(lo,wire(1,1,0,0xff987654),false);nw.receive(ln,ordinaryWire(1,1,0,0xff987654),false);
    check(lo.grafon.frontBmp.compare(ln.grafon.frontBmp)===0,"ordinary-room receive pixels remain exact");
    check(old.checkpoint(lo).length==nw.checkpoint(ln).length&&nw.checkpoint(ln)[0].sv===0,"ordinary checkpoint preserves cell count and declares initial generation");
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
    var smallPacket:Array=[{x:1,y:1,v:800,sv:0,full:false,d:RoomCodec.pack(smallWords)}];
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
    // Production ordinary methods, not a model: the exact 22 native uints
    // missed by recovery22 all sit in a collision-empty cell beside a wall.
    var edgeSource:Object=small(0),edgeOwner:Object=small(0),es:WallImpactVisuals=new WallImpactVisuals(),eo:WallImpactVisuals=new WallImpactVisuals();
    edgeSource.space[0][0].phis=edgeOwner.space[0][0].phis=0;es.ordinaryRole(edgeSource,false);eo.ordinaryRole(edgeOwner,true);
    for each(var ep:Array in EdgeObserved.POINTS) {
     edgeSource.grafon.frontBmp.setPixel32(ep[0],ep[1],NativeWallColor.setter(uint(ep[3])));
     edgeOwner.grafon.frontBmp.setPixel32(ep[0],ep[1],NativeWallColor.setter(uint(ep[3])));
    }
    es.before(edgeSource);var edgeBullet:Bullet=new Bullet(edgeSource,45,18);edgeSource.firstObj=edgeBullet;
    for each(ep in EdgeObserved.POINTS)edgeSource.grafon.frontBmp.setPixel32(ep[0],ep[1],NativeWallColor.setter(uint(ep[2])));
    edgeBullet.tilehit=true;es.observe(edgeSource);var edgeReport:Object=es.report(edgeSource,false),edgeReceipt:Object=eo.settle(edgeOwner,"edge",edgeReport);
    check(edgeReport!=null&&edgeReport.cells.length==1&&edgeReceipt!=null,"actual empty-cell wall edge diff is reported and authoritatively settled");
    es.acknowledge(edgeSource,edgeReceipt);
    for each(ep in EdgeObserved.POINTS)check(pixel(edgeOwner,ep[0],ep[1])==uint(ep[2])&&pixel(edgeSource,ep[0],ep[1])==uint(ep[2]),"both sides preserve observed edge uint at "+ep[0]+","+ep[1]);
    var clear:Object=eo.settle(edgeOwner,"late",{seq:1,cells:ordinaryWire(0,0,38,0,0)});
    var late:Object=eo.settle(edgeOwner,"late",{seq:2,cells:ordinaryWire(0,0,38,0xffee5522,0)});
    check(clear!=null&&late!=null&&pixel(edgeOwner)==0xffee5522,"ordinary erase then same-generation late ink is accepted even on alpha zero");
    check(late.cells[0].v>clear.cells[0].v&&late.cells[0].sv==0,"ACK uses advancing authority v with unchanged sv");
    var immutable:String=JSON.stringify(edgeReport);eo.settle(edgeOwner,"edge",edgeReport);
    check(JSON.stringify(edgeReport)==immutable,"settle leaves source report wire immutable");
    eo.before(edgeOwner);edgeOwner.grafon.frontBmp.fillRect(new Rectangle(0,0,40,40),0);
    eo.structureComplete(edgeOwner,edgeOwner.grafon.frontBmp,new Rectangle(0,0,40,40),true);
    var structure:Array=eo.checkpoint(edgeOwner),structCell:Object=structure[0];
    check(structCell.sv>0&&structCell.v==structCell.sv&&structCell.full&&WallCellCodec.unpack(structCell.d).length==3200,"structure captures complete native cell including all transparent pixels");
    var rejected:Object=eo.settle(edgeOwner,"obsolete",{seq:1,cells:ordinaryWire(0,0,38,0xffffffff,0)});
    check(rejected.cells[0].sv==structCell.sv&&pixel(edgeOwner)==0,"old generation ink returns current full authority and cannot resurrect wall");
    check(eo.report(edgeOwner,false)==null,"structure updates shadow without creating another ordinary prediction");
    es.receive(edgeSource,[structCell],false);
    check(pixel(edgeSource)==0,"higher generation full block replaces former edge colors without local-alpha filtering");
    var dupe:Object=eo.settle(edgeOwner,"obsolete",{seq:1,cells:ordinaryWire(0,0,38,0xff00ff00,0)});
    check(dupe===rejected&&pixel(edgeOwner)==0,"duplicate seq returns original receipt without repeating writes");
    // Current confirmed state progresses behind predictions; old ACK only
    // retires its own overlay, including pixels omitted by a sparse new packet.
    var predLoc:Object=small(),pred:WallImpactVisuals=new WallImpactVisuals();pred.ordinaryRole(predLoc,false);
    ink(pred,predLoc,0xffaa0000);var pendingOrd:Object=pred.report(predLoc,false);
    pred.receive(predLoc,ordinaryWire(0,0,38,0xff00aa00,50),false);
    check(pixel(predLoc)==0xffaa0000,"same-sv pending overlays newer confirmed data while its seq is outstanding");
    pred.acknowledge(predLoc,{seq:pendingOrd.seq,cells:ordinaryWire(0,0,38,0xffaa0000,1)});
    check(pixel(predLoc)==0xff00aa00,"stale ACK retires actual visual prediction and reveals newest confirmed v");
    ink(pred,predLoc,0xffbb0000,37,0);pendingOrd=pred.report(predLoc,false);
    pred.receive(predLoc,ordinaryWire(0,0,36,0xff112233,51),false);
    pred.acknowledge(predLoc,{seq:pendingOrd.seq,cells:[{x:0,y:0,v:0,sv:0,full:false,d:WallCellCodec.pack({})}]});
    check(pixel(predLoc,37,0)==0xff777777&&pixel(predLoc,36,0)==0xff112233,"stale ACK restores native underlay when no confirmed mark exists at retired pixel");
    ink(pred,predLoc,0xffcc0000);pendingOrd=pred.report(predLoc,false);
    var sentWire:String=JSON.stringify(pendingOrd);pred.receive(predLoc,[full(100,100)],false);
    ink(pred,predLoc,0xff884422);
    pred.acknowledge(predLoc,{seq:pendingOrd.seq,cells:ordinaryWire(0,0,38,0xffcc0000,52)});
    var nextOrd:Object=pred.report(predLoc,false);
    check(JSON.stringify(pendingOrd)==sentWire&&nextOrd!=null&&nextOrd.cells[0].sv==100&&pixel(predLoc)==0xff884422,"old seq cannot mutate its sent wire or erase newer-generation queued ink");
    // Malformed metadata and incomplete high-sv packets reject atomically.
    var validation:Object=small(),vw:WallImpactVisuals=new WallImpactVisuals();vw.ordinaryRole(validation,false);
    var malformed:Array=[NaN,-1,1.5,2147483647,"2",null];
    for each(var badVersion:* in malformed) {
     var malformedCell:Object=full(5,5,0xff111111);malformedCell.sv=badVersion;vw.receive(validation,[malformedCell],false);
     check(pixel(validation)==0xff777777,"reject noncanonical sv "+String(badVersion));
    }
    vw.receive(validation,ordinaryWire(0,0,38,0xff123456,5,5),false);
    check(pixel(validation)==0xff777777,"new structural generation cannot arrive as sparse colors");
    var missing:Object=full(5,5,0xff123456);missing.d=RoomCodec.pack([0,0]);vw.receive(validation,[missing],false);
    check(pixel(validation)==0xff777777,"full marker cannot hide an incomplete baseline");
    var validFull:Object=full(10,10,0xff222222),invalidTail:Object=full(10,10);invalidTail.x=2;
    vw.receive(validation,[validFull,invalidTail],false);
    check(pixel(validation)==0xff777777,"invalid later cell prevents all earlier packet writes");
    vw.receive(validation,[validFull],false);vw.receive(validation,[full(11,9,0xff333333)],false);
    check(pixel(validation)==0xff222222,"higher v cannot roll back sv");
    // Inactive metadata never reads/writes the currently displayed other room.
    var inactive:Object=small(),away:Object=small(),iw:WallImpactVisuals=new WallImpactVisuals();iw.ordinaryRole(inactive,true);inactive.grafon=away.grafon;
    iw.structurePending(inactive,new Rectangle(0,0,40,40));var waitState:Array=iw.checkpoint(inactive);
    check(iw.hasNeedsNative(inactive)&&iw.updates(inactive)==null&&waitState[0].d===undefined&&pixel(away)==0xff777777,"inactive structural pending retains metadata only and never touches foreign foreground");
    var waitingFollower:Object=small(),wf:WallImpactVisuals=new WallImpactVisuals();wf.prepareRestore(waitingFollower,waitState,false);
    check(!wf.finishRestore(waitingFollower)&&!wf.nativeRaster(waitingFollower,waitingFollower.grafon.frontBmp,true),"non-authority cannot invent a pending authority baseline from local native pixels");
    var freshOwner:Object=small(0xff445566),fw:WallImpactVisuals=new WallImpactVisuals();fw.prepareRestore(freshOwner,waitState,true);
    check(fw.nativeRaster(freshOwner,freshOwner.grafon.frontBmp,true)&&fw.finishRestore(freshOwner),"new authority resolves pending only after actual native raster callback");
    var freshState:Array=fw.checkpoint(freshOwner);
    check(freshState[0].sv>waitState[0].sv&&freshState[0].full&&!freshState[0].rebase,"resolved native baseline advances imported generation and clears rebase");
    wf.receive(waitingFollower,freshState,false);
    check(wf.finishRestore(waitingFollower)&&pixel(waitingFollower)==0xff445566,"authority full baseline releases receiving room with authoritative pixels");
    var noNative:Object=small(),nn:WallImpactVisuals=new WallImpactVisuals();nn.prepareRestore(noNative,waitState,true);
    check(!nn.nativeRaster(noNative,noNative.grafon.frontBmp,false)&&nn.hasNeedsNative(noNative),"failed native draw never materializes pending structural state");
    // Full rebase is an explicit conservative cell reset, not a claim that
    // old marks on remaining wall survive a native structural rebuild.
    var rb:Object=small(),rbw:WallImpactVisuals=new WallImpactVisuals();rbw.ordinaryRole(rb,true);rbw.before(rb);
    rb.grafon.frontBmp.setPixel32(38,0,0xffee0000);rbw.structureComplete(rb,rb.grafon.frontBmp,new Rectangle(0,0,40,40),true);
    var priorState:Array=rbw.checkpoint(rb);rb.grafon.frontBmp.fillRect(new Rectangle(0,0,40,40),0xff123456);rbw.nativeRaster(rb,rb.grafon.frontBmp,true);
    check(pixel(rb)==0xff123456&&rbw.checkpoint(rb)[0].sv>priorState[0].sv,"successful same-bitmap native redraw replaces only rebase cell with new native base");
    var preserved:Array=rbw.checkpoint(rb);rbw.roleChanged(rb);rbw.endSession();
    check(same(preserved,rbw.checkpoint(rb)),"role change and session end retain ordinary confirmed structure generation");
    var importLoc:Object=small(),importWall:WallImpactVisuals=new WallImpactVisuals();importWall.prepareRestore(importLoc,[full(5000,4000,0xff444444)],true);importWall.finishRestore(importLoc);
    ink(importWall,importLoc,0xff555555);check(importWall.checkpoint(importLoc)[0].v>5000,"next authority revision exceeds both imported v and sv");
    // Ordinary request count bounds cumulative full ACK without fragmenting seq.
    var many:Object=loc(4,2),manyWall:WallImpactVisuals=new WallImpactVisuals();many.grafon={loc:many,frontBmp:new BitmapData(160,80,true,0xff777777)};manyWall.ordinaryRole(many,false);
    ink(manyWall,many,0xff111111,1,1);ink(manyWall,many,0xff222222,41,1);ink(manyWall,many,0xff333333,81,1);ink(manyWall,many,0xff444444,121,1);
    var batch:Object=manyWall.report(many,false);check(batch.cells.length==3,"ordinary report caps three cells for worst-case full ACK size");
    var manyOwner:Object=loc(4,2),manyOW:WallImpactVisuals=new WallImpactVisuals();manyOwner.grafon={loc:manyOwner,frontBmp:new BitmapData(160,80,true,0xff777777)};manyOW.ordinaryRole(manyOwner,true);
    var tooMany:Array=[];for(var bi:int=0;bi<4;bi++)tooMany.push(ordinaryWire(bi,0,41,0xff000001,0)[0]);
    check(manyOW.settle(manyOwner,"many",{seq:1,cells:tooMany})==null,"owner rejects oversized ordinary cell count before mutation");
    manyWall.acknowledge(many,{seq:batch.seq,cells:batch.cells});var remainder:Object=manyWall.report(many,false);
    check(remainder!=null&&remainder.cells.length==1,"next seq drains remaining queued ordinary cell");
    // Exercise the actual independent bridge function with the host event
    // envelope; these calls do not claim real Grafon artwork qualification.
    var hookLoc:Object=small(),hookWall:WallImpactVisuals=wall();hookWall.ordinaryRole(hookLoc,true);
    var notify:Function=Grafon.rconnectOrdinaryWallBridge;
    hookWall.before(hookLoc);
    // Earlier excluded native writes share the cell, one inside this decal's
    // bounds and one outside. Neither is a new change made by this decal.
    hookLoc.grafon.frontBmp.setPixel32(36,0,0xffaabbcc);hookLoc.grafon.frontBmp.setPixel32(1,0,0xff112244);
    var hookEvent:Object={kind:"ink-before",loc:hookLoc,grafon:hookLoc.grafon,bitmap:hookLoc.grafon.frontBmp,bounds:new Rectangle(36,0,3,1),valid:true};
    var reply:Object=notify(hookEvent);hookLoc.grafon.frontBmp.setPixel32(38,0,0xff556677);
    hookEvent.kind="ink-after";hookEvent.token=reply.token;notify(hookEvent);
    var boundedReport:Object=hookWall.report(hookLoc,false);
    check(boundedReport!=null,"native ordinary ink envelope returns a usable token and captures actual changed bitmap");
    var boundedWords:Array=boundedReport==null?[]:WallCellCodec.unpack(boundedReport.cells[0].d);
    check(boundedReport!=null&&boundedReport.cells.length==1&&same(boundedWords,[38,Number(0xff556677)])&&pixel(hookLoc,36,0)==0xffaabbcc&&pixel(hookLoc,1,0)==0xff112244,"earlier excluded writes inside and outside actual decal bounds are not repackaged as ordinary ink");
    hookEvent.kind="ink-before";reply=notify(hookEvent);hookWall.reset();hookLoc.grafon.frontBmp.setPixel32(38,0,0xff778899);
    hookEvent.kind="ink-after";hookEvent.token=reply.token;notify(hookEvent);
    check(hookWall.checkpoint(hookLoc).length==0,"world reset invalidates in-flight ordinary ink token identity");
    hookWall.ordinaryRole(hookLoc,true);
    notify({kind:"raster-failed",loc:hookLoc,grafon:hookLoc.grafon,bitmap:hookLoc.grafon.frontBmp});
    check(hookWall.hasNeedsNative(hookLoc)&&!hookWall.finishRestore(hookLoc),"native failed raster closes restore release even without pending cells");
    check(hookWall.nativeRaster(hookLoc,hookLoc.grafon.frontBmp,true)&&hookWall.finishRestore(hookLoc),"a later real successful native raster clears only raster failure");
    var invalidReply:Object=notify({kind:"structure-before",loc:hookLoc,grafon:hookLoc.grafon,bitmap:hookLoc.grafon.frontBmp,bounds:new Rectangle(0,0,40,40),ordinaryPhysical:true,valid:true,token:null});
    check(invalidReply.allow===true&&hookWall.hasNeedsNative(hookLoc)&&!hookWall.finishRestore(hookLoc),"owner missing pre-die evidence preserves native behavior but blocks qualification and release");
    check(!hookWall.nativeRaster(hookLoc,hookLoc.grafon.frontBmp,true),"ordinary raster cannot silently clear an unknown structural footprint failure");
    hookWall.reset();var remembered:Object=small(),foreign:Object=small();hookWall.ordinaryRole(remembered,true);
    foreign.grafon.sceneLarge=true;remembered.grafon=foreign.grafon;
    var prep:Object=notify({kind:"structure-prepare",loc:remembered,grafon:foreign.grafon,bitmap:null,bounds:new Rectangle(0,0,40,40),ordinaryPhysical:true,valid:true});
    notify({kind:"structure-pending",loc:remembered,grafon:foreign.grafon,bitmap:null,bounds:prep.bounds,token:prep,ordinaryPhysical:true,valid:true});
    check(hookWall.hasNeedsNative(remembered)&&hookWall.checkpoint(remembered)[0].needsNative===true&&pixel(foreign)==0xff777777,"cached old ordinary room receives pending destruction even while shared Grafon displays large room");
    var nonowner:Object=small();hookWall.ordinaryRole(nonowner,false);
    var blockedDraw:Object=notify({kind:"structure-before",loc:nonowner,grafon:nonowner.grafon,bitmap:nonowner.grafon.frontBmp,bounds:new Rectangle(0,0,40,40),ordinaryPhysical:true,valid:true,token:null});
    check(blockedDraw.allow===false&&!hookWall.hasNeedsNative(nonowner),"non-authority remote tileDie needs no old local eraser footprint because foreground write is deferred");
    var ignored:Object=notify({kind:"structure-before",loc:nonowner,grafon:nonowner.grafon,bitmap:nonowner.grafon.frontBmp,bounds:new Rectangle(0,0,40,40),ordinaryPhysical:false,valid:true,token:null});
    check(ignored==null,"unqualified magic/other structural path retains original draw permission");
    var throwLoc:Object=small();hookWall.ordinaryRole(throwLoc,true);
    var safePrepare:Object=notify({kind:"structure-prepare",loc:throwLoc,grafon:throwLoc.grafon,bitmap:null,bounds:new Rectangle(0,0,40,40),ordinaryPhysical:true,valid:true});
    var bridgeThrew:Boolean=false;
    try{notify({kind:"structure-pending",loc:throwLoc,grafon:throwLoc.grafon,bitmap:null,bounds:new Rectangle(NaN,0,40,40),token:safePrepare,ordinaryPhysical:true,valid:true});}catch(observationError:Error){bridgeThrew=true;}
    check(bridgeThrew&&hookWall.hasNeedsNative(throwLoc)&&!hookWall.finishRestore(throwLoc),"real consumer exception propagates to native boundary and sticky bridge failure forbids ready");
   }catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}
   var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   fs.writeUTFBytes(JSON.stringify({assertions:assertions,passed:failed==0,count:assertions.length,failed:failed,diagnostic_only:true}));fs.close();NativeApplication.nativeApplication.exit(failed?1:0);
  }
 }
}
