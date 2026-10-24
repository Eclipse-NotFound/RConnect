package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import fe.weapon.Bullet;
   import rconnect.game.WallImpactVisuals;
   import rconnect.net.RoomCodec;

   /** Small native-contact fixture reused from WorkingSetChecks: actual
    * BitmapData pixels and full current WIV/codec, no private test wrappers. */
   public class WallFirstRasterChecks extends Sprite {
      private var rows:Array=[];
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      public function WallFirstRasterChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function world():Object {
         var loc:Object={spaceX:4,spaceY:2,space:[],firstObj:null};
         for(var x:int=0;x<4;x++){loc.space[x]=[];for(var y:int=0;y<2;y++)loc.space[x][y]={hp:10,phis:1};}
         loc.grafon={loc:loc,frontBmp:new BitmapData(160,80,true,0xff222222),rconnectRasterPending:false};return loc;
      }
      private function equalPixels(a:BitmapData,b:BitmapData):Boolean {
         var av:Vector.<uint>=a.getVector(a.rect),bv:Vector.<uint>=b.getVector(b.rect);
         if(av.length!=bv.length)return false;
         for(var i:int=0;i<av.length;i++)if(av[i]!=bv[i])return false;return true;
      }
      private function value(cells:Array,x:int,index:int):* {
         for each(var cell:Object in cells)if(cell.x==x && cell.y==0) {
            var words:Array=RoomCodec.unpack(cell.d) as Array;
            for(var i:int=0;i<words.length;i+=2)if(words[i]==index)return words[i+1];
         }
         return null;
      }
      private function pendingPixels():void {
         var wall:WallImpactVisuals=new WallImpactVisuals(),loc:Object=world();
         var b:BitmapData=loc.grafon.frontBmp,red:uint=0xffff0000,yellow:uint=0xffffff00;
         wall.before(loc);wall.receive(loc,[{x:0,y:0,v:1,d:RoomCodec.pack([820,red])}],false);
         check(b.getPixel32(20,20)==red,"ordinary exact WIV receive paints native front bitmap");
         var original:String=JSON.stringify(wall.checkpoint(loc));
         loc.grafon.rconnectRasterPending=true;
         b.setPixel32(20,20,0xff00ff00);b.setPixel32(60,20,0xff0000ff);
         var unfinished:BitmapData=b.clone();
         var bullet:Bullet=new Bullet();bullet.loc=loc;bullet.X=20;bullet.Y=20;bullet.tilehit=true;loc.firstObj=bullet;
         loc.space[0][0].hp--;wall.observe(loc,[{x:0,y:0}]);wall.before(loc);
         check(JSON.stringify(wall.checkpoint(loc))==original,
            "pending raster is not observed as new wall damage despite real contact and terrain delta inputs");
         check(equalPixels(b,unfinished),"pending before and observe do not repaint unfinished native pixels");
         wall.receive(loc,[{x:1,y:0,v:2,d:RoomCodec.pack([820,yellow])}],false);
         var saved:Array=wall.checkpoint(loc);
         check(saved.length==2 && value(saved,0,820)==red && value(saved,1,820)==yellow,
            "pending receive retains complete existing and incoming wall state");
         wall.redraw(loc);
         check(equalPixels(b,unfinished),"explicit redraw also waits for native raster completion");
         loc.grafon.rconnectRasterPending=false;
         b.fillRect(b.rect,0xff222222);wall.redraw(loc);
         var expected:BitmapData=new BitmapData(160,80,true,0xff222222);
         expected.setPixel32(20,20,red);expected.setPixel32(60,20,yellow);
         check(equalPixels(b,expected),"released ticket redraw reproduces both saved wall marks pixel for pixel");
         check(JSON.stringify(wall.checkpoint(loc))==JSON.stringify(saved),
            "postpaint observation does not lose or invent checkpoint cells");
         wall.reset();b.dispose();unfinished.dispose();expected.dispose();
      }
      private function restoreBeforeFirstPaint():void {
         var wall:WallImpactVisuals=new WallImpactVisuals(),loc:Object=world();
         var b:BitmapData=loc.grafon.frontBmp,base:BitmapData=b.clone(),color:uint=0xffaa33cc;
         var saved:Array=[{x:2,y:0,v:7,d:RoomCodec.pack([820,color])}];
         loc.grafon.rconnectRasterPending=true;wall.restore(loc,saved);wall.before(loc);wall.observe(loc);
         check(equalPixels(b,base),"full checkpoint restore does not write pre-raster bitmap pixels");
         var kept:Array=wall.checkpoint(loc);
         check(kept.length==1 && value(kept,2,820)==color,"full checkpoint restore retains wall state while raster is pending");
         var first:BitmapData=new BitmapData(160,80,true,0xff222222);loc.grafon.frontBmp=first;
         wall.redraw(loc);check(equalPixels(first,base),"replacement first bitmap remains unpainted while ticket is pending");
         loc.grafon.rconnectRasterPending=false;wall.redraw(loc);
         base.setPixel32(100,20,color);
         check(equalPixels(first,base),"ticket completion paints saved state on the actual replacement bitmap");
         check(b.getPixel32(100,20)==0xff222222,"abandoned pre-raster bitmap is never painted later");
         wall.reset();b.dispose();first.dispose();base.dispose();
      }
      private function begin(e:Event):void {
         try{pendingPixels();restoreBeforeFirstPaint();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false,actual_bitmap_pixels:true}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
