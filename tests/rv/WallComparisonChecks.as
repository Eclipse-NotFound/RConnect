package {
   import flash.display.*;
   import flash.geom.*;
   import flash.filters.BlurFilter;
   import flash.desktop.NativeApplication;
   import flash.filesystem.*;
   import flash.utils.getTimer;

   /** Pixel and callback-order differential against the exact installed class.
    * Both renderers see the same native-style inputs, including in-place changes. */
   public class WallComparisonChecks extends Sprite {
      private var baseline:BaselineWallSurface=new BaselineWallSurface();
      private var candidate:RVWallSurface=new RVWallSurface();
      private var oldFog:Sprite=new Sprite(),fog:Sprite=new Sprite(),front:Sprite=new Sprite();
      private var oldBase:Sprite,base:Sprite,tiles:Array=[],loc:Object;
      private var texture:BitmapData=new BitmapData(400,320,true,0);
      private var mode:String="current",bright:Boolean=false,knownMode:int=1,intensity:Number=.35;
      private var calls:Array,inject:String="",throwAt:int=0,callIndex:int;
      private var passed:int=0,failed:int=0,seed:uint=917355;
      public function WallComparisonChecks(){
         try{run();}catch(e:Error){check(false,e+" "+e.getStackTrace());}
         trace("WALL COMPARISON COMPLETE passed="+passed+" failed="+failed);
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function check(ok:Boolean,label:String):void {
         if(ok)passed++;else failed++;trace((ok?"PASS ":"FAIL ")+label);
      }
      private function random():uint {seed=uint(seed*1664525+1013904223);return seed;}
      private function makeBase(offset:int=0):Sprite {
         var s:Sprite=new Sprite(),raw:BitmapData=new BitmapData(80,64,true,0);
         for(var y:int=0;y<64;y++)for(var x:int=0;x<80;x++)raw.setPixel32(x,y,uint((x*11+y*3+offset)%256)<<24);
         var b:Bitmap=new Bitmap(raw,"auto",true);b.scaleX=b.scaleY=5;
         if(mode=="current")b.filters=[new BlurFilter(4,4,3)];s.addChild(b);
         var wall:Sprite=new Sprite(),clip:Shape=new Shape();
         wall.graphics.beginFill(0,.8);wall.graphics.drawRect(0,0,400,320);wall.graphics.endFill();
         clip.graphics.beginFill(0xffffff);clip.graphics.drawRect(80,80,200,160);clip.graphics.endFill();
         s.addChild(wall);s.addChild(clip);wall.mask=clip;return s;
      }
      private function replaceBase(offset:int):void {
         if(oldBase!=null){oldFog.removeChild(oldBase);fog.removeChild(base);}
         oldBase=makeBase(offset);base=makeBase(offset);oldFog.addChildAt(oldBase,0);fog.addChildAt(base,0);
      }
      private function sample(kind:String,args:Array):void {
         calls.push(kind+":"+args.join(","));
         if(kind==inject && ++callIndex==throwAt)throw new Error("injected callback interruption");
      }
      private function known(x:int,y:int):Boolean {
         sample("known",[x,y]);return knownMode==2 || (knownMode==1&&(y==1||x==1||(x+y)%3==0));
      }
      private function light(x:int,y:int,wx:Number,wy:Number,dir:int):Number {
         sample("light",[x,y,wx,wy,dir]);return intensity*(.5+.5*wx/400);
      }
      private function imageOf(s:Sprite):BitmapData {
         var b:BitmapData=new BitmapData(400,320,false,0xffffff);b.draw(s,null,null,null,null,true);return b;
      }
      private function dump(name:String,b:BitmapData):void {
         var dir:File=File.applicationStorageDirectory.resolvePath("evidence");dir.createDirectory();
         var f:FileStream=new FileStream();f.open(dir.resolvePath(name+".png"),FileMode.WRITE);
         f.writeBytes(b.encode(b.rect,new PNGEncoderOptions()));f.close();
      }
      private function equalPixels(a:BitmapData,b:BitmapData,label:String):void {
         var delta:Object=a.compare(b),ok:Boolean=delta is uint&&uint(delta)==0;
         check(ok,label+" exact pixels");
         if(!ok){dump("failure-"+failed+"-baseline",a);dump("failure-"+failed+"-candidate",b);}
         if(delta is BitmapData)BitmapData(delta).dispose();
      }
      private function compare(label:String,view:Rectangle=null,capture:Boolean=false):void {
         view=view||new Rectangle(0,0,10,8);calls=[];callIndex=0;
         baseline.update(oldFog,oldBase,{visFront:front},loc,view,known,light,bright);
         var expected:String=calls.join("|");calls=[];callIndex=0;
         candidate.update(fog,base,{visFront:front},loc,view,known,light,bright);
         check(expected==calls.join("|"),label+" same samples and order");
         check(baseline.fieldUpdates==candidate.fieldUpdates&&baseline.terrainUpdates==candidate.terrainUpdates,
            label+" same field/terrain redraw counts");
         check(baseline.faces.join(",")==candidate.faces.join(","),label+" same wall faces");
         var a:BitmapData=imageOf(oldFog),b:BitmapData=imageOf(fog);
         equalPixels(a,b,label);
         if(capture){dump(label+"-baseline",a);dump(label+"-candidate",b);}
         a.dispose();b.dispose();
      }
      private function interruption(kind:String):void {
         // Change before the interruption, then repeat exactly the input. A
         // partially committed value cache must still repaint on recovery.
         inject=kind;throwAt=9;intensity=.71;knownMode=2;
         if(kind=="height")tiles[0].opac=1;
         var errors:int=0;
         for each(var renderer:Object in [baseline,candidate]) {
            calls=[];callIndex=0;
            try{renderer.update(renderer===baseline?oldFog:fog,renderer===baseline?oldBase:base,
               {visFront:front},loc,new Rectangle(0,0,10,8),known,light,bright);}
            catch(e:Error){if(e.message=="injected callback interruption")errors++;else throw e;}
         }
         check(errors==2,kind+" interruption exercised both implementations");inject="";
         compare(kind+" exception recovery");
      }
      private function run():void {
         var self:WallComparisonChecks=this;
         for(var y:int=0;y<8;y++)for(var x:int=0;x<10;x++)tiles.push({opac:x>=2&&x<=6&&y>=2&&y<=5?1:0,zForm:0});
         loc={spaceX:10,spaceY:8,getTile:function(x:int,y:int):Object{self.sample("height",[x,y]);return self.tiles[x+y*10];}};
         texture.fillRect(new Rectangle(80,80,200,160),0xffffffff);
         texture.fillRect(new Rectangle(140,80,10,15),0);texture.fillRect(new Rectangle(180,80,8,15),0x80ffffff);
         front.addChild(new Bitmap(texture));
         for each(mode in ["classic","current"]) {
            replaceBase(0);
            for each(bright in [false,true]) {
               compare(mode+(bright?"-on":"-off"),null,true);
               compare("unchanged "+mode+bright);
            }
         }
         for(var n:int=0;n<96;n++) {
            if(n%8==0){x=random()%80;tiles[x].opac=Number(random()%2);tiles[x].zForm=random()%4;}
            if(n%8==1)knownMode=random()%3;
            if(n%8==2)intensity=Number(random()%350)/255-.2;
            if(n%8==3)bright=!bright;
            if(n%8==4)texture.setPixel32(random()%400,random()%320,random());
            if(n%8==5)replaceBase(int(random()%255));
            var view:Rectangle=n%8==6?new Rectangle(1,2,6,4):new Rectangle(0,0,10,8);
            compare("transition "+n,view);
         }
         knownMode=2;intensity=NaN;compare("NaN initial");compare("NaN stable");
         intensity=Number.POSITIVE_INFINITY;compare("infinity clamps");
         intensity=Number.NEGATIVE_INFINITY;compare("negative infinity clamps");
         intensity=.35;knownMode=1;compare("finite reset");interruption("height");
         knownMode=1;compare("before known failure");interruption("known");
         intensity=.35;compare("before light failure");interruption("light");
         front.visible=false;compare("hidden foreground");front.visible=true;compare("restore foreground");
         compare("empty view",new Rectangle());compare("restore view");
         loc={spaceX:10,spaceY:8,getTile:loc.getTile};compare("new room identity");
         baseline.reset();candidate.reset();compare("explicit reset");
         for each(var tile:Object in tiles)tile.opac=0;compare("all wall faces removed");
         compare("all wall faces stable");
      }
   }
}
