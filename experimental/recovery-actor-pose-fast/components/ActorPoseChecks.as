package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import fe.unit.Unit;
   import fixture.Clock;
   import fixture.Trace;
   import fixture.TestWeapon;
   import fixture.MotionReadProbe;
   import rconnect.game.PoseBefore;
   import rconnect.game.PoseAfter;
   import rconnect.game.RemoteMotion;

   /** Full production classes, renamed, controlled clock and read-only hooks.
    * Native weapon/resource execution stays an explicit external boundary. */
   public final class ActorPoseChecks extends Sprite {
      private var rows:Array=[],failed:int=0;
      public function ActorPoseChecks() {addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         rows.push({passed:ok,label:label});if(!ok)failed++;trace((ok?"PASS ":"FAIL ")+label);
      }
      private function same(a:*,b:*):Boolean {return JSON.stringify(a)===JSON.stringify(b);}
      private function near(a:Number,b:Number):Boolean {return Math.abs(a-b)<1e-10;}
      private function gunSnapshot(id:String="gun",slot:int=0,stream:int=7):Object {
         return {id:id,slot:slot,stream:stream,variant:0,main:slot==0,shots:0,
            ox:10,oy:20,rot:.5,prep:30,reload:15,cadence:50,aura:{color:123},melee:{pose:"swing"}};
      }
      private function sourcePose(id:String="gun",slot:int=0,stream:int=7):Object {
         return {id:id,slot:slot,stream:stream,variant:0,ox:40,oy:-30,rot:-2};
      }
      private function setup(after:Boolean):Object {
         Clock.now=1000;Trace.reset();
         var p:Object=after?new PoseAfter():new PoseBefore();
         var u:Unit=new Unit(),layer:Sprite=new Sprite(),w:TestWeapon=new TestWeapon(layer);
         u.id="unit";u.X=100;u.Y=200;u.sost=1;u.vis=new Sprite();layer.addChild(u.vis);
         u.vis.alpha=.5;u.vis.visible=true;w.owner=u;
         u.childObjs=[w];u.currentWeapon=w;u.loc={active:true};
         var clock:RemoteMotion=new RemoteMotion();clock.currentSample={weapons:[sourcePose()]};
         var s:Object=gunSnapshot(),snapshot:Object={sost:1,anim:"walk",pose:null,body:null,burning:false,weapons:[s]};
         p.apply(u,snapshot,{},clock,false,true);
         var rec:Object=p.fixtureState(u),g:Object=rec.guns["0"];
         g.motion={x:2,y:4,r:0,at:900,duration:200};
         Trace.reset();
         return {p:p,u:u,w:w,rec:rec,g:g,clock:clock,s:s,snapshot:snapshot,layer:layer};
      }
      private function output(c:Object):Object {
         var names:Array=[],guns:Array=[];
         for(var name:String in c.rec.guns)names.push(name);names.sort();
         for each(name in names) {
            var g:Object=c.rec.guns[name],w:Object=g.weapon;
            guns.push({slot:name,id:w.id,x:w.X,y:w.Y,r:w.rot,prep:w.t_prep,reload:w.t_reload,
               shoot:w.t_shoot,queue:g.queue,next:g.next,flash:g.flash,shots:g.shots,gunReload:g.reload,
               visible:w.vis.visible,alpha:w.vis.alpha});
         }
         return {guns:guns,trace:Trace.rows.concat(),clockCalls:Clock.calls};
      }
      private function events(o:Object,name:String):int {
         var n:int=0;for each(var row:Array in o.trace)if(row[0]===name)n++;return n;
      }
      private function errorFree(o:Object):Boolean {return events(o,"ERROR")==0;}
      private function poseCase(after:Boolean,kind:String):Object {
         var c:Object=setup(after),pose:Object=sourcePose(),sample:Object={weapons:[pose]},paused:Boolean=false;
         if(kind=="null-clock")c.rec.clock=null;
         else if(kind=="null-sample")sample=null;
         else if(kind=="missing-weapons")sample={};
         else if(kind=="nonarray-weapons")sample={weapons:{}};
         else if(kind=="empty-weapons")sample={weapons:[]};
         else if(kind=="wrong-slot")pose.slot=1;
         else if(kind=="wrong-id")pose.id="other";
         else if(kind=="wrong-variant")pose.variant=1;
         else if(kind=="wrong-stream")pose.stream=8;
         else if(kind=="later-match")sample.weapons=[sourcePose("other"),pose];
         else if(kind=="duplicate-first")sample.weapons=[pose,sourcePose()];
         else if(kind=="positive-wrap") {sample=null;c.g.motion.r=3;c.s.rot=-3;}
         else if(kind=="negative-wrap") {sample=null;c.g.motion.r=-3;c.s.rot=3;}
         else if(kind=="duration-zero") {sample=null;c.g.motion.duration=0;}
         else if(kind=="elapsed-clamped") {sample=null;c.g.motion.at=0;}
         else if(kind=="paused-match")paused=true;
         else if(kind=="paused-fallback") {paused=true;sample=null;}
         else if(kind=="other-gun-first")sample.weapons=[sourcePose("gun",1),pose];
         else if(kind=="unused-fallback-NaN")c.g.motion.r=NaN;
         else if(kind=="coercive-identity") {pose.slot="0";pose.variant="0";pose.stream="7";}
         if(kind=="duplicate-first")sample.weapons[1].ox=999;
         c.clock.currentSample=sample;c.p.tick(c.u,paused);return output(c);
      }
      private function poseCases():void {
         var cases:Array=[
            ["match",140,170,-2], ["null-clock",106,212,.25], ["null-sample",106,212,.25],
            ["missing-weapons",106,212,.25], ["nonarray-weapons",106,212,.25], ["empty-weapons",106,212,.25],
            ["wrong-slot",106,212,.25], ["wrong-id",106,212,.25], ["wrong-variant",106,212,.25],
            ["wrong-stream",106,212,.25], ["later-match",140,170,-2], ["duplicate-first",140,170,-2],
            ["positive-wrap",106,212,Math.PI], ["negative-wrap",106,212,-Math.PI],
            ["duration-zero",110,220,.5], ["elapsed-clamped",110,220,.5], ["paused-match",140,170,-2],
            ["paused-fallback",106,212,.25], ["other-gun-first",140,170,-2],
            ["unused-fallback-NaN",140,170,-2], ["coercive-identity",140,170,-2]];
         for each(var row:Array in cases) {
            var a:Object=poseCase(false,row[0]),b:Object=poseCase(true,row[0]),g:Object=b.guns[0];
            check(errorFree(a)&&errorFree(b)&&same(a,b),row[0]+": complete state, time reads and boundary order equal");
            check(near(g.x,row[1])&&near(g.y,row[2])&&near(g.r,row[3])
               &&g.prep==(row[0]=="elapsed-clamped"?0:27)&&g.reload==(row[0]=="elapsed-clamped"?0:12)&&events(b,"animate")==1
               && events(b,"aura")==1&&events(b,"melee")==1,row[0]+": expected final pose and one full presentation");
         }
      }
      private function controlCase(after:Boolean,kind:String):Object {
         var c:Object=setup(after),s:Object=c.s;
         if(kind=="defer")c.p.apply(c.u,c.snapshot,{},c.clock,false,true);
         else if(kind=="immediate")c.p.apply(c.u,c.snapshot,{},c.clock,false,false);
         else if(kind=="burst") {
            s.shots=3;c.p.apply(c.u,c.snapshot,{},c.clock,false,true);
            for(var i:int=0;i<3;i++){Clock.now=1000+i*50;c.p.tick(c.u,false);}
         } else if(kind=="paused") {
            c.g.queue=3;c.g.flash=3;c.p.tick(c.u,true);Clock.now=1100;c.p.tick(c.u,true);
         } else if(kind=="cooldown") {
            c.g.queue=1;c.g.next=1100;c.p.tick(c.u,false);Clock.now=1100;c.p.tick(c.u,false);
         } else if(kind=="reload") {
            c.g.reload=0;s.reload=10;c.p.apply(c.u,c.snapshot,{},c.clock,false,true);c.p.tick(c.u,false);
            s.reload=9;c.p.apply(c.u,c.snapshot,{},c.clock,false,true);c.p.tick(c.u,false);
         } else if(kind=="reattach") {
            c.w.vis.parent.removeChild(c.w.vis);c.u.vis.visible=false;c.u.vis.alpha=.25;c.p.tick(c.u,false);
         } else if(kind=="turret") {
            c.rec.body={kind:"turret"};c.g.queue=1;c.p.tick(c.u,false);
         } else if(kind=="two-guns") {
            var second:TestWeapon=new TestWeapon(c.layer);second.id="other";second.owner=c.u;c.u.childObjs.push(second);
            c.snapshot.weapons.push(gunSnapshot("other",1,8));
            c.clock.currentSample.weapons=[sourcePose("other",1,8),sourcePose()];
            c.p.apply(c.u,c.snapshot,{},c.clock,false,true);c.p.tick(c.u,false);
         } else if(kind=="replacement") {
            var fresh:TestWeapon=new TestWeapon(c.layer);fresh.id="new";fresh.owner=c.u;
            c.u.childObjs=[fresh];c.u.currentWeapon=fresh;c.snapshot.weapons=[gunSnapshot("new",0,99)];
            // The old clock identity must not control the newly selected weapon.
            c.p.apply(c.u,c.snapshot,{},c.clock,false,true);c.p.tick(c.u,false);
            c.clock.currentSample.weapons=[sourcePose("new",0,99)];c.p.tick(c.u,false);
         }
         return output(c);
      }
      private function controlCases():void {
         var kinds:Array=["defer","immediate","burst","paused","cooldown","reload","reattach","turret","two-guns","replacement"];
         for each(var kind:String in kinds) {
            var a:Object=controlCase(false,kind),b:Object=controlCase(true,kind),g:Object=b.guns[0],valid:Boolean=true;
            if(kind=="defer")valid=events(b,"animate")==0&&events(b,"play")==0;
            if(kind=="immediate")valid=events(b,"animate")==1;
            if(kind=="burst")valid=events(b,"play")==2&&events(b,"animate")==3&&g.queue==0&&g.flash==2;
            if(kind=="paused")valid=events(b,"play")==0&&events(b,"animate")==2&&g.queue==3&&g.flash==3;
            if(kind=="cooldown")valid=events(b,"play")==1&&events(b,"animate")==2&&g.queue==0;
            if(kind=="reload")valid=events(b,"play")==1&&events(b,"animate")==2&&g.reload==9;
            if(kind=="reattach")valid=events(b,"add")==1&&events(b,"animate")==1&&!g.visible&&g.alpha==.25;
            if(kind=="turret")valid=events(b,"turret-fire")==1&&events(b,"turret-present")==1&&events(b,"animate")==1;
            if(kind=="two-guns")valid=b.guns.length==2&&events(b,"animate")==2&&b.guns[1].x==140;
            if(kind=="replacement")valid=events(b,"remove")==1&&events(b,"forget-aura")==1&&events(b,"forget-melee")==1
               &&events(b,"animate")==2&&g.id=="new"&&g.x==140&&g.y==170&&g.r==-2;
            check(valid&&errorFree(a)&&errorFree(b)&&same(a,b),kind+": actual apply/tick sequence and independent semantic expectation");
         }
      }
      private function reads(after:Boolean,matched:Boolean):Object {
         var c:Object=setup(after),m:MotionReadProbe=new MotionReadProbe();c.g.motion=m;
         if(!matched)c.clock.currentSample=null;
         c.p.tick(c.u,false);return {out:output(c),reads:m.reads};
      }
      private function readCases():void {
         var a:Object=reads(false,true),b:Object=reads(true,true);
         check(a.reads==2&&b.reads==0&&same(a.out,b.out),"matching source avoids both fallback angle reads; final observations equal");
         a=reads(false,false);b=reads(true,false);
         check(a.reads==2&&b.reads==2&&same(a.out,b.out),"missing source retains both fallback angle reads and exact result");
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try {poseCases();controlCases();readCases();}
         catch(error:Error) {check(false,"uncaught component "+error.getStackTrace());}
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,
            native_game_loaded:false,performance_qualified:false,clock_boundary_controlled:true,
            real_clip_resource_playback_tested:false}));f.close();
         NativeApplication.nativeApplication.exit(failed==0?0:1);
      }
   }
}
