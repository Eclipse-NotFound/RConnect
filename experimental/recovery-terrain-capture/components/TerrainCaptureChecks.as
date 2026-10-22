package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import fe.loc.Tile;
   import fe.loc.Box;
   import rconnect.game.TerrainSync;
   import rconnect.game.ControlTerrainSync;
   import rconnect.game.NativeRoomState;

   /** Exact whole old/new TerrainSync, exact native Tile source. No game/TCP loaded. */
   public class TerrainCaptureChecks extends Sprite {
      private var assertions:Array=[],failed:int=0,work:Array=[],measurements:Array=[];
      private var bench:Object,started:int=getTimer(),frames:int=0;
      public function TerrainCaptureChecks() {
         work=[basic,visualFields,permissions,prediction,closing,settlement,checkpoint,dynamicFallback,largeSetup,
            function():void{measure(false,"A1");},function():void{measure(true,"B1");},
            function():void{measure(true,"B2");},function():void{measure(false,"A2");},largeVerify];
         addEventListener(Event.ENTER_FRAME,next);
      }
      private function next(e:Event):void {
         frames++;
         try {
            if(work.length){var task:Function=work.shift();task();}
            else finish();
         } catch(error:Error) {check(false,"uncaught "+error.getStackTrace());finish();}
      }
      private function check(ok:Boolean,label:String):void {assertions.push({passed:ok,label:label});if(!ok)failed++;}
      private function same(a:*,b:*,label:String):void {check(canon(a)==canon(b),label);}
      private static function canon(v:*):String {
         if(v===undefined)return "undefined";if(v===null)return "null";
         if(v is Number){if(isNaN(Number(v)))return "NaN";if(v===0 && 1/Number(v)<0)return "-0";return String(v);}
         if(v is Boolean || v is String)return JSON.stringify(v);
         var arr:Array=[],key:String;
         if(v is Array){for each(var item:* in v)arr.push(canon(item));return "["+arr.join(",")+"]";}
         var keys:Array=[];for(key in v)keys.push(key);keys.sort();
         for each(key in keys)arr.push(JSON.stringify(key)+":"+canon(v[key]));return "{"+arr.join(",")+"}";
      }
      private static function pair(width:int=2,height:int=2,getter:Boolean=false):Object {
         var p:Object={a:new ControlTerrainSync(),b:new TerrainSync(),ra:new TerrainCaptureRoom(width,height),rb:new TerrainCaptureRoom(width,height)};
         if(getter){p.ra.space[0][0]=new GetterTile();p.rb.space[0][0]=new GetterTile();}
         p.initialA=p.a.report(p.ra);p.initialB=p.b.report(p.rb);return p;
      }
      private static function t(p:Object,b:Boolean=false):Object {return (b?p.rb:p.ra).space[0][0];}
      private static function setBoth(p:Object,key:String,value:*):void {t(p)[key]=value;t(p,true)[key]=value;}
      private static function tileState(v:Object):Object {
         return {x:v.X,y:v.Y,p:v.phis,f:v.front,b:v.back,z:v.zad,zf:v.zForm,w:v.water,st:v.stair,
            h:v.hp,o:v.opac,v:v.vid,v2:v.vid2,d:v.diagon,sh:v.shelf};
      }
      private function report(p:Object,label:String):Object {
         var a:Object=p.a.report(p.ra),b:Object=p.b.report(p.rb);same(a,b,label);return a;
      }
      private static function ack(p:Object,req:Object,hp:int):void {
         var a:Object=tileState(t(p)),b:Object=tileState(t(p,true));a.h=hp;b.h=hp;
         p.a.acknowledge(p.ra,{epoch:req.epoch,seq:req.seq,tiles:[a]});
         p.b.acknowledge(p.rb,{epoch:req.epoch,seq:req.seq,tiles:[b]});
      }
      private function basic():void {
         var p:Object=pair();
         check(t(p) is Tile && getQualifiedClassName(t(p))=="fe.loc::Tile","complete native Tile class is used");
         check(p.initialA==null && p.initialB==null,"initial capture emits no damage");
         check(report(p,"unchanged old/new report")==null,"unchanged report is null");
         setBoth(p,"hp",75);var r:Object=report(p,"first HP loss request");
         check(r!=null && r.tiles.length==1 && r.tiles[0].damage===25 && r.tiles[0].destroy===false,"native HP loss independently equals 25");
         setBoth(p,"hp",65);check(report(p,"pending capture does not resubmit")==null,"one pending batch retained");
         p.a.acknowledge(p.ra,{epoch:r.epoch,seq:r.seq+1,tiles:[]});p.b.acknowledge(p.rb,{epoch:r.epoch,seq:r.seq+1,tiles:[]});
         check(report(p,"wrong sequence ACK ignored")==null,"wrong ACK leaves pending batch");
         ack(p,r,75);var r2:Object=report(p,"second loss survives original ACK");
         check(r2!=null && r2.tiles[0].damage===10 && t(p).hp==65 && t(p,true).hp==65,"pending second hit preserved without rolling back local HP");
         ack(p,r2,65);check(report(p,"final ACK empties queue")==null,"no duplicate damage after final ACK");
         ack(p,r2,90);check(t(p).hp==65 && t(p,true).hp==65,"duplicate ACK cannot change HP after pending cleared");
      }
      private function visualFields():void {
         var fields:Array=["front","back","zad","zForm","water","stair","opac","vid","vid2","diagon","shelf"];
         var wire:Array=["f","b","z","zf","w","st","o","v","v2","d","sh"];
         var values:Array=["front-new","back-new","rear-new",2,1,2,.375,3,4,-1,true];
         for(var i:int=0;i<fields.length;i++) {
            var p:Object=pair();setBoth(p,fields[i],values[i]);
            check(report(p,"visual-only "+fields[i]+" report equality")==null,"visual-only "+fields[i]+" creates no local damage");
            var a:Array=p.a.hostPatch(p.ra),b:Array=p.b.hostPatch(p.rb);same(a,b,"hostPatch retains complete "+fields[i]);
            check(a!=null && a.length==1 && a[0][wire[i]]===values[i],"hostPatch independently contains "+fields[i]);
         }
         p=pair();setBoth(p,"front","changed");setBoth(p,"opac",NaN);
         check(report(p,"native visual NaN remains no-damage")==null,"native opacity NaN does not create damage");
         same(p.a.hostPatch(p.ra),p.b.hostPatch(p.rb),"NaN visual field preserved in full host patch");
         same(p.a.checkpoint(p.ra),p.b.checkpoint(p.rb),"NaN fallback checkpoint remains complete");
         setBoth(p,"hp",70);var request:Object=report(p,"visual changes then native HP loss");
         check(request.tiles[0].damage===30,"visual-only observation never changes HP baseline");
      }
      private function permissions():void {
         var p:Object=pair();t(p).door=new Box();t(p,true).door=new Box();setBoth(p,"hp",90);
         check(report(p,"door HP change observation")==null,"door damage not queued by terrain");
         setBoth(p,"door",null);check(report(p,"door removed without HP loss")==null,"door removal alone not damage");
         setBoth(p,"hp",85);var r:Object=report(p,"hit after door removal");check(r.tiles[0].damage===5,"new eligible hit is five, not historical door damage");
         p=pair();setBoth(p,"indestruct",true);setBoth(p,"hp",90);
         check(report(p,"indestructible observation")==null,"indestructible HP change not queued");
         setBoth(p,"indestruct",false);check(report(p,"indestructible cleared")==null,"permission change alone not damage");
         setBoth(p,"hp",81);r=report(p,"hit after permission change");check(r.tiles[0].damage===9,"only eligible nine HP queued");
         p=pair();setBoth(p,"phis",0);r=report(p,"native removal without HP loss");
         check(r.tiles[0].destroy===true && r.tiles[0].damage===0,"removal-only destruction flag kept");
         ack(p,r,100);setBoth(p,"hp",70);check(report(p,"HP change of already empty cell")==null,"empty cell does not queue damage");
      }
      private function prediction():void {
         var p:Object=pair();setBoth(p,"hp",80);var r:Object=report(p,"prediction initial damage");
         var s:Object={x:0,y:0,h:50,f:"server-wall"};
         p.a.apply(p.ra,[s],true);p.b.apply(p.rb,[s],true);
         check(t(p).hp==80 && t(p,true).hp==80 && t(p).front=="wall","pending local hit protects against host patch");
         setBoth(p,"hp",75);p.a.apply(p.ra,[s],true);p.b.apply(p.rb,[s],true);
         check(t(p).hp==75 && t(p,true).hp==75,"apply captures second hit before checking prediction");
         ack(p,r,80);var r2:Object=report(p,"prediction second hit after ACK");check(r2.tiles[0].damage===5,"five damage survives crossed host patch and ACK");
         ack(p,r2,75);p.a.apply(p.ra,[s],true);p.b.apply(p.rb,[s],true);
         check(t(p).hp==50 && t(p,true).hp==50 && t(p).front=="server-wall","unpredicted host correction applies after ACK");
         check(report(p,"authoritative patch baseline")==null,"host correction is not reported as local damage");
         same(p.a.checkpoint(p.ra),p.b.checkpoint(p.rb),"prediction complete checkpoint equality");
      }
      private function closing():void {
         var p:Object=pair(130,1),i:int;
         for(i=0;i<130;i++){p.ra.space[i][0].hp=99;p.rb.space[i][0].hp=99;}
         var r:Object=report(p,"first 128-cell batch");check(r.tiles.length==128,"wire batch cap remains 128");
         for(i=0;i<130;i++){p.ra.space[i][0].hp=98;p.rb.space[i][0].hp=98;}
         var a:Array=p.a.finishReports(p.ra),b:Array=p.b.finishReports(p.rb);same(a,b,"finishReports exact ordered batches and fields");
         var total:Number=0,count:int=0;for each(var batch:Object in a)for each(var hit:Object in batch.tiles){total+=hit.damage;count++;}
         check(a.length==2 && a[0].tiles.length==128 && a[1].tiles.length==2,"finish drains every queued change in bounded batches");
         check(total===132 && count==130,"finish excludes sent 128 but retains two unsent and 130 new damage");
         check(report(p,"post-close empty report")==null,"closing leaves no duplicate report");
      }
      private function settlement():void {
         var p:Object=pair();var req:Object={epoch:4,seq:1,tiles:[{x:0,y:0,damage:25,destroy:false}]};
         var a:Object=p.a.settle(p.ra,"peer",req),b:Object=p.b.settle(p.rb,"peer",req);same(a,b,"settle complete receipt");
         check(t(p).hp==75 && t(p,true).hp==75,"settle uses native Tile.udar");
         same(p.ra.hitCalls,p.rb.hitCalls,"native hit call arguments and temporary active state");
         check(p.ra.hitCalls.length==1 && p.ra.hitCalls[0][5]===false && p.ra.active,"nonlethal hit temporarily suppresses independent random decal");
         check(p.a.settle(p.ra,"peer",req)===a && p.b.settle(p.rb,"peer",req)===b,"duplicate request returns same existing receipt identity");
         check(p.ra.hitCalls.length==1 && p.rb.hitCalls.length==1,"duplicate request does not hit twice");
         check(p.a.settle(p.ra,"peer",{epoch:4,seq:0,tiles:[]})==null && p.b.settle(p.rb,"peer",{epoch:4,seq:0,tiles:[]})==null,"older request rejected");
         req={epoch:4,seq:2,tiles:[{x:0,y:0,damage:80,destroy:false}]};
         same(p.a.settle(p.ra,"peer",req),p.b.settle(p.rb,"peer",req),"lethal native result receipt");
         check(t(p).phis==0 && t(p,true).phis==0 && p.ra.dieCalls.length==1 && p.rb.dieCalls.length==1,"native die called once per peer fixture");
         p=pair();var destroyed:Object=tileState(t(p));destroyed.p=0;destroyed.h=0;destroyed.f="";destroyed.o=0;
         p.a.apply(p.ra,[destroyed],true);p.b.apply(p.rb,[destroyed],true);
         check(p.ra.paintCalls.length==1 && p.rb.paintCalls.length==1 && !p.a.dirty && !p.b.dirty,"native destruction paint avoids whole-room redraw");
         same(NativeRoomState.scalars(t(p)),NativeRoomState.scalars(t(p,true)),"apply complete actual tile scalar equality");
         p=pair();var shaped:Object={x:0,y:0,zf:2,o:.625,b:"server-back"};
         p.a.apply(p.ra,[shaped],false);p.b.apply(p.rb,[shaped],false);
         check(t(p).phY1===20 && t(p,true).phY1===20 && t(p).opac===.625 && p.a.dirty && p.b.dirty,"setZForm collision side effect and final opacity both preserved");
      }
      private function checkpoint():void {
         var p:Object=pair(3,2),x:int,y:int;
         for(x=0;x<3;x++)for(y=0;y<2;y++) {
            for each(var loc:Object in [p.ra,p.rb]) {
               var v:Tile=loc.space[x][y];v.hp=80+x+y;v.front="f"+x;v.back="b"+y;v.t_ghost=17;v.fake=true;
               v.setZForm((x+y)%4);v.opac=.25;v.mat=7;v.grav=.8;
            }
         }
         var a:Object=p.a.checkpoint(p.ra),b:Object=p.b.checkpoint(p.rb);same(a,b,"complete native table checkpoint");
         check(a.nativeTileTable===2 && a.rows.length==6 && a.names.indexOf("t_ghost")>=0 && a.names.indexOf("grav")>=0,"checkpoint includes native fields outside network damage state");
         var original:Array=[];for(x=0;x<3;x++)for(y=0;y<2;y++)original.push(NativeRoomState.scalars(p.ra.space[x][y]));
         for(x=0;x<3;x++)for(y=0;y<2;y++){p.ra.space[x][y].hp=1;p.rb.space[x][y].hp=1;p.ra.space[x][y].front="bad";p.rb.space[x][y].front="bad";}
         p.a.restoreCheckpoint(p.ra,a);p.b.restoreCheckpoint(p.rb,b);
         var actualA:Array=[],actualB:Array=[];for(x=0;x<3;x++)for(y=0;y<2;y++){actualA.push(NativeRoomState.scalars(p.ra.space[x][y]));actualB.push(NativeRoomState.scalars(p.rb.space[x][y]));}
         same(actualA,actualB,"restore every native scalar old/new equality");same(actualA,original,"restore every native scalar matches independent saved state");
         check(report(p,"restored observation has no artificial damage")==null,"restored HP is new observation baseline");
         same(p.a.hostPatch(p.ra),p.b.hostPatch(p.rb),"restore retains full hostPatch base semantics");
         p.a.reset();p.b.reset();setBoth(p,"hp",90);check(report(p,"explicit reset")==null,"reset starts new local observation");
         var newA:TerrainCaptureRoom=new TerrainCaptureRoom(),newB:TerrainCaptureRoom=new TerrainCaptureRoom();
         check(p.a.report(newA)==null && p.b.report(newB)==null,"new room identity does not inherit old damage");
         newA.space[0][0].hp=90;newB.space[0][0].hp=90;
         same(p.a.report(newA),p.b.report(newB),"new room epoch and damage payload remain equal");
      }
      private function dynamicFallback():void {
         var p:Object=pair(1,1,true),a:GetterTile=t(p) as GetterTile,b:GetterTile=t(p,true) as GetterTile;
         same(a.calls,b.calls,"dynamic initial getter access order");a.calls=[];b.calls=[];
         a.currentHp=75;b.currentHp=75;var r:Object=report(p,"dynamic HP damage");
         same(a.calls,b.calls,"dynamic damage getter access order");check(r.tiles[0].damage===25 && a.calls.indexOf("front")>=0,"dynamic route still reads full fields and produces damage");
         p=pair(1,1,true);a=t(p) as GetterTile;b=t(p,true) as GetterTile;a.calls=[];b.calls=[];a.throwFront=true;b.throwFront=true;
         check(report(p,"throwing dynamic front")==null,"throwing non-HP field does not generate damage");same(a.calls,b.calls,"throwing getter order and repeat semantics");
         a.calls=[];b.calls=[];a.missingHp=true;b.missingHp=true;
         check(report(p,"missing dynamic HP")==null,"missing HP does not invent numeric loss");same(a.calls,b.calls,"missing HP getter sequence remains exact");
         a.missingHp=false;b.missingHp=false;a.currentHp=NaN;b.currentHp=NaN;a.calls=[];b.calls=[];
         check(report(p,"dynamic NaN HP first capture")==null,"NaN HP never invents damage");same(a.calls,b.calls,"NaN getter sequence remains exact");
         a.calls=[];b.calls=[];check(report(p,"dynamic repeated NaN HP")==null,"repeated NaN preserves old mismatch path");same(a.calls,b.calls,"repeated NaN does not bypass dynamic getter reads");
         a.currentHp=90;b.currentHp=90;check(report(p,"finite HP after NaN")==null,"unknown prior HP is not treated as damage");
         a.currentHp=80;b.currentHp=80;r=report(p,"finite HP second sample");check(r.tiles[0].damage===10,"dynamic finite baseline subsequently reports ten");
         p=pair(1,1,true);a=t(p) as GetterTile;b=t(p,true) as GetterTile;a.calls=[];b.calls=[];a.frontDamage=1;b.frontDamage=1;
         same(p.a.report(p.ra),p.b.report(p.rb),"side-effecting getter request remains exact");same(a.calls,b.calls,"side-effecting getter call order remains exact");
         check(a.currentHp===b.currentHp && a.currentHp<100,"dynamic getter side effects are not skipped");
      }
      private function largeSetup():void {
         bench=pair(240,125);
         check(bench.ra.space.length==240 && bench.ra.space[239].length==125 && bench.ra.space[239][124] is Tile,"benchmark has 30000 exact native Tile instances per side");
         check(bench.initialA==null && bench.initialB==null,"30000-cell entry baselines initialized outside timing");
         // Identical full native room state. Five read-only report scans per ABBA slot.
         check(bench.a.report(bench.ra)==null && bench.b.report(bench.rb)==null,"both benchmark classes execute one untimed same-workload warm scan");
      }
      private function measure(candidate:Boolean,label:String):void {
         var sync:Object=candidate?bench.b:bench.a,loc:Object=candidate?bench.rb:bench.ra;
         var count:int=0,start:int=getTimer();
         for(var i:int=0;i<5;i++)if(sync.report(loc)!=null)count++;
         var elapsed:int=getTimer()-start;
         measurements.push({order:label,candidate:candidate,ms:elapsed,iterations:5,cells:30000,unexpectedReports:count});
         check(count==0,"ABBA "+label+" unchanged grid produces no request");
      }
      private function largeVerify():void {
         var sameAll:Boolean=true;
         for(var x:int=0;x<240;x++)for(var y:int=0;y<125;y++) {
            var a:Tile=bench.ra.space[x][y],b:Tile=bench.rb.space[x][y];
            if(a.phis!=1 || b.phis!=1 || a.hp!=100 || b.hp!=100 || a.front!="wall" || b.front!="wall")sameAll=false;
         }
         check(sameAll,"all 30000 cells unchanged after measured report calls");
         check(bench.a.hostPatch(bench.ra)==null && bench.b.hostPatch(bench.rb)==null,"all 13-field host baselines stay unchanged after ABBA");
         bench.ra.space[239][124].hp=93;bench.rb.space[239][124].hp=93;
         var r:Object=report(bench,"last tile damage detected after ABBA");
         check(r.tiles.length==1 && r.tiles[0].x==239 && r.tiles[0].y==124 && r.tiles[0].damage===7,"whole grid remains observed, including final cell");
         bench=null;
      }
      private function finish():void {
         removeEventListener(Event.ENTER_FRAME,next);
         var result:Object={passed:failed==0,failed:failed,assertions:assertions,measurements:measurements,
            native_game:false,tcp_socket:false,performance_qualified:false,complete_old_new_classes:true,
            native_tile_source_exact:true,adjacent_room_side_effects_are_fixtures:true,elapsed:getTimer()-started,frames:frames};
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify(result));f.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
