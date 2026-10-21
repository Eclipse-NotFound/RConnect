package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.BitmapData;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import fe.weapon.Bullet;
   import rconnect.game.*;

   /** No native game or TCP. Extracted production methods execute unchanged,
    * except loop-entry counters; native inputs/weapon discovery are fixtures. */
   public class RecoveryCostChecks extends Sprite {
      private var assertions:Array=[],failed:int=0;
      public function RecoveryCostChecks(){addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         assertions.push({passed:ok,label:label});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label);
      }
      private function clone(v:*):* {
         if(v==null || typeof v!="object")return v;
         var out:*=v is Array?[]:{};
         for(var key:String in v)out[key]=clone(v[key]);
         return out;
      }
      private function equal(a:*,b:*):Boolean {
         if(a is Number && b is Number) {
            if(isNaN(a)&&isNaN(b))return true;
            if(a==0&&b==0)return 1/Number(a)==1/Number(b);
         }
         if(a===b)return true;
         if(a==null || b==null || typeof a!=typeof b || typeof a!="object")return false;
         if((a is Array)!=(b is Array))return false;
         if(a is Array) {
            if(a.length!=b.length)return false;
            for(var i:int=0;i<a.length;i++)if(!equal(a[i],b[i]))return false;
         }
         var ak:Array=[],bk:Array=[],k:String;
         for(k in a)ak.push(k);for(k in b)bk.push(k);ak.sort();bk.sort();
         if(ak.join("|")!=bk.join("|"))return false;
         for each(k in ak)if(!equal(a[k],b[k]))return false;
         return true;
      }
      private function p(at:Number,x:Number=1):Object {
         return {at:at,x:x,y:12,rot:5,sx:1,sy:1,a:0.8,f:2,ls:1,lf:1};
      }
      private function shot(frames:Array,fastAt:*=100,prior:Object=null,fresh:Boolean=false,end:int=0):Object {
         return {seq:7,at:20,recorded:true,frames:frames,fastSent:!fresh,fastAt:fastAt,
            fastPoint:prior,fastEnd:0,fastStop:0,fastExplosion:null,fastImpact:null,
            end:end,stopped:0,endSentAt:99,explosion:null,impact:null,
            flight:{cls:"fixtureClip",x:0,y:0,ex:30,ey:0,spring:1}};
      }
      private function frameXs(result:Array,energy:Boolean=false):Array {
         if(result==null || result.length==0)return null;
         var entries:Array=energy?result[0].impacts:result[0].events;
         if(entries==null || entries.length==0)return null;
         var f:Array=energy?entries[0].frames:(entries[0].flight==null?null:entries[0].flight.frames);
         if(f==null)return null;
         var out:Array=[];for each(var point:Object in f)out.push(point.x);return out;
      }
      private function captureCase(label:String,input:Object,expectedShot:*,withEnergy:Boolean=false,expectedEnergy:*=null,
                                   expectedOldVisits:int=-1,expectedNewVisits:int=-1,
                                   sharedPointIndex:int=-1,finalSharedPointIndex:int=-1):void {
         var before:CaptureBefore=new CaptureBefore(),after:CaptureAfter=new CaptureAfter();
         var wa:Object={id:"fixture",variant:2},wb:Object={id:"fixture",variant:2};
         var a:Object=clone(input),b:Object=clone(input),source:Object=clone(input);
         // clone deliberately isolates fixtures but does not retain aliases.
         // Restore the production cursor/history identity explicitly when asked.
         if(sharedPointIndex>=0) {
            a.fastPoint=a.frames[sharedPointIndex];b.fastPoint=b.frames[sharedPointIndex];
            check(a.fastPoint===a.frames[sharedPointIndex] && b.fastPoint===b.frames[sharedPointIndex] &&
               a.fastPoint!==b.fastPoint,label+" independent shot fixtures restore shared cursor/history reference");
         }
         before.weapons=[wa];after.weapons=[wb];
         before.hostShots[wa]={stream:3,events:[a]};after.hostShots[wb]={stream:3,events:[b]};
         var ea:Object=null,eb:Object=null;
         if(withEnergy) {
            var record:Object={wire:{id:9,cls:"partFixture",layer:2,blend:"normal",frames:clone(input.frames),end:input.end},
               fastAt:input.fastAt,fastPoint:clone(input.fastPoint),fastEnd:input.fastEnd};
            before.energyImpacts.sources[wa]=[clone(record)];after.energyImpacts.sources[wb]=[clone(record)];
            ea=before.energyImpacts.sources[wa][0];eb=after.energyImpacts.sources[wb][0];
            if(sharedPointIndex>=0) {
               ea.fastPoint=ea.wire.frames[sharedPointIndex];eb.fastPoint=eb.wire.frames[sharedPointIndex];
               check(ea.fastPoint===ea.wire.frames[sharedPointIndex] && eb.fastPoint===eb.wire.frames[sharedPointIndex] &&
                  ea.fastPoint!==eb.fastPoint && ea.fastPoint!==a.fastPoint && eb.fastPoint!==b.fastPoint,
                  label+" independent energy fixtures restore shared cursor/history reference");
            }
         }
         Counter.before=0;Counter.after=0;
         var oldResult:Array=before.captureEffects({}),newResult:Array=after.captureEffects({});
         check(equal(oldResult,newResult),label+" complete payload, field presence/types/order");
         check(equal(a,b),label+" complete mutable shot state/cursors");
         check(equal(a.frames,source.frames)&&equal(b.frames,source.frames),label+" input history is not changed");
         check(equal(frameXs(newResult),expectedShot),label+" independently expected shot order");
         if(withEnergy) {
            check(equal(before.energyImpacts.sources[wa],after.energyImpacts.sources[wb]),label+" energy state/cursors");
            check(equal(frameXs(newResult,true),expectedEnergy),label+" independently expected energy order");
         }
         if(sharedPointIndex>=0) {
            check(a.fastPoint===a.frames[finalSharedPointIndex] && b.fastPoint===b.frames[finalSharedPointIndex],
               label+" shot cursor retains expected canonical history reference");
            if(withEnergy)check(ea.fastPoint===ea.wire.frames[finalSharedPointIndex] && eb.fastPoint===eb.wire.frames[finalSharedPointIndex],
               label+" energy cursor retains expected canonical history reference");
         }
         if(expectedOldVisits>=0)check(Counter.before==expectedOldVisits,label+" exact old history visits="+expectedOldVisits);
         if(expectedNewVisits>=0)check(Counter.after==expectedNewVisits,label+" exact new history visits="+expectedNewVisits);
      }
      private function trajectoryCases():void {
         captureCase("same stamp unchanged",shot([p(100)],100,p(100)),null,true,null,4,2);
         captureCase("revision without new point",shot([p(100,2)],100,p(100)),[2],true,[2],4,2);
         captureCase("mixed new/revision unsorted",shot([p(110,3),p(100,2),p(120,4)],100,p(100)),[2,3,4],true,[2,3,4],10,6);
         captureCase("first changed duplicate only",shot([p(100),p(100,2),p(100,4),p(110,3)],100,p(100)),[2,3],true,[2,3],12,8);
         captureCase("new point input order retained",shot([p(140,4),p(110,3),p(90,0),p(100,2)],100,p(100)),[2,4,3],true,[2,4,3],16,8);
         captureCase("empty history terminal",shot([],100,p(100),false,200),[],true,null,0,0);
         captureCase("no new point terminal",shot([p(100)],100,p(100),false,200),[],true,[1],4,2);
         captureCase("fresh ignores stale revision cursor",shot([p(50,0),p(100,2)],100,p(100),true),[0,2],false,null,2,2);
         captureCase("null fastAt keeps legacy zero revision",shot([p(0,2),p(10,3)],null,p(0)),[2,2,3],true,[2,2,3],6,4);
         captureCase("undefined fastAt keeps NaN revision",shot([p(0,2),p(10,3)],undefined,p(0)),[2,3],true,[2,3],8,4);
         captureCase("NaN cursor nonterminal suppresses both deltas",shot([p(0,2),p(10,3)],NaN,p(0)),null,true,null,8,4);
         captureCase("NaN cursor terminal preserves energy last-pose fallback",shot([p(0,2),p(10,3)],NaN,p(0),false,200),[],true,[3],8,4);
         var color:Object=p(100,2);color.c=[1,2,3,4,5,6,7,8];
         var prior:Object=clone(color);prior.c[7]=9;
         captureCase("nested color revision",shot([color],100,prior),[2],true,[2],4,2);
         var special:Object=p(100,2);special.a=NaN;special.sx=-1/Number.POSITIVE_INFINITY;
         captureCase("NaN and negative zero unchanged semantics",shot([special],100,clone(special)),[2],true,[2],4,2);
         // NaN pose fields make reference identity observable: the same object
         // is unchanged, while an independently cloned NaN pose above is revised.
         captureCase("shared NaN pose is unchanged",shot([special],100,special),null,true,null,4,2,0,0);
         captureCase("shared NaN pose advances only to new point",shot([special,p(110,3)],100,special),[3],true,[3],8,4,0,1);
         var missing:Object=shot([p(110,3)],100,p(100));missing.flight=null;
         captureCase("missing native clip does not consume cursor",missing,null,false,null,2,1);
         missing.impact={id:4,at:110,x:7,y:8};
         captureCase("impact without clip preserves independent event",missing,null,false,null,2,1);
         var maximum:Array=[];for(var i:int=0;i<64;i++)maximum.push(p(i,i));
         captureCase("64 retained points no updates",shot(maximum,63,p(63,63)),null,true,null,256,128);
         var original:Object=shot([p(100,2)],100,p(100));original.explosion={at:100,x:3,y:4};original.stopped=100;
         captureCase("revision plus stop explosion",original,[2],true,[2],4,2);
         // Exercise combinations without relaxing equality. A deterministic input
         // generator changes order/duplicate stamps; no game PRNG is touched.
         for(var seed:int=0;seed<80;seed++) {
            var list:Array=[],n:int=seed%9;
            for(i=0;i<n;i++)list.push(p([90,100,110,120][(seed*3+i*5)%4],(seed+i)%5));
            var expected:Array=[];for each(var point:Object in list)if(point.at>100)expected.push(point.x);
            for each(point in list)if(point.at==100 && point.x!=1){expected.unshift(point.x);break;}
            captureCase("ordered output fixture "+seed,shot(list,100,p(100)),expected.length?expected:null);
         }
      }
      private function world():Object {
         var loc:Object={spaceX:4,spaceY:2,space:[],firstObj:null};
         for(var x:int=0;x<4;x++){loc.space[x]=[];for(var y:int=0;y<2;y++)loc.space[x][y]={hp:10,phis:1};}
         loc.grafon={loc:loc,frontBmp:new BitmapData(160,80,true,0xff222222)};return loc;
      }
      private function fixtureCalls(after:Boolean):Object {
         var calls:Object=after?new CallsAfter():new CallsBefore();
         calls.loc=world();calls._wall=after?new WallAfter():new WallBefore();
         calls._terrain=new TerrainFixture();calls._wall.before(calls.loc);return calls;
      }
      private function contact(calls:Object,color:uint):void {
         calls.loc.grafon.frontBmp.setPixel32(20,20,color);calls.loc.space[0][0].hp--;
         var b:Bullet=new Bullet();b.loc=calls.loc;b.X=20;b.Y=20;b.tilehit=true;calls.loc.firstObj=b;
      }
      private function closeCalls(calls:Object):void {
         calls._wall.reset();calls.loc.grafon.frontBmp.dispose();
      }
      private function wallCases():void {
         var a:Object=fixtureCalls(false),b:Object=fixtureCalls(true);
         contact(a,0xff00aa44);contact(b,0xff00aa44);
         var ra:Object=a.hostPair(),rb:Object=b.hostPair();
         check(equal(ra,rb),"host continuous readTilePatch/readWallPaint complete wire payload");
         check(a._wall.observeCalls==2 && b._wall.observeCalls==1,"host pair observes exactly twice -> once");
         check(equal(a._wall.checkpoint(a.loc),b._wall.checkpoint(b.loc)),"host pair preserves persistent cell state");
         var va:Vector.<uint>=a.loc.grafon.frontBmp.getVector(a.loc.grafon.frontBmp.rect);
         var vb:Vector.<uint>=b.loc.grafon.frontBmp.getVector(b.loc.grafon.frontBmp.rect);
         var pixels:Boolean=va.length==vb.length;for(var i:int=0;i<va.length;i++)if(va[i]!=vb[i])pixels=false;
         check(pixels,"host pair preserves every fixture bitmap pixel");
         closeCalls(a);closeCalls(b);
         a=fixtureCalls(false);b=fixtureCalls(true);contact(a,0xffaa0044);contact(b,0xffaa0044);
         ra=a.scanTileReports();rb=b.scanTileReports();
         check(equal(ra,rb),"join scanTileReports complete queued report");
         check(a._wall.observeCalls==2 && b._wall.observeCalls==1,"join pair observes exactly twice -> once");
         var oa:int=a._wall.observeCalls,ob:int=b._wall.observeCalls;
         check(equal(a.scanTileReports(),b.scanTileReports()),"pending ACK does not duplicate report");
         check(a._wall.observeCalls-oa==2 && b._wall.observeCalls-ob==1,"pending ACK also keeps exact paired scan counts");
         a._wall.acknowledge(a.loc,ra.wall);b._wall.acknowledge(b.loc,rb.wall);
         check(equal(a.scanTileReports(),b.scanTileReports()),"ACK queue/protection behavior stays equal");
         // Unpaired/default calls still observe a NEW native contact.
         contact(a,0xff0044aa);contact(b,0xff0044aa);oa=a._wall.observeCalls;ob=b._wall.observeCalls;
         ra=a.readWallPaint();rb=b.readWallPaint();
         check(equal(ra,rb)&&ra!=null,"unknown readWallPaint caller still captures new contact");
         check(a._wall.observeCalls-oa==1 && b._wall.observeCalls-ob==1,"default readWallPaint still observes once");
         contact(a,0xff1144bb);contact(b,0xff1144bb);oa=a._wall.observeCalls;ob=b._wall.observeCalls;
         check(equal(a._wall.snapshot(a.loc),b._wall.snapshot(b.loc)),"unknown direct snapshot caller preserves payload");
         check(a._wall.observeCalls-oa==1 && b._wall.observeCalls-ob==1,"default snapshot still observes once");
         oa=a._wall.observeCalls;ob=b._wall.observeCalls;
         check(equal(a._wall.report(a.loc),b._wall.report(b.loc)),"unknown report caller preserves payload");
         check(a._wall.observeCalls-oa==1 && b._wall.observeCalls-ob==1,"default report still observes once");
         oa=a._wall.observeCalls;ob=b._wall.observeCalls;
         check(equal(a._wall.report(a.loc,false),b._wall.report(b.loc,false)),"existing explicit fast report is unchanged");
         check(a._wall.observeCalls==oa && b._wall.observeCalls==ob,"explicit fast report performs zero scans");
         closeCalls(a);closeCalls(b);
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try{trajectoryCases();wallCases();}catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:assertions,
            native_game:false,tcp_socket:false,performance_measured:false}));fs.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
