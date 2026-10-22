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
