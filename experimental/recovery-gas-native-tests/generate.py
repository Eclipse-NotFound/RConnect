"""Text-only derivative of the previously exercised native acid G fixture."""
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'experimental/recovery-acid-native-tests/native/AcidGroundNativeTestDoc.as'
BASE_SHA='aa02ac1760bca30ce0967093cf1c5ecaaafa276db87a40ba03e8a22e41510643'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,text):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(text.encode('utf-8'))
def one(t,a,b):
    assert t.count(a)==1,a
    return t.replace(a,b,1)
def method(t,name,new):
    start=t.index('      private function '+name+'(')
    following=re.search(r'^      private function ',t[start+1:],re.M)
    assert following,name
    return t[:start]+new.rstrip()+'\n'+t[start+1+following.start():]

def source():
    assert sha(BASE)==BASE_SHA
    t=BASE.read_text(encoding='utf-8').replace('AcidGroundNativeTestDoc','GasPulseNativeTestDoc').replace('AcidGroundProbe','GasPulseProbe')
    t=t.replace('acid-ground-native','gas-pulse-native').replace('ACID ','GAS ')
    t=one(t,'''   /** Dedicated ground-acid suite: native G input -> actual PhisBullet/Part
    * -> production TCP -> actual receiving Part and stage pixels. Four trials:
    * dry host/join source, water host/join source. Not a flight/FPS benchmark. */''', '''   /** Four real G trials: one/double gas grenade, each direction.
    * Source oracle is actual Part objects, not configured explosion count.
    * Production wire/display are read-only observations; no clock injection. */''')
    t=one(t,'''         {id:"acidgr",quick:true,water:false,part:"acidexpl",ground:"acid",impact:true},
         {id:"acidgr",quick:true,water:true,part:"acidexpl",ground:"acid",impact:true}''', '''         {id:"gasgr",quick:true,water:false,part:"gas",shots:1},
         {id:"gasgr",quick:true,water:false,part:"gas",shots:2}''')
    t=one(t,'      private var originalInventory:Object;','''      private var originalInventory:Object;
      private var gasBullets:Array=[],lastShotFrame:int=-100,gasOverlap:Boolean=false,gasDone:Boolean=false;''')
    t=one(t,'         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);', '''         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,100000);
         mod.stage.addEventListener(Event.ENTER_FRAME,clockBefore,false,90001);
         mod.stage.addEventListener(Event.ENTER_FRAME,clockAfter,false,89999);''')
    t=one(t,'      private function before(e:Event):void {', '''      private function clockBefore(e:Event):void {if(ground!=null)ground.beginFrame(true);}
      private function clockAfter(e:Event):void {if(ground!=null)ground.beginFrame(false);}
      private function before(e:Event):void {''')
    t=one(t,'mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);', '''mod.stage.removeEventListener(Event.ENTER_FRAME,before);mod.stage.removeEventListener(Event.RENDER,render);
            mod.stage.removeEventListener(Event.ENTER_FRAME,clockBefore);mod.stage.removeEventListener(Event.ENTER_FRAME,clockAfter);''')
    t=one(t,'ground.allEnded && getTimer()-ground.lastBirth>=500','ground.allEnded && getTimer()-ground.lastActivity>=500')
    t=one(t,'         nativeBullet=null;nativeClass="";nativeBirth=nativeEnd=peerEnd=sourceShots=0;', '''         nativeBullet=null;nativeClass="";nativeBirth=nativeEnd=peerEnd=sourceShots=0;
         gasBullets=[];lastShotFrame=-100;gasOverlap=false;gasDone=false;''')
    t=one(t,'if(phase=="run" && source && !issued && gun!=null && gun.b==null)',
          'if(phase=="run" && source && sourceShots<int(spec.shots) && gun!=null && gameFrame>lastShotFrame+1)')
    t=one(t,'         var p:Object=e.data;if(p.type!="gas-pulse-native-test" || phase=="done")return;', '''         var p:Object=e.data;
         if(phase=="run" && ground!=null)ground.observePacket(p);
         if(p.type!="gas-pulse-native-test" || phase=="done")return;''')
    t=method(t,'render',r'''      private function render(e:Event):void {
         if(phase!="run")return;
         try {
            var now:int=getTimer();observedFrames++;
            if(source && gun!=null && gun.b!=null && !nativeShots[gun.b]) {
               var bullet:Object=gun.b;
               nativeShots[bullet]=true;sourceShots++;issued=true;lastShotFrame=gameFrame;
               if(gasBullets.length>0 && gasBullets[0].bullet.in_chain)gasOverlap=true;
               gasBullets.push({bullet:bullet,born:now,bornWall:new Date().time,exploded:0,end:0});
               if(nativeBullet==null){nativeBullet=bullet;nativeBirth=now;nativeClass=getQualifiedClassName(bullet.vis);}
               check(getQualifiedClassName(bullet)=="fe.weapon::PhisBullet" && Number(bullet.explRadius)>0
                  && int(bullet.tipDamage)==7,"native G creates actual toxic PhisBullet shot="+sourceShots);
               send("native-born",{cls:nativeClass});
            }
            if(source) {
               var ended:Boolean=sourceShots==int(spec.shots);
               for each(var record:Object in gasBullets) {
                  bullet=record.bullet;
                  if(bullet.isExpl && record.exploded==0)record.exploded=now;
                  if(!bullet.in_chain && record.end==0)record.end=now;
                  ended=ended && record.end>0;
               }
               if(ended && !gasDone){gasDone=true;nativeEnd=now;send("native-end");}
            } else {
               var guard:int=0;
               for(var o:Object=mod.game.loc.firstObj;o!=null && guard++<20000;o=o.nobj) {
                  var cname:String=getQualifiedClassName(o);
                  if((cname=="fe.weapon::Bullet" || cname=="fe.weapon::PhisBullet") && o.weap!=null
                     && String(o.weap.id)==spec.id && !unexpected[o]){unexpected[o]=true;unexpectedBullets++;}
               }
               if(guard>=20000)throw new Error("Native object chain exceeds fixture bound");
            }
            ground.scan(gameFrame);groundCount=ground.count;
         } catch(err:Error){fail(err.getStackTrace());}
      }''')
    t=method(t,'complete',r'''      private function complete():void {
         // Stop action sampling before any bitmap readback or PNG encoding.
         setPhase("result");var proof:Object=ground.result(),shots:Array=[];
         for each(var record:Object in gasBullets)shots.push({born:record.born,bornWall:record.bornWall,
            exploded:record.exploded,end:record.end});
         localResult={source:source,id:spec.id,requested:int(spec.shots),shots:sourceShots,shotRows:shots,
            overlap:gasOverlap,unexpected:unexpectedBullets,inputReleased:inputReleased,proof:proof};
         Log.d("GAS PULSE RESULT "+JSON.stringify({round:round,role:host?"host":"join",value:localResult}));
         check(!proof.overflow && proof.visualRows.length>0,"bounded actual gas visuals exist");
         check(proof.pixel!=null && proof.pixel.pixels>0,"real gas contributes final-stage pixels; encoding follows sampling");
         check(proof.allEnded,"every observed gas visual reaches its real end");
         if(source) {
            check(sourceShots==int(spec.shots) && inputReleased>0,"requested actual G throws and input release");
            check(proof.nativeRows.length>0 && proof.visualRows.length==proof.nativeRows.length,
               "source actual Part identities correspond to artwork, without expected twelve assumption");
            check(int(spec.shots)==1 || gasOverlap,"double trial has two simultaneously live native projectiles");
         } else {
            check(unexpectedBullets==0 && proof.nativeRows.length==0,"receiver creates no native gas Part or damaging projectile");
            check(proof.wireRows.length>0 && proof.wireRows.length==proof.visualRows.length,
               "actual unique production gas records each appear once in display tree");
            var terminal:Boolean=proof.wireRows.length>0;
            for each(var row:Object in proof.wireRows)terminal=terminal && row.end>0 && row.strictEnd===true;
            check(terminal,"every actually received gas record has source ending and strict native lifetime");
         }
         if(host)advance();else send("result",{value:localResult});
      }''')
    t=method(t,'advance',r'''      private function advance():void {
         if(!host || localResult==null || peerResult==null)return;
         var origin:Object=localResult.source?localResult:peerResult,remote:Object=localResult.source?peerResult:localResult;
         check(origin.proof.nativeRows.length>0 && origin.proof.nativeRows.length==remote.proof.wireRows.length
            && origin.proof.nativeRows.length==remote.proof.visualRows.length,
            "actual source Part count equals distinct wire and remote visual counts; source="+origin.proof.nativeRows.length
            +" wire="+remote.proof.wireRows.length+" visual="+remote.proof.visualRows.length);
         nextRound();
      }''')
    return t

def main():
    t=source();put(HERE/'native/GasPulseNativeTestDoc.as',t)
    put(HERE/'driver.patch',''.join(difflib.unified_diff(BASE.read_text().splitlines(True),t.splitlines(True),
        fromfile='acid-native/AcidGroundNativeTestDoc.as',tofile='gas-native/GasPulseNativeTestDoc.as')))
    plan=dict(entry='GasPulseNativeTestDoc',baseline=str(BASE.relative_to(ROOT)),baseline_sha256=BASE_SHA,
        files={p.name:sha(p) for p in sorted((HERE/'native').glob('*.as'))},rounds=4,seconds=360,
        compiled=False,air_started=False,performance_qualified=False,generator_sha256=sha(Path(__file__)))
    put(HERE/'native-plan.json',json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(dict(written=True,files=list(plan['files']),JVM_started=False,AIR_started=False)))
if __name__=='__main__':main()
