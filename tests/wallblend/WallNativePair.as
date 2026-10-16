package {
    import flash.desktop.NativeApplication;
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.geom.*;
    import flash.net.URLRequest;
    import flash.system.*;
    import flash.utils.getTimer;

    /** Both exact production SWFs see the SAME native pixels, including random impacts. */
    public class WallNativePair {
        private static var host:*,world:*,state:int=0,started:int,step:int=0;
        private static var first:Class,second:Class,loader:Loader;
        private static var assertions:Array=[],images:Array=[];
        private static var colors:Array=["D","E","G","H","I","C","F","A"];
        public static function init(main:*):void {
            if(NativeApplication.nativeApplication.applicationID.indexOf("wallblend-test-rconnect-pair-")!=0)return;
            host=main;started=getTimer();main.stage.addEventListener(Event.ENTER_FRAME,tick,false,-200);
        }
        private static function tick(e:Event):void {
            try {
                if(getTimer()-started>240000)throw new Error("paired native timeout at "+state+"/"+step);
                world=ApplicationDomain.currentDomain.getDefinition("fe.World")["w"];
                if(!world)return;
                if(world.verror.visible)throw new Error(world.verror.txt.text);
                if(state==0 && world.allLandsLoaded && world.grafon.resIsLoad && world.mm) {
                    state=1;world.mm.active=false;world.newGame(-1,"WallBlend shared pixels",null);
                } else if(state==1 && world.loc && world.gg && world.allStat==1 && world.ng_wait==0) {
                    host.stage.removeEventListener(Event.ENTER_FRAME,world.mm.mainStep);
                    state=2;load("WallBlendControl.swf",true);
                } else if(state==4) {
                    state=5;first["init"](host);second["init"](host);
                    check(first["status"].version=="0.5.4-scene" && second["status"].version=="0.5.5-scene","exact old and new production identities");
                    fixture(false);compare("initial");
                } else if(state==5) {
                    runCase(step++);if(step>17)finish();
                }
            }catch(error:Error){check(false,error.message+" "+error.getStackTrace());finish();}
        }
        private static function load(path:String,old:Boolean):void {
            loader=new Loader();loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void {check(false,e.text);finish();});
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
                var entry:Class=loader.contentLoaderInfo.applicationDomain.getDefinition("WallBlendMod") as Class;
                if(old){first=entry;state=3;load("WallBlendCandidate.swf",false);}else{second=entry;state=4;}
            });
            loader.load(new URLRequest("app:/"+path),new LoaderContext(false,new ApplicationDomain(ApplicationDomain.currentDomain)));
        }
        private static function both(method:String,value:*=null):void {
            if(value===null){first[method]();second[method]();}else{first[method](value);second[method](value);}
        }
        private static function fixture(large:Boolean):void {
            var g:*=world.grafon,l:*=world.loc,tc:Class=ApplicationDomain.currentDomain.getDefinition("fe.loc.Tile") as Class;
            // The native scene renderer owns the large-to-small teardown. Do
            // not call an enabled mod with sceneLarge=true and grafon.loc=null.
            both("setEnabled",false);g.loc=null;both("refreshNow");
            l.spaceX=large?60:48;l.spaceY=25;l.limX=l.spaceX*40;l.limY=1000;l.space=[];
            l.cTransform=new ColorTransform();l.backobjs=[];l.signposts=[];l.firstObj=null;l.backwall="";
            l.black=false;world.black=false;l.gas=0;l.homeStable=false;l.destroyOn=true;l.active=true;l.tileSpawn=0;
            for(var x:int=0;x<l.spaceX;x++) {
                l.space[x]=[];
                for(var y:int=0;y<25;y++) {
                    var t:*=new tc(x,y);t.dec("");
                    if(y<7 || y>=14 && y<19) {
                        t.dec(colors[int(x/6)%colors.length]);
                        if(y==14)t.setZForm((x%3)+1);
                    }
                    t.back=(x%12<6)?"A":"D";t.visi=1;l.space[x][y]=t;
                }
            }
            g.drawLoc(l);world.cam.setLoc(l);world.cam.setZoom(2);world.cam.calc(world.gg);
            both("setEnabled",true);both("refreshNow");
        }
        private static function runCase(n:int):void {
            var g:*=world.grafon,l:*=world.loc;
            if(n==0)compare("unchanged");
            if(n==1){g.dyrka(240,120,1,1,false,.5);g.frontBmp.setPixel32(239,120,0xffdc235a);compare("same-random-impact");}
            if(n==2){both("setMode","second");compare("impact-second");}
            if(n==3){both("setMode","current");compare("impact-current");}
            if(n==4){l.hitTile(l.space[6][4],2000,260,180,4);compare("same-native-destruction");}
            if(n==5){l.space[5][5].hp=1;l.space[5][5].fake=true;l.space[5][5].thre=0;l.space[5][5].indestruct=false;compare("one-hit-wall");}
            if(n==6){l.hitTile(l.space[5][5],2,220,220,4);compare("one-hit-broken");}
            if(n==7){both("refreshNow");compare("invalidated-damage");}
            if(n==8){l.cTransform=new ColorTransform(.7,.8,.6);g.drawLoc(l);compare("tinted-redraw");}
            if(n==9){both("setMode","second");compare("tinted-second");}
            if(n==10){both("setMode","current");fixture(true);compare("large-scene");}
            if(n==11){l.hitTile(l.space[8][4],2000,340,180,4);compare("large-scene-hit");}
            if(n==12){l.space[7][15].back="D";l.space[8][15].back="A";g.drawLoc(l);compare("background-material-change");}
            if(n==13){both("setStyle","materialWeathered");compare("weathered-mode");}
            if(n==14){both("setMode","current");fixture(false);compare("return-normal-room");}
            if(n==15){l.backwall="A";l.lightOn=!l.lightOn;g.drawLoc(l);compare("lighting-change");}
            if(n==16){g.loc=null;both("refreshNow");g.drawLoc(l);compare("dispose-reenter");}
            if(n==17)compare("final-unchanged");
        }
        private static function frame(g:*,back:Boolean):BitmapData {
            // In a native large scene frontBmp is only a working chunk. Capture
            // the complete location-sized display layers, not that small tile.
            var image:BitmapData=new BitmapData(Math.max(g.frontBmp.width,world.loc.spaceX*40),
                Math.max(g.frontBmp.height,world.loc.spaceY*40),true,0);
            image.draw(back?g.visBack:g.visFront);return image;
        }
        private static function compare(label:String):void {
            // Enable updates both ways without invalidating their persistent caches.
            // Neither renderer changes the native source bitmap. Only its own layer
            // visibility changes while obtaining the two independent views.
            var g:*=world.grafon,before:BitmapData=g.frontBmp.clone();
            second["setEnabled"](false);first["setEnabled"](true);
            var oldFront:BitmapData=frame(g,false),oldBack:BitmapData=frame(g,true);
            var oldMetrics:Object=JSON.parse(JSON.stringify(first["status"]));
            first["setEnabled"](false);second["setEnabled"](true);
            var newFront:BitmapData=frame(g,false),newBack:BitmapData=frame(g,true);
            var newMetrics:Object=JSON.parse(JSON.stringify(second["status"]));
            if(label=="initial") {
                check(oldMetrics.render.patches>0 && newMetrics.render.patches>0,"foreground comparison contains real overlay patches");
                check(oldMetrics.background.patches>0 && newMetrics.background.patches>0,"background comparison contains real overlay patches");
            }
            check(oldFront.compare(newFront)===0,label+" full foreground RGBA equal");
            check(oldBack.compare(newBack)===0,label+" full background RGBA equal");
            check(before.compare(g.frontBmp)===0,label+" native pixels unchanged");
            for each(var part:String in ["render","background"]) for each(var key:String in ["rebuilds","partialRebuilds","patches","pixels"])
                check(oldMetrics[part][key]===newMetrics[part][key],label+" "+part+" "+key+" equal");
            check(!oldMetrics.failed&&!newMetrics.failed,label+" neither production module failed");
            for each(var item:Object in [{name:"old-front",b:oldFront},{name:"new-front",b:newFront},{name:"old-back",b:oldBack},{name:"new-back",b:newBack}]) {
                var name:String=label+"-"+item.name+".png";saveImage(name,item.b);images.push(name);item.b.dispose();
            }
            before.dispose();first["setEnabled"](true);second["setEnabled"](true);
        }
        private static function check(ok:Boolean,name:String):void {assertions.push({passed:ok,name:name});trace((ok?"PASS ":"FAIL ")+name);}
        private static function saveImage(name:String,b:BitmapData):void {
            var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);
            // Lossless fast compression keeps evidence writing from dominating
            // this pixel-equivalence test; dimensions and RGBA stay unchanged.
            file.writeBytes(b.encode(b.rect,new PNGEncoderOptions(true)));file.close();
        }
        private static function finish():void {
            if(state==99)return;state=99;host.stage.removeEventListener(Event.ENTER_FRAME,tick);
            var ok:Boolean=true;for each(var a:Object in assertions)if(!a.passed)ok=false;
            var file:FileStream=new FileStream();file.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
            file.writeUTFBytes(JSON.stringify({passed:ok,assertions:assertions,images:images,durationMs:getTimer()-started},null,2));file.close();
            NativeApplication.nativeApplication.exit(ok?0:1);
        }
    }
}
