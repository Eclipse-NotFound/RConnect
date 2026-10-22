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
