package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObject;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.ColorTransform;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import fe.graph.Part;
   import fe.unit.Unit;
   import fe.unit.Mine;
   import fe.weapon.Bullet;
   import rconnect.game.*;
   import rconnect.net.BinaryMessageCodec;

   /** Identical old/new suite. Actual full RC classes and binary codec;
    * source Part objects and artwork are external boundary fixtures, not AIR game. */
   public class GasPulseChecks extends Sprite {
      private var rows:Array=[],failed:int=0,label:String="",wireSizes:Array=[];
      public function GasPulseChecks(){addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,text:String):void {
         rows.push({passed:ok,label:label+": "+text});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label+": "+text);
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         for each(var f:Function in [actualParts,framesAndEnd,noExpectedCount,firstSound,legacyReplay,
            pausedRoom,foreignClock,boundsAndReset,packetBudget,ordinaryFlare])try{f();}catch(error:Error){check(false,"uncaught "+error.getStackTrace());}
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,native_game:false,
            realCapture:true,realReceiver:true,realCodec:true,wireBytes:wireSizes,
            sourcePartsAndArtworkAreFixtures:true,performance_qualified:false}));
         fs.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function scene():Object {
         var s:Object={p:new UnitPresentation(),v:new ProjectileVisuals(),clock:new GasClock(),layer:new Sprite(),emits:[],sounds:[]};
         addChild(s.layer);s.loc={firstObj:null,units:[],active:true,getAbsTile:function(x:Number,y:Number):Object{return {phis:0};}};
         var u:Unit=new Unit();u.loc=s.loc;u.X=0;u.Y=0;u.fraction=0;u.sost=1;u.childObjs=[];
         u.currentWeapon=null;u.throwWeapon=null;u.magicWeapon=null;s.u=u;s.loc.units=[u];
         var emit:Object={arr:{}};
         emit.emit=function(name:String,loc:Object,x:Number,y:Number,opts:Object=null):void{s.emits.push(name);};
         emit.arr.gas={cast:function(loc:Object,x:Number,y:Number,opts:Object=null):Object {
            s.emits.push("gas");var p:Part=part(s,false);p.X=x;p.Y=y;return p;
         }};
         emit.arr.pinkgas={cast:function(loc:Object,x:Number,y:Number,opts:Object=null):Object {
            s.emits.push("pinkgas");return part(s,true);
         }};
         s.main={loaderInfo:{applicationDomain:{getDefinition:function(n:String):Object {
            if(n=="fe.World")return {w:{grafon:{visObjs:[s.layer,s.layer,s.layer,s.layer,s.layer]}}};
            if(n=="fe.graph.Emitter")return emit;
            if(n=="fe.Snd")return {ps:function(name:String,x:Number,y:Number):void{s.sounds.push(name);}};
            if(n=="visualGas")return visualGas;if(n=="visualPinkGas")return visualPinkGas;
            if(n=="flPlasma")return flPlasma;
            return Sprite;
         }}}};return s;
      }
      private function part(s:Object,pink:Boolean=false):Part {
         var p:Part=new Part();p.loc=s.loc;p.nobj=s.loc.firstObj;s.loc.firstObj=p;
         p.X=100;p.Y=80;p.in_chain=true;p.sloy=3;p.liv=60;p.mliv=60;
         p.vis=pink?new visualPinkGas():new visualGas();p.vis.x=p.X;p.vis.y=p.Y;p.vis.alpha=.2;
         addChild(p.vis);return p;
      }
      private function sample(s:Object,time:int):Array {s.p.observe(s.loc,time);return s.p.capture(s.u,true);}
      private function gas(guns:Array):Array {for each(var g:Object in guns)if(g.id=="@room-gas")return g.impacts as Array;return [];}
      private function fields(events:Array):Object {return events.length?events[0]:{frames:[],end:0};}
      private function point(events:Array):Object {var r:Object=fields(events);return r.frames.length?r.frames[r.frames.length-1]:{};}
      private function wire(guns:Array):Array {
         var b:ByteArray=BinaryMessageCodec.pack({type:"worldstate",enemyMotion:[{effects:guns}]});
         if(b==null)throw new Error("binary encode failed");
         wireSizes.push(b.length);
         var m:Object=BinaryMessageCodec.unpack(b);if(m==null)throw new Error("binary decode failed");
         return m.enemyMotion[0].effects as Array;
      }
      private function receive(s:Object,guns:Array):void{s.v.receive(s.u,wire(guns),s.main,true,s.clock);}
      private function tick(s:Object,time:Number):void{s.clock.time=time;s.v.tick(s.loc,getTimer());}
      private function clean(s:Object):void{s.v.reset();s.p.reset();while(numChildren)removeChildAt(0);}
      private function actualParts():void {
         label="actual Part identities, no shooter inference";var s:Object=scene();
         var a:Part=part(s),b:Part=part(s,true);b.vis.x=180;b.vis.rotation=73;b.vis.scaleX=.8;
         b.vis.transform.colorTransform=new ColorTransform(.5,.6,.7,.8,1,2,3,4);
         var packets:Array=sample(s,1000),events:Array=gas(packets);
         check(events.length==2,"two actual gas Parts become two events without any weapon or bullet");
         check(events.length==2 && events[0].id!=events[1].id,"overlapping effects keep distinct native object identities");
         check(packets.length==1 && packets[0].roomParts===true && packets[0].effectsOnly===true && packets[0].main===false,
            "transport explicitly identifies a room-only cosmetic stream");
         var p:Object=point(events);
         check(events.length==2 && fields(events).cls=="visualPinkGas" && fields(events).strictEnd===true,
            "real native pink resource and strict native ending are retained");
         check(p.at==1000 && p.x==180 && p.r==73 && Math.abs(Number(p.sx)-.8)<.001,
            "first sample preserves actual Part time, position, rotation and scale");
         check(p.c is Array && Math.abs(Number(p.c[0])-.5)<.01 && p.c[4]==1,"actual native color transform is serialized");
         receive(s,packets);tick(s,999);check(s.layer.numChildren==0,"received future clouds wait for source display time");
         tick(s,1000);check(s.layer.numChildren==2,"both gas resources produce display objects");
         receive(s,packets);tick(s,1000);check(s.layer.numChildren==2,"duplicate full transport does not duplicate a cloud");
         check(s.loc.firstObj===b && b.nobj===a && s.emits.length==0,"replay creates no native Part, emitter or damaging world object");
         check(gas(sample(s,1000)).length==0,"same stamp and unchanged pose do not resend samples");
         clean(s);
      }
      private function framesAndEnd():void {
         label="source frames and real removal";var s:Object=scene(),p:Part=part(s),first:Array=sample(s,1000);
         receive(s,first);tick(s,1000);p.vis.x=127;p.vis.alpha=.7;p.liv=53;
         var update:Array=sample(s,1233),events:Array=gas(update);
         check(events.length==1 && fields(events).id==fields(gas(first)).id,"later pulse pose updates the same Part identity");
         check(fields(events).frames.length==1 && point(events).at==1233,"next snapshot sends only new native samples");
         receive(s,update);tick(s,1233);
         check(s.layer.numChildren==1 && s.layer.getChildAt(0).x==127,"receiver reaches observed source position");
         check(s.layer.numChildren==1 && Math.abs(s.layer.getChildAt(0).alpha-.7)<.01,"receiver uses observed fade rather than fresh emitter fade");
         p.in_chain=false;s.loc.firstObj=null;var end:Array=sample(s,1666);
         check(fields(gas(end)).end==1666,"native disappearance, not configured life count, produces ending");
         receive(s,end);tick(s,1665);check(s.layer.numChildren==1,"known ending is not applied before the source cursor");
         tick(s,1666);check(s.layer.numChildren==0,"gas ends exactly at observed end without flash recovery extension");
         receive(s,first);tick(s,1700);check(s.layer.numChildren==0,"old duplicate cannot resurrect ended cloud");
         check(gas(sample(s,2700)).length==0,"ended source records retire after existing retention horizon");clean(s);
      }
      private function noExpectedCount():void {
         label="actual count and source filtering";var s:Object=scene();
         check(gas(sample(s,1000)).length==0,"empty chain never manufactures configured pulses");
         var fake:Object={constructor:Object,loc:s.loc,in_chain:true,vis:new visualGas(),nobj:null};s.loc.firstObj=fake;
         check(gas(sample(s,1033)).length==0,"matching-looking non-Part object is rejected");
         var p:Part=part(s);p.vis=new Sprite();check(gas(sample(s,1066)).length==0,"unrelated native Part resource is rejected");
         p=part(s);p.in_chain=false;check(gas(sample(s,1099)).length==0,"already removed native Part is rejected");
         p=part(s);p.loc={};check(gas(sample(s,1132)).length==0,"Part from another room is rejected");
         s.loc.firstObj=null;for(var i:int=0;i<12;i++)part(s,i%2==0);
         check(gas(sample(s,1165)).length==12,"source group containing twelve actual objects is preserved");
         check(gas(sample(s,1165)).length==0,"attempted thirteenth emission with no Part causes no event");
         // Native Location.remObj marks in_chain=false before a removed Part
         // can disappear from the chain. Merely unlinking the head leaves all
         // twelve fixture objects falsely alive to retained-object observers.
         for(var removed:Object=s.loc.firstObj;removed!=null;removed=removed.nobj)removed.in_chain=false;
         s.loc.firstObj=null;sample(s,1198);p=part(s);var later:Array=gas(sample(s,1500));
         check(later.length==1 && point(later).at==1500,"irregular later actual pulse keeps observed time without filling gaps");clean(s);
      }
      private function firstSound():void {
         label="first detonation and gas Part separation";var s:Object=scene();
         var w:Object={id:"gasgr",owner:s.u,loc:s.loc,variant:0,kol_shoot:1,hold:5,rashod:1,b:null,visexpl:""};
         var b:Bullet=new Bullet();b.loc=s.loc;b.weap=w;b.owner=s.u;b.in_chain=true;b.nobj=null;b.vis=null;
         b.isExpl=true;b.babah=true;b.explRadius=180;b.tipDamage=7;b.X=100;b.Y=80;b.inWater=0;w.b=b;
         s.u.currentWeapon=w;s.u.childObjs=[w];s.loc.firstObj=b;
         var before:Object={x:b.X,y:b.Y,type:b.tipDamage,chain:b.in_chain,hold:w.hold};
         var events:Array=sample(s,1000);receive(s,events);tick(s,1000);
         check(s.emits.length==0,"confirmed detonation without an emitted Part does not fabricate gas");
         check(s.sounds.length==1 && s.sounds[0]=="gas_e","original first detonation sound remains once-only");
         var p:Part=part(s);var withPart:Array=sample(s,1060);receive(s,withPart);tick(s,1060);
         check(s.layer.numChildren==1 && s.emits.length==0,"actual later first Part appears exactly once");
         receive(s,events);tick(s,1100);check(s.sounds.length==1,"repeated shot packets do not replay the sound");
         check(b.X==before.x && b.Y==before.y && b.tipDamage==before.type && b.in_chain==before.chain && w.hold==before.hold,
            "collection and replay do not modify bullet, damage type or ammunition");clean(s);
      }
      private function legacyReplay():void {
         label="legacy recipe remains one-way";var s:Object=scene();
         ProjectileExplosionVisuals.play(s.main,s.loc,{x:100,y:80,type:7,repeat:false});
         check(s.emits.length==1 && s.emits[0]=="gas" && s.sounds.length==1,"legacy packet still uses original native gas recipe");
         check(gas(sample(s,1000)).length==0,"legacy received native Part is excluded from outgoing room stream");
         ProjectileExplosionVisuals.play(s.main,s.loc,{x:100,y:80,type:19,repeat:true,nativeGasParts:true});
         check(s.emits.length==1 && s.sounds.length==1,"new pink pulse recipe cannot duplicate Part or first sound");
         var mine:Mine=new Mine();mine.tipDamage=7;mine.lootIsDrop=false;
         var death:Object=DeathVisuals.capture(mine);
         check(death!=null && death.nativeGasParts===true,"native gas death recipe identifies separately observed Parts");
         DeathVisuals.play(s.main,s.loc,death,100,80);
         check(s.emits.length==1 && s.sounds.length==2,"new gas death keeps sound without duplicating gas Part");
         DeathVisuals.play(s.main,s.loc,{type:19,water:false},100,80);
         check(s.emits.length==2 && s.sounds.length==3,"legacy gas death still emits original cosmetic recipe");
         check(gas(sample(s,1066)).length==0,"all legacy gas death and projectile Parts are excluded from recapture");clean(s);
      }
      private function pausedRoom():void {
         label="pause and room lifecycle";var s:Object=scene(),p:Part=part(s),start:Array=sample(s,1000);
         receive(s,start);tick(s,1000);p.in_chain=false;s.loc.firstObj=null;receive(s,sample(s,1500));
         s.v.setPaused(true);s.v.tick(s.loc,getTimer()+30000);
         check(s.layer.numChildren==1,"shared pause retains the current source pose and terminal boundary");
         s.v.setPaused(false);tick(s,1500);check(s.layer.numChildren==0,"resume reaches already received native end once");
         p=part(s);receive(s,sample(s,1800));tick(s,1800);
         check(s.layer.numChildren==1,"new post-pause Part remains independent of prior ended identity");
         var oldRoom:Object=s.loc;s.loc={firstObj:null,units:[],active:true};s.u.loc=s.loc;s.loc.units=[s.u];
         s.v.tick(s.loc,getTimer());check(s.layer.numChildren==0,"viewer changing room clears old-room clouds");
         check(gas(sample(s,1900)).length==0,"source changing room does not send retained previous-room gas");
         s.loc=oldRoom;s.u.loc=oldRoom;var back:Array=sample(s,2000);
         check(gas(back).length==1 && back[0].stream!=start[0].stream,"returning room gets separate transport identity for still actual Part");clean(s);
      }
      private function foreignClock():void {
         label="finite source clock detachment";var s:Object=scene(),p:Part=part(s);receive(s,sample(s,1000));tick(s,1000);
         p.in_chain=false;s.loc.firstObj=null;receive(s,sample(s,2000));
         var now:int=getTimer();s.v.forget(s.u);s.clock.time=99999;s.v.tick(s.loc,now+10);
         check(s.layer.numChildren==1,"forget detaches stopped owner clock without jumping to received end");
         s.v.tick(s.loc,now+1500);check(s.layer.numChildren==0,"detached confirmed ending continues on existing fallback clock");clean(s);
      }
      private function boundsAndReset():void {
         label="bounded histories and reset";var s:Object=scene(),p:Part=part(s);
         for(var i:int=0;i<80;i++){p.vis.x=i;s.p.observe(s.loc,1000+i*33);}
         var out:Array=sample(s,1000+79*33),events:Array=gas(out);
         check(events.length==1 && fields(events).frames.length==64,"one live observed Part has bounded native frame history");
         check(point(events).x==79,"history bound preserves newest actual native pose");
         receive(s,out);tick(s,1000+79*33);check(s.layer.numChildren==1,"bounded late history remains renderable");
         s.v.reset();check(s.layer.numChildren==0,"reset removes all gas display children");
         s.p.reset();check(gas(sample(s,4000)).length==1,"collector reset can observe an actual remaining Part with fresh identity");clean(s);
      }
      private function packetBudget():void {
         label="bounded incremental wire budget";var s:Object=scene(),parts:Array=[];
         for(var i:int=0;i<12;i++)parts.push(part(s,i%2==0));
         for(var frame:int=0;frame<20;frame++) {
            for each(var p:Part in parts){p.vis.x=123.456+frame;p.vis.rotation=17.25+frame;p.vis.alpha=.333;}
            s.p.observe(s.loc,1000+frame*33);
         }
         for each(p in parts)p.in_chain=false;s.loc.firstObj=null;s.p.observe(s.loc,2000);
         var points:int=0,maxPoints:int=0,total:int=0,ids:Object={},ends:Object={},maxBytes:int=0,partial:Boolean=false;
         for(var batch:int=0;batch<5;batch++) {
            var packet:Array=s.p.capture(s.u,true),events:Array=gas(packet);points=0;
            for each(var record:Object in events) {
               points+=record.frames.length;ids[String(record.id)]=true;
               if(record.frames.length<20 && int(record.end)==0)partial=true;
               if(int(record.end)==2000)ends[String(record.id)]=true;
            }
            total+=points;maxPoints=Math.max(maxPoints,points);
            var decoded:Array=wire(packet);maxBytes=Math.max(maxBytes,int(wireSizes[wireSizes.length-1]));
         }
         var count:int=0,ended:int=0;for(var id:String in ids)count++;for(id in ends)ended++;
         check(maxPoints==64,"gas packet has an explicit 64-point cap across all Parts");
         check(count==12 && total==240,"budget retains every observed point across subsequent deltas");
         check(partial,"partial history does not prematurely publish the native end");
         check(ended==12,"every deferred Part terminal eventually follows its complete prefix");
         check(maxBytes<24576,"actual AMF packet stays below 24 KiB for bounded gas history");
         check(gas(s.p.capture(s.u,true)).length==0,"fully drained gas history is not resent in later player packets");clean(s);
      }
      private function ordinaryFlare():void {
         label="unrelated ordinary energy impact unchanged";var s:Object=scene();
         var w:Object={id:"plasma",owner:s.u,loc:s.loc,variant:0,kol_shoot:1,hold:5,rashod:1,b:null,flare:"plasma"};
         var b:Bullet=new Bullet();b.loc=s.loc;b.weap=w;b.in_chain=true;b.nobj=null;b.vis=null;
         b.isExpl=false;b.babah=true;b.tilehit=true;b.parr=[];b.explRadius=0;b.flare="plasma";b.X=100;b.Y=80;w.b=b;
         s.u.currentWeapon=w;s.u.childObjs=[w];s.loc.firstObj=b;
         var p:Part=part(s);p.vis=new flPlasma();p.vis.x=100;p.vis.y=80;addChild(p.vis);
         var packet:Array=sample(s,1000);
         check(gas(packet).length==0,"plasma Part never enters room gas stream");
         check(packet.length==1 && packet[0].impacts.length==1 && packet[0].impacts[0].cls=="flPlasma",
            "actual plasma contact still enters its original weapon impact stream");
         // ENTER_FRAME and RENDER may call the receiver at the same display
         // timestamp. The original short-flash policy counts only a new time
         // as another displayed frame; advancing source time alone is not one.
         var renderedAt:int=getTimer();receive(s,packet);s.clock.time=1000;s.v.tick(s.loc,renderedAt);
         check(s.layer.numChildren==1,"ordinary energy impact rendering remains available");
         p.in_chain=false;s.loc.firstObj=b;receive(s,sample(s,1100));s.clock.time=1100;s.v.tick(s.loc,renderedAt);
         var sameFrame:Boolean=s.layer.numChildren==1;s.v.tick(s.loc,renderedAt+33);
         check(sameFrame && s.layer.numChildren==0,"unchanged short-flash ending preserves same-frame pose and retires on next display frame");clean(s);
      }
   }
}
import rconnect.game.RemoteMotion;
class GasClock extends RemoteMotion {
   public var time:Number=1000;
   override public function get sourceTime():Number{return time;}
}
