package {
   import flash.desktop.NativeApplication;
   import flash.display.Loader;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.system.ApplicationDomain;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Native regeneration and a real encoded checkpoint, never a network qualification. */
   public class TerrainRoundTripTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private const SEED:uint=1380142925;
      private var mod:RConnectMod,phase:String="boot",started:int=getTimer(),phaseAt:int=getTimer();
      private var checks:int=0,failed:int=0,ended:Boolean=false,restores:int=0,reloads:int=0,stableFrames:int=0;
      private var landClass:Object,sceneClass:Object,codec:Object,oldSeed:Function,seedHook:Function,oldScene:*;
      private var sourceGame:Object,sourceLand:Object,sourceLoc:Object,sourceActor:Object,payload:Object;
      private var sourceInfo:Object,targetInfo:Object,constructs:Array=[],sourceBytes:ByteArray;
      private var configured:Boolean=false,loadObserved:Boolean=false,nextLogRead:int=0,renderFrames:int=0;
      private var observations:Array=[],cleanup:Object={seedRestored:false,sceneRestored:false,slotUnchanged:false,errors:[]};
      public function TerrainRoundTripTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("pfe-modsettings-rconnect-coop-host-")!=0)return;
         addEventListener(Event.ENTER_FRAME,tick);
      }
      private function check(ok:Boolean,label:String):void {
         checks++;Log.d("COOP "+(ok?"PASS ":"FAIL ")+"terrain-roundtrip "+label);
         if(!ok){failed++;throw new Error(label);}
      }
      private function note(kind:String,data:Object=null):void {
         if(observations.length>=32)throw new Error("Bounded observation capacity exceeded");
         observations.push({kind:kind,at:getTimer(),phase:phase,data:data});
      }
      private function bytes(file:File):ByteArray {
         var stream:FileStream=new FileStream(),out:ByteArray=new ByteArray();
         try{stream.open(file,FileMode.READ);stream.readBytes(out);}finally{stream.close();}return out;
      }
      private function write(name:String,text:String):void {
         var file:File=File.applicationStorageDirectory.resolvePath(name),stream:FileStream=new FileStream();
         if(file.exists)throw new Error("Evidence file already exists: "+name);
         try{stream.open(file,FileMode.WRITE);stream.writeUTFBytes(text);}finally{stream.close();}
      }
      private function slot():File {return File.applicationStorageDirectory.resolvePath("#SharedObjects/pfe.swf/PFEgame9.sol");}
      private function change(next:String):void {phase=next;phaseAt=getTimer();stableFrames=0;note("phase");}
      private function offline():Boolean {
         var s:Object=mod.session;
         return s.mode=="offline" && s.link==null && s.server==null && s.peers.length==0 && s.remotes.length==0;
      }
      private function stable(id:String=""):Boolean {
         var w:Object=mod.game.world;
         return w!=null && w.gg!=null && w.game!=null && w.land!=null && w.loc!=null
            && (id=="" || (String(w.game.curLandId)==id && String(w.land.act.id)==id))
            && int(w.comLoad)<0 && int(w.ng_wait)==0 && w.allStat==1 && !w.onPause
            && !mod.game.isTransitioning() && w.gg.ggControl && !w.pip.noAct
            && (!w.vblack.visible || w.vblack.alpha<=0);
      }
      private function configure():void {
         check(String(Object(MOD_CLASS)["VERSION"])=="0.2.24-roomreason1","exact diagnostic product");
         check(offline() && String(mod.config.getValue("autoRole"))=="" && String(mod.config.getValue("autoLoadSave"))=="9","native private slot-nine solo input");
         sourceBytes=bytes(slot());check(sourceBytes.length>26,"private slot-nine input exists");
         var nativeMain:MainFE=mod.game.main as MainFE;
         for(var key:Object in nativeMain.modEntryByLoader) {
            var loader:Loader=key as Loader;
            if(loader!=null && loader.contentLoaderInfo.applicationDomain.hasDefinition("ContinuousSceneMod")) {
               sceneClass=loader.contentLoaderInfo.applicationDomain.getDefinition("ContinuousSceneMod");break;
            }
         }
         check(sceneClass!=null,"loaded ContinuousScene class found through the real loader");
         oldScene=sceneClass.nativeEnabled;check(oldScene===true,"CS native preference was applied before launch");
         var preference:ByteArray=bytes(File.applicationStorageDirectory.resolvePath("ContinuousScene.preferences.json"));
         preference.position=0;check(JSON.parse(preference.readUTFBytes(preference.length)).nativeEnabled===true,"private CS preference file is true");
         var domain:ApplicationDomain=ApplicationDomain.currentDomain;
         check(domain.getDefinition("RConnectMod")===MOD_CLASS,"codec domain shares the actual production class");
         codec=domain.getDefinition("rconnect.net.RoomCodec");
         landClass=mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");oldSeed=landClass.rconnectSeedSource;
         check(oldSeed is Function,"native seed callback exists before installing the owned hook");
         seedHook=function(land:Object):uint {
            if((phase=="source-travel" || phase=="target-travel") && String(land.act.id)=="random_mane") {
               if(constructs.length>=2)throw new Error("Unexpected extra target Land construction");
               constructs.push({phase:phase,id:String(land.act.id),visited:Boolean(land.act.visited),stage:int(land.act.landStage),
                  conf:int(land.act.conf),difficulty:Number(land.act.dif),level:Number(land.landDifLevel),seed:SEED,scene:Boolean(sceneClass.nativeEnabled)});
               return SEED;
            }
            return oldSeed(land);
         };
         landClass.rconnectSeedSource=seedHook;configured=true;note("configured");
      }
      private function observeInitialLoad():Boolean {
         if(loadObserved)return true;
         if(getTimer()<nextLogRead)return false;nextLogRead=getTimer()+1000;
         var file:File=File.applicationStorageDirectory.resolvePath("RConnect.log");if(!file.exists)return false;
         var text:ByteArray=bytes(file);text.position=0;
         loadObserved=text.readUTFBytes(text.length).indexOf("RConnectGame: loadSaveTest -> slot 9")>=0;
         return loadObserved;
      }
      private function travel():void {
         mod.game.forceCloseOverlays();mod.game.world.pers.healAll();mod.game.world.game.gotoLand("rbl");
      }
      private function depart(which:String):void {
         change(which+"-travel");mod.game.forceCloseOverlays();mod.game.world.pers.healAll();
         mod.game.world.game.beginMission("random_mane");
      }
      private function info():Object {
         var w:Object=mod.game.world,details:Object=mod.game.readWorldInfo();
         var merged:Boolean=w.grafon.sceneNativeCall("state",[w.land])!=null;
         return {key:mod.game.roomKey(),width:int(w.loc.spaceX),height:int(w.loc.spaceY),seed:Number(details.layoutSeed),
            x:Number(w.gg.X),y:Number(w.gg.Y),units:w.loc.units.length,objects:w.loc.objs.length,merged:merged};
      }
      private function capture():void {
         var w:Object=mod.game.world;sourceGame=w.game;sourceLand=w.land;sourceLoc=w.loc;sourceActor=w.gg;sourceInfo=info();
         check(constructs.length==1 && sourceInfo.seed==SEED && sourceInfo.merged,"source uses one real seeded merged construction");
         check(sourceInfo.width>48 || sourceInfo.height>25,"source is a native large scene");
         var raw:Object=Object(mod.game).checkpoint(),packed:String=codec.pack(raw);payload=codec.unpack(packed);
         check(raw!==payload && payload.key==sourceInfo.key && payload.width==sourceInfo.width && payload.height==sourceInfo.height,"real codec produces a detached complete checkpoint");
         write("terrain-roundtrip-snapshot.txt",packed);
         note("checkpoint",{encodedCharacters:packed.length,units:payload.units.length,objects:payload.objs.length,
            tileSchema:payload.tiles is Array?"array":"rows",tileRows:payload.tiles is Array?payload.tiles.length:payload.tiles.rows.length});
         reloads++;check(reloads==1 && mod.game.loadSaveTest(9),"one native slot-nine reload is queued");change("reload");
      }
      private function restore():void {
         var w:Object=mod.game.world;targetInfo=info();
         check(w.game!==sourceGame && w.land!==sourceLand && w.loc!==sourceLoc && w.gg!==sourceActor,"native reload replaced Game player Land and Location identities");
         check(constructs.length==2,"target is a second real Land construction");
         var a:Object=constructs[0],b:Object=constructs[1];
         for each(var field:String in ["id","visited","stage","conf","difficulty","level","seed","scene"])
            check(a[field]===b[field],"constructor parameter agrees: "+field);
         check(targetInfo.key==sourceInfo.key && targetInfo.width==sourceInfo.width && targetInfo.height==sourceInfo.height
            && targetInfo.seed==sourceInfo.seed && targetInfo.merged && sceneClass.nativeEnabled===true,"target native key geometry seed and scene mode agree");
         check(offline(),"no network session was created");
         restores++;check(restores==1,"only one foreign non-retained restore");
         Object(mod.game).restoreCheckpoint(payload,false,true,false);
         note("restored",{arguments:[false,true,false],restoreCalls:restores});change("render");
         mod.stage.addEventListener(Event.RENDER,render,false,-1000000);mod.stage.invalidate();
      }
      private function render(e:Event):void {
         if(phase!="render")return;
         try {renderFrames++;if(renderFrames>=2){check(offline(),"still offline after native restore presentation");finish("");}}
         catch(error:*){finish(String(error));}
      }
      private function tick(e:Event):void {
         if(ended)return;
         try {
            mod=RConnectMod.instance;if(mod==null || mod.game==null || mod.game.world==null)return;
            var w:Object=mod.game.world;
            if(getTimer()-started>300000 || getTimer()-phaseAt>95000)throw new Error("Bounded phase timeout: "+phase);
            if(w.verror!=null && w.verror.visible)throw new Error("Native error dialog: "+String(w.verror.txt.text));
            if(w.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
            if(!configured){if(mod.game.gg==null)return;configure();}
            if(!offline())throw new Error("Unexpected network session");
            if(phase=="render"){mod.stage.invalidate();return;}
            if(phase=="boot") {
               if(!observeInitialLoad() || !stable())return;
               if(String(w.game.curLandId)=="rbl")change("source-base");else{change("source-base");travel();}
            } else if(phase=="source-base" || phase=="target-base") {
               if(!stable("rbl")){stableFrames=0;return;}
               if(++stableFrames>=2)depart(phase=="source-base"?"source":"target");
            } else if(phase=="source-travel" || phase=="target-travel") {
               if(!stable("random_mane")){stableFrames=0;return;}
               if(++stableFrames>=2){if(phase=="source-travel")capture();else restore();}
            } else if(phase=="reload") {
               if(w.game===sourceGame || w.gg===sourceActor || !stable())return;
               change("target-base");if(String(w.game.curLandId)!="rbl")travel();
            }
         } catch(error:*){finish(String(error));}
      }
      private function finish(problem:String):void {
         if(ended)return;ended=true;removeEventListener(Event.ENTER_FRAME,tick);
         if(mod!=null)mod.stage.removeEventListener(Event.RENDER,render);
         if(problem!=""){failed++;Log.d("COOP FAIL terrain-roundtrip "+problem);}
         try{if(landClass!=null){if(landClass.rconnectSeedSource!==seedHook)throw new Error("Seed hook ownership changed");landClass.rconnectSeedSource=oldSeed;}cleanup.seedRestored=true;}catch(a:*){cleanup.errors.push(String(a));}
         try{if(sceneClass!=null){if(sceneClass.nativeEnabled!==oldScene)throw new Error("Scene preference changed");}cleanup.sceneRestored=true;}catch(b:*){cleanup.errors.push(String(b));}
         try{var now:ByteArray=bytes(slot());check(sourceBytes!=null && now.length==sourceBytes.length,"private save length unchanged");
            for(var i:int=0;i<now.length;i++)if(now[i]!==sourceBytes[i])throw new Error("Private save bytes changed");cleanup.slotUnchanged=true;}catch(c:*){cleanup.errors.push(String(c));}
         var lastPhase:String=phase;phase="done";
         var result:Object={version:"0.2.24-roomreason1",passed:failed==0 && cleanup.errors.length==0,checks:checks,failed:failed,
            phase:phase,lastPhase:lastPhase,problem:problem,mechanismOnly:true,multiplayerQualified:false,performanceQualified:false,
            reloads:reloads,restores:restores,renderFrames:renderFrames,source:sourceInfo,target:targetInfo,
            constructors:constructs,observations:observations,cleanup:cleanup};
         try{write("terrain-roundtrip-result.json",JSON.stringify(result));}catch(d:*){Log.d("COOP FAIL terrain-roundtrip evidence write "+d);}
         Log.d("TERRAIN ROUNDTRIP RESULT "+JSON.stringify(result));Log.d("COOP EFFECTS DONE terrain-roundtrip host");
      }
   }
}
