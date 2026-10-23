package {
 import flash.desktop.NativeApplication;
 import flash.display.Sprite;
 import flash.display.BitmapData;
 import flash.events.Event;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import flash.system.ApplicationDomain;
 import fe.graph.Grafon;
 import fe.weapon.Bullet;
 import rconnect.game.WallImpactVisuals;
 import rconnect.game.NativeWallColor;
 import rconnect.net.RoomCodec;
 public class WallAckChecks extends Sprite {
  private var assertions:Array=[],failed:int=0;
  public function WallAckChecks(){addEventListener(Event.ADDED_TO_STAGE,run);}
  private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});if(!ok)failed++;}
  private function room():Object {
   var l:Object={spaceX:2,spaceY:2,space:[],firstObj:null};
   for(var x:int=0;x<2;x++){l.space[x]=[];for(var y:int=0;y<2;y++)l.space[x][y]={phis:1,hp:100};}
   l.grafon={loc:l,sceneLarge:false,frontBmp:new BitmapData(80,80,true,0xff777777)};return l;
  }
  private function ink(w:WallImpactVisuals,l:Object,color:uint,x:int=38):void {
   w.before(l);var b:Bullet=new Bullet(l,x,0);l.firstObj=b;
   BitmapData(l.grafon.frontBmp).setPixel32(x,0,NativeWallColor.setter(color));b.tilehit=true;w.observe(l);
  }
  private function ack(seq:int,x:int=0,v:int=1,color:uint=0xffaa0000):Object {
   return {seq:seq,cells:[{x:x,y:0,v:v,sv:0,full:false,d:RoomCodec.pack([38,Number(color)])}]};
  }
  private function run(e:Event):void {
   removeEventListener(Event.ADDED_TO_STAGE,run);
   try {
    var l:Object=room(),w:WallImpactVisuals=new WallImpactVisuals();w.ordinaryRole(l,false);
    check(!w.acknowledge(l,null),"no pending/null receipt cannot create a flush opportunity");
    ink(w,l,0xffaa0000);var first:Object=w.report(l,false);
    check(first!=null,"real wall class creates the first pending batch");
    ink(w,l,0xffbb0000,37);
    check(w.report(l,false)==null,"queued second mark remains blocked by real pending");
    check(!w.acknowledge(l,ack(first.seq+1)),"future or unrelated seq does not retire current pending");
    check(!w.acknowledge(l,{seq:first.seq,cells:[]}),"incomplete cell set cannot open flush opportunity");
    check(!w.acknowledge(l,ack(first.seq,1)),"different cell set cannot open flush opportunity");
    check(!w.acknowledge(l,{seq:first.seq,cells:[{x:0,y:0,v:1,sv:0,full:false,d:"bad"}]}),"malformed cell payload cannot open flush opportunity");
    check(w.report(l,false)==null,"all rejected ACKs preserve pending and queued state");
    check(w.acknowledge(l,ack(first.seq)),"valid complete ordinary ACK returns true after composition");
    var second:Object=w.report(l,false);
    check(second!=null&&second.seq>first.seq,"retired ACK permits exactly one next queued batch");
    check(!w.acknowledge(l,ack(first.seq)),"old duplicate cannot retire the new batch");
    check(w.report(l,false)==null,"single pending continues to block an additional drain");
    check(w.acknowledge(l,{seq:second.seq,cells:[{x:0,y:0,v:2,sv:0,full:false,d:RoomCodec.pack([37,Number(0xffbb0000)])}]}),"second valid ACK retires second pending");
    check(w.report(l,false)==null,"valid ACK with no queued ink yields no empty report");
    check(!w.acknowledge(l,ack(second.seq)),"duplicate after retirement returns false");
    ink(w,l,0xffcc0000);var third:Object=w.report(l,false);
    w.receive(l,[{x:0,y:0,v:100,sv:0,full:false,d:RoomCodec.pack([38,Number(0xff00aa00)])}],false);
    check(w.acknowledge(l,ack(third.seq,0,3,0xffcc0000)),"older authority v still truthfully retires matching transport seq");
    check(BitmapData(l.grafon.frontBmp).getPixel32(38,0)==0xff00aa00,"retirement preserves newest confirmed pixels");
    ink(w,l,0xffdd0000);var abandoned:Object=w.report(l,false);w.roleChanged(l);
    check(!w.acknowledge(l,ack(abandoned.seq)),"roleChanged retires transport so late ACK cannot open flush");
    var other:Object=room();w.ordinaryRole(other,false);
    check(!w.acknowledge(other,ack(abandoned.seq)),"another room has no matching pending batch");
    w.reset();check(!w.acknowledge(l,ack(abandoned.seq)),"reset/failed-session cleanup leaves no flush opportunity");
   } catch(error:Error){check(false,"uncaught: "+error.getStackTrace());}
   var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   fs.writeUTFBytes(JSON.stringify({assertions:assertions,passed:failed==0,count:assertions.length,failed:failed,diagnostic_only:true,
    session_transport_tested:false,performance_qualified:false}));fs.close();NativeApplication.nativeApplication.exit(failed?1:0);
  }
 }
}
