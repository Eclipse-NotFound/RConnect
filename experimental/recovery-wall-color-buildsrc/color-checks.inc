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
