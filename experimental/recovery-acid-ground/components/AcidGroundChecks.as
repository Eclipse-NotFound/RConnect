package {
   import flash.display.Sprite;
   import flash.desktop.NativeApplication;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.BurnVisualsBefore;
   import rconnect.game.BurnVisualsAfter;
   import rconnect.game.ProjectileExplosionVisualsBefore;
   import rconnect.game.ProjectileExplosionVisualsAfter;

   public class AcidGroundChecks extends Sprite {
      private var rows:Array=[],failed:int=0;
      public function AcidGroundChecks() {
         try {run();}catch(e:Error){check(false,"unexpected "+e.getStackTrace());}
         var result:Object={assertions:rows,failed:failed,passed:failed==0,native_game_test:false,
            native_Emitter:false,native_Part:false,functional_only:true,performance_qualified:false};
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(result));stream.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function check(ok:Boolean,label:String):void {rows.push({passed:ok,label:label});if(!ok)failed++;}
      private function equal(a:*,b:*):Boolean {return JSON.stringify(a)==JSON.stringify(b);}
      private function room():AcidRoomFixture {
         var r:AcidRoomFixture=new AcidRoomFixture();for(var x:int=0;x<12;x++)r.setTile(x,5);return r;
      }
      private function bullet(r:AcidRoomFixture,type:int=10,water:Number=0,custom:String=""):Object {
         return {loc:r,X:260,Y:180,explRadius:100,tipDamage:type,inWater:water,isExpl:true,weap:{visexpl:custom}};
      }
      private function containsPoint(points:Array,x:Number,y:Number):Boolean {
         for each(var p:Object in points)if(p.x==x && p.y==y)return true;return false;
      }
      private function definitions(events:Array):Object {
         return {loaderInfo:{applicationDomain:{getDefinition:function(name:String):Object {
            if(name=="fe.graph.Emitter")return {emit:function(id:String,r:Object,x:Number,y:Number,options:Object=null):void {
               events.push({id:id,x:x,y:y,options:options});
            }};
            if(name=="fe.Snd")return {ps:function(id:String,x:Number,y:Number):void {
               events.push({sound:id,x:x,y:y});
            }};
            throw new Error("Unexpected native boundary "+name);
         }}}};
      }
      private function play(cls:Object,r:AcidRoomFixture,s:Object):Array {
         var out:Array=[];cls.play(definitions(out),r,s);return out;
      }
      private function only(events:Array,id:String):Array {
         var out:Array=[];for each(var e:Object in events)if(e.id==id)out.push(e);return out;
      }
      private function ids(events:Array):Array {
         var out:Array=[];for each(var e:Object in events)out.push(e.id==null?"sound:"+e.sound:e.id);return out;
      }
      private function fireTrial(water:Number,custom:String,repeat:Boolean):void {
         var r:AcidRoomFixture=room(),b:Object=bullet(r,3,water,custom);
         var a:Object=ProjectileExplosionVisualsBefore.capture(b),z:Object=ProjectileExplosionVisualsAfter.capture(b);
         check(equal(a,z),"fire capture unchanged water="+water+" custom="+custom+" repeat="+repeat);
         a.repeat=z.repeat=repeat;
         check(equal(play(ProjectileExplosionVisualsBefore,r,a),play(ProjectileExplosionVisualsAfter,r,z)),
            "fire recipe and footprint unchanged water="+water+" custom="+custom+" repeat="+repeat);
      }
      private function run():void {
         var r:AcidRoomFixture=room(),b:Object=bullet(r);
         var old:Object=ProjectileExplosionVisualsBefore.capture(b),now:Object=ProjectileExplosionVisualsAfter.capture(b);
         var expected:Array=[{x:180,y:200},{x:220,y:200},{x:260,y:200},{x:300,y:200},{x:340,y:200}];
         check(old.ground.length==0 && now.ground.length==5,"acid gap reproduced on real old class and filled by new class"); // 1
         check(equal(now.ground,expected),"acid surface positions equal native flat-floor circle footprint"); // 2
         b.inWater=2;
         check(equal(ProjectileExplosionVisualsAfter.capture(b).ground,expected),"native acid is not excluded in water"); // 3
         check(ProjectileExplosionVisualsBefore.capture(b).ground.length==0,"old acid remains missing in water"); // 4
         var fire:Object=bullet(r,3),fireOld:Object=ProjectileExplosionVisualsBefore.capture(fire),fireNew:Object=ProjectileExplosionVisualsAfter.capture(fire);
         check(equal(fireOld,fireNew),"existing fire capture bytes unchanged"); // 5
         var offsets:Boolean=true;for(var i:int=0;i<expected.length;i++)offsets=offsets && fireNew.ground[i].y==expected[i].y-33;
         check(offsets,"acid uses phY1 while native fire keeps minus 33 offset"); // 6
         r.setTile(6,5,0,true);
         check(containsPoint(BurnVisualsAfter.captureGround(b),260,200),"acid accepts native shelf surfaces"); // 7
         r.setTile(6,4);r.setTile(6,5);
         check(!containsPoint(BurnVisualsAfter.captureGround(b),260,200),"covered flat cell is excluded"); // 8
         r.setTile(6,5,1,false,1,193);
         check(containsPoint(BurnVisualsAfter.captureGround(b),260,193),"slope zForm allows covered surface with actual phY1"); // 9
         var boundary:AcidRoomFixture=new AcidRoomFixture();boundary.setTile(5,5);
         var edge:Object=bullet(boundary);edge.X=180;edge.Y=220;edge.explRadius=40;
         check(BurnVisualsAfter.captureGround(edge).length==0,"strict native radius excludes exact-circle boundary"); // 10
         edge.X=220;edge.Y=60;edge.explRadius=30;boundary.setTile(5,1);
         check(BurnVisualsAfter.captureGround(edge).length==0,"native top row ty<=1 is excluded"); // 11
         b=bullet(room(),10,0,"customacid");
         check(BurnVisualsAfter.captureGround(b).length==0,"custom visexpl overrides acid footprint"); // 12
         b.weap.visexpl="sparkle";
         check(BurnVisualsAfter.captureGround(b).length==0,"sparkle override excludes acid footprint"); // 13
         b=bullet(room());var limits:Boolean=true;
         for each(var bad:Number in [0,-1,801,NaN,Infinity]){b.explRadius=bad;limits=limits && BurnVisualsAfter.captureGround(b).length==0;}
         check(limits,"existing radius guards remain for acid"); // 14
         b=bullet(room(),7);
         check(BurnVisualsAfter.captureGround(b).length==0,"gas gets no guessed liquid footprint"); // 15
         b.isExpl=false;
         check(ProjectileExplosionVisualsAfter.capture(b)==null,"capture still requires native isExpl flag"); // 16
         b=bullet(room());b.X=NaN;
         check(ProjectileExplosionVisualsAfter.capture(null)==null && ProjectileExplosionVisualsAfter.capture(b)==null
            && BurnVisualsAfter.captureGround(null).length==0,"null and invalid capture stay inert"); // 17

         // Use the original flat-floor packet with a receiver whose tiles differ.
         r=new AcidRoomFixture();var packet:String=JSON.stringify(now);
         var a:Array=play(ProjectileExplosionVisualsBefore,r,old),z:Array=play(ProjectileExplosionVisualsAfter,r,now);
         check(equal(ids(a),["acidexpl","acidkap","sound:acid_e"]) && only(z,"acid").length==5,
            "old plays only acid burst while new also emits five native acid Parts"); // 18
         var jitter:Boolean=true,spots:Array=only(z,"acid");
         for(i=0;i<spots.length;i++)jitter=jitter && Math.abs(spots[i].x-expected[i].x)<=2 && spots[i].y==expected[i].y;
         check(jitter,"acid footprint uses native horizontal jitter bounds and exact source surface Y"); // 19
         check(equal(ids(z),["acid","acid","acid","acid","acid","acidexpl","acidkap","sound:acid_e"]),
            "acid burst recipe and sound retained once after ground emission"); // 20
         check(only(a,"acidkap")[0].options.kol>=30 && only(a,"acidkap")[0].options.kol<=34
            && only(z,"acidkap")[0].options.kol>=30 && only(z,"acidkap")[0].options.kol<=34,"native acid drop count bounds retained"); // 21
         var wet:Object=JSON.parse(packet);wet.water=true;
         check(only(play(ProjectileExplosionVisualsAfter,r,wet),"acid").length==5,"water replay includes acid ground"); // 22
         var repeat:Object=JSON.parse(packet);repeat.repeat=true;
         check(play(ProjectileExplosionVisualsAfter,r,repeat).length==0,"later acid pulse does not re-emit first-explosion visuals"); // 23
         var custom:Object=JSON.parse(packet);custom.custom="customacid";
         check(equal(ids(play(ProjectileExplosionVisualsAfter,r,custom)),["customacid"]),"custom replay ignores supplied acid ground"); // 24
         custom.custom="sparkle";
         check(equal(ids(play(ProjectileExplosionVisualsAfter,r,custom)),["expl","sparkleexpl","iskr","sound:bale_e"]),"dry sparkle keeps own native recipe"); // 25
         custom.water=true;
         check(equal(ids(play(ProjectileExplosionVisualsAfter,r,custom)),["explw","bubble","sound:expl_uw"]),"wet sparkle keeps own native recipe"); // 26
         var legacy:Object=JSON.parse(packet);delete legacy.ground;
         check(equal(ids(play(ProjectileExplosionVisualsAfter,r,legacy)),ids(a)),"old packet without ground remains compatible"); // 27
         check(r.dangerCalls==0,"replay never invokes damage, terrain or AI methods"); // 28
         r.active=false;
         check(only(play(ProjectileExplosionVisualsAfter,r,now),"acid").length==0,"inactive room receives no acid ground"); // 29
         r.active=true;var none:Array=[];var main:Object=definitions(none);
         BurnVisualsAfter.playGround(null,r,expected,"acid");BurnVisualsAfter.playGround(main,null,expected,"acid");
         BurnVisualsAfter.playGround(main,r,null,"acid");ProjectileExplosionVisualsAfter.play(null,r,now);
         check(none.length==0,"missing playback inputs do nothing"); // 30
         var invalid:Array=[null,{x:NaN,y:200},{x:100,y:Infinity},{x:-1,y:0},{x:481,y:0},{x:0,y:481},{x:0,y:-1},{x:220,y:200}];
         BurnVisualsAfter.playGround(main,r,invalid,"acid");
         check(only(none,"acid").length==1,"invalid or outside received coordinates do not emit acid"); // 31
         none=[];main=definitions(none);var many:Array=[];for(i=0;i<300;i++)many.push({x:220,y:200});
         BurnVisualsAfter.playGround(main,r,many,"acid");
         check(none.length==256,"same 256-position replay cap bounds acid work"); // 32
         none=[];main=definitions(none);BurnVisualsAfter.playGround(main,r,expected,"gas");
         check(none.length==0,"liquid helper cannot be redirected to arbitrary emitter"); // 33
         check(JSON.stringify(now)==packet && equal(expected,[{x:180,y:200},{x:220,y:200},{x:260,y:200},{x:300,y:200},{x:340,y:200}]),
            "replays leave source packet and points unchanged"); // 34
         check(r.reads==0,"receiver never resamples delayed terrain for source liquid positions"); // 35
         var points:Array=BurnVisualsAfter.captureGround(bullet(room()));points[0].x=999;
         check(equal(BurnVisualsAfter.captureGround(bullet(room())),expected),"capture returns independent arrays without retained footprint state"); // 36
         none=[];main=definitions(none);BurnVisualsBefore.playGround(main,r,expected);var oldFire:Array=none;
         none=[];main=definitions(none);BurnVisualsAfter.playGround(main,r,expected);
         check(equal(oldFire,none),"three-argument playGround remains exact fire behavior"); // 37

         fireTrial(0,"",false);fireTrial(2,"",false);fireTrial(0,"",true);
         fireTrial(0,"customfire",false);fireTrial(0,"sparkle",false);fireTrial(2,"sparkle",true); // 38-49
      }
   }
}
