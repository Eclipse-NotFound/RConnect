package {
   import flash.desktop.NativeApplication;
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.ColorTransform;
   import flash.utils.getTimer;
   import fe.loc.Tile;
   import rconnect.game.ControlRoomTerrainView;
   import rconnect.game.RoomTerrainView;
   import rconnect.test.CountingRoom;

   /** Complete old/new production views, separate declared-field fixtures.
    * This is not a native game, RV, room-loading or performance test. */
   public class RoomRestoreAllocationChecks extends Sprite {
      private static const INPUTS:Array=['X','Y','phis','shelf','phX1','phX2','phY1','phY2',
         'zForm','diagon','stair','water','vid','vid2','front','back','zad','fRear','vRear',
         'v2Rear','opac','mat','kontur','konturRot','floor','place','fake','door'];
      private static const REPLACEMENTS:Array=[9,9,2,true,99,99,99,99,2,2,2,2,2,2,
         'changed','changed','changed',true,true,true,0.5,2,2,2,2,false,true,{id:'new-door'}];
      private static const CONTOURS:Array=['kont1','kont2','kont3','kont4','pont1','pont2','pont3','pont4'];
      private var assertions:Array=[],queue:Array=[],failed:int=0,done:Boolean=false;
      private var started:int=getTimer(),active:String='';

      public function RoomRestoreAllocationChecks() {
         caseOf('unchanged',null,null,true,4);
         for(var i:int=0;i<INPUTS.length;i++)fieldCase(String(INPUTS[i]),REPLACEMENTS[i]);
         for each(var key:String in ['phX1','phX2','phY1','phY2','opac'])
            valueCase('stable NaN '+key,key,NaN,NaN,false);
         valueCase('strict front string/number','front','1',1,false);
         valueCase('strict front zero/false','front',0,false,false);
         valueCase('strict front numeric equality','front',1,1,true);
         valueCase('strict front string/false','front','0',false,false);
         valueCase('numeric Number/int equality','phX1',Number(1),int(1),true);
         valueCase('numeric signed zero equality','phX1',0,-0,true);
         valueCase('numeric infinity equality','phX1',Number.POSITIVE_INFINITY,Number.POSITIVE_INFINITY,true);
         valueCase('door null/undefined absent','door',null,undefined,true);
         valueCase('door different owners both present','door',{id:'old'},{id:'new'},true);
         valueCase('door present/absent','door',{id:'old'},null,false);
         valueCase('door zero/false both present','door',0,false,true);
         valueCase('door null/zero','door',null,0,false);
         ignoredCase('hp',123);ignoredCase('visi',0.75);ignoredCase('trap',{id:'trap'});
         caseOf('native rebuild short circuit',null,function(r:CountingRoom):void {
            r.isRebuild=true;r.failAfter=0;
         },false,0);
         caseOf('style short circuit',null,function(r:CountingRoom):void {
            r.backwall='changed';r.failAfter=0;
         },false,0);
         caseOf('backdrop identity short circuit',null,function(r:CountingRoom):void {
            r.backobjs=[backdrop()];r.failAfter=0;
         },false,0);
         caseOf('first tile mismatch short circuit',null,function(r:CountingRoom):void {
            r.raw[0][0].X=999;r.failAfter=1;
         },false,1);
         caseOf('first tile null short circuit',null,function(r:CountingRoom):void {
            r.raw[0][0]=null;r.failAfter=1;
         },false,1);
         queue.push({label:'refresh contours light callbacks',action:refreshCase});
         addEventListener(Event.ENTER_FRAME,onFrame);
      }
      private static function independent(value:*):* {
         if(value!==null && value!==undefined && typeof value=='object') {
            var copy:Object={};for(var key:String in value)copy[key]=value[key];return copy;
         }
         return value;
      }
      private function fieldCase(key:String,value:*):void {
         caseOf('mismatch '+key,null,function(r:CountingRoom):void {
            r.raw[1][1][key]=independent(value);
         },false,4);
      }
      private function valueCase(label:String,key:String,before:*,after:*,expected:Boolean):void {
         caseOf(label,function(r:CountingRoom):void {r.raw[1][1][key]=independent(before);},
            function(r:CountingRoom):void {r.raw[1][1][key]=independent(after);},expected,4);
      }
      private function ignoredCase(key:String,value:*):void {
         caseOf('ignored '+key,null,function(r:CountingRoom):void {
            r.raw[1][1][key]=independent(value);
         },true,4);
      }
      private function caseOf(label:String,setup:Function,change:Function,expected:Boolean,reads:int):void {
         queue.push({label:label,action:function():void {
            var a:CountingRoom=room(),b:CountingRoom=room();
            try {
               if(setup!=null){setup(a);setup(b);}
               var old:ControlRoomTerrainView=new ControlRoomTerrainView(a);
               var fresh:RoomTerrainView=new RoomTerrainView(b);
               if(change!=null){change(a);change(b);}
               var stateA:Array=snapshot(a),stateB:Array=snapshot(b);
               a.reads=0;b.reads=0;
               var resultA:Boolean=old.unchanged(a),resultB:Boolean=fresh.unchanged(b);
               var readsA:int=a.reads,readsB:int=b.reads;
               check(resultA==expected && resultB==expected && resultA==resultB
                  && readsA==reads && readsB==reads && equal(stateA,snapshot(a))
                  && equal(stateB,snapshot(b)) && a.events.length==0 && b.events.length==0,
                  label+' old/new='+resultA+'/'+resultB+' reads='+readsA+'/'+readsB);
            } catch(error:*) {check(false,label+' exception '+errorText(error));}
            finally {dispose(a);dispose(b);}
         }});
      }
      private static function backdrop():Object {
         return {X:1,Y:2,scX:1,scY:1,alpha:0.75,blend:'normal',sloy:0,er:0,vis:true,erase:false,light:false};
      }
      private static function room():CountingRoom {
         var r:CountingRoom=new CountingRoom();
         r.spaceX=2;r.spaceY=2;r.isRebuild=false;r.isRecalc=false;
         for(var x:int=0;x<2;x++) {
            r.raw[x]=[];
            for(var y:int=0;y<2;y++) {
               var t:Tile=new Tile(x,y);r.raw[x][y]=t;
               for(var i:int=0;i<CONTOURS.length;i++)t[CONTOURS[i]]=10+x*20+y*8+i;
            }
         }
         r.backwall='back';r.backform=0;r.darkness=0;r.transpFon=0;r.tipWater=0;r.gas=0;
         r.homeStable=false;r.black=true;r.lightOn=true;r.limX=2;r.limY=2;r.color=0;
         r.cTransform=new ColorTransform();r.cTransformFon=new ColorTransform();
         r.backobjs=[backdrop()];r.events=[];r.cameraRoom=null;
         var renderer:Object={loc:r,lightBmp:new BitmapData(2,2,true,0),visLight:{visible:false}};
         renderer.setLight=function():void {r.events.push('setLight');renderer.lightBmp.setPixel32(0,0,0xFFAABBCC);};
         renderer.warShadow=function():void {r.events.push('warShadow');};
         renderer.drawAllObjs=function():void {r.events.push('drawAllObjs');};
         r.grafon=renderer;
         r.world={black:true,cam:{setLoc:function(loc:Object):void {r.events.push('setLoc');r.cameraRoom=loc;}},
            gui:{setAll:function():void {r.events.push('setAll');}}};
         return r;
      }
      private static function snapshot(r:CountingRoom):Array {
         var values:Array=[];
         var names:Array=INPUTS.concat(CONTOURS).concat(['hp','visi','trap']);
         for(var x:int=0;x<2;x++)for(var y:int=0;y<2;y++) {
            var tile:Object=r.raw[x][y];values.push(tile);
            if(tile!=null)for each(var name:String in names)values.push(tile[name]);
         }
         return values;
      }
      private static function equal(a:Array,b:Array):Boolean {
         if(a.length!=b.length)return false;
         for(var i:int=0;i<a.length;i++) {
            if(a[i]===b[i])continue;
            if(a[i] is Number && b[i] is Number && isNaN(Number(a[i])) && isNaN(Number(b[i])))continue;
            return false;
         }
         return true;
      }
      private function refreshCase():void {
         var a:CountingRoom=room(),b:CountingRoom=room();
         try {
            var old:ControlRoomTerrainView=new ControlRoomTerrainView(a);
            var fresh:RoomTerrainView=new RoomTerrainView(b);
            var stateA:Array=snapshot(a),stateB:Array=snapshot(b);
            for(var x:int=0;x<2;x++)for(var y:int=0;y<2;y++)for each(var key:String in CONTOURS) {
               a.raw[x][y][key]=-1;b.raw[x][y][key]=-1;
            }
            old.refresh(a.world);fresh.refresh(b.world);
            var pixelsA:BitmapData=a.grafon.lightBmp,pixelsB:BitmapData=b.grafon.lightBmp;
            var samePixels:Boolean=true;
            for(x=0;x<2;x++)for(y=0;y<2;y++)
               if(pixelsA.getPixel32(x,y)!==pixelsB.getPixel32(x,y))samePixels=false;
            check(equal(stateA,snapshot(a)) && equal(stateB,snapshot(b)) && samePixels
               && pixelsA.getPixel32(0,0)===uint(0xFFAABBCC) && pixelsA.getPixel32(1,1)===uint(0xFF000000)
               && a.events.join(',')=='setLight,warShadow,drawAllObjs,setLoc,setAll'
               && b.events.join(',')==a.events.join(',') && a.cameraRoom===a && b.cameraRoom===b
               && a.grafon.visLight.visible===true && b.grafon.visLight.visible===true,
               'refresh preserves saved contours, light pixels, visibility and callback order');
         }catch(error:*) {check(false,'refresh exception '+errorText(error));}
         finally {dispose(a);dispose(b);}
      }
      private static function dispose(r:CountingRoom):void {r.grafon.lightBmp.dispose();}
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});if(!ok)failed++;}
      private static function errorText(value:*):String {
         return value is Error?value.name+':'+value.message+':'+value.errorID:String(value);
      }
      private function onFrame(e:Event):void {
         if(done)return;
         var at:int=getTimer();
         try {
            do {
               if(!queue.length){finish();return;}
               var item:Object=queue.shift();active=item.label;item.action();
            }while(getTimer()-at<8);
         }catch(error:*) {check(false,'unexpected '+active+' '+errorText(error));finish();}
      }
      private function finish():void {
         if(done)return;done=true;removeEventListener(Event.ENTER_FRAME,onFrame);
         if(assertions.length!=55)check(false,'expected exactly 55 complete cases');
         var result:Object={passed:failed==0,failed:failed,assertions:assertions,elapsed:getTimer()-started,
            actual_complete_old_new_terrain_view:true,independent_fixtures:true,fixture_front_type_relaxed:true,
            gamebridge_scan_source_proof_only:true,native_game:false,performance_qualified:false};
         var stream:FileStream=new FileStream();
         try {stream.open(File.applicationStorageDirectory.resolvePath('result.json'),FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify(result));}
         finally {stream.close();}
         trace(JSON.stringify(result));NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
