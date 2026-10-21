"""Make a dedicated four-round acid fixture from the existing real-input driver."""
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'tests/ExplosiveVisualTestDoc.as'
ENTRY='AcidGroundNativeTestDoc'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def one(text,old,new):
    assert text.count(old)==1,old[:100]
    return text.replace(old,new,1)


def body(text,name):
    clean=re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"',lambda m:' '*len(m[0]),text)
    start=clean.index('      private function '+name+'(')
    brace=clean.index('{',start);depth=1;end=brace+1
    while depth:depth+=(clean[end]=='{')-(clean[end]=='}');end+=1
    return text[start:end]


def main():
    old=BASE.read_text(encoding='utf-8-sig');text=old
    text=text.replace('ExplosiveVisualTestDoc',ENTRY).replace('explosive-visual','acid-ground-native')
    start=text.index('      private static const CASES:Array=');end=text.index('      private var cases:',start)
    text=text[:start]+'''      private static const CASES:Array=[
         {id:"acidgr",quick:true,water:false,part:"acidexpl",ground:"acid",impact:true},
         {id:"acidgr",quick:true,water:true,part:"acidexpl",ground:"acid",impact:true}
      ];
'''+text[end:]
    text=one(text,'      private var diagnosticAt:int=0,observedFrames:int=0;',
        '      private var diagnosticAt:int=0,observedFrames:int=0;\n      private var ground:AcidGroundProbe,gameFrame:int=0,inputReleased:int=0,issued:Boolean=false;\n'
        '      private var bootActor:Object,bootRoom:Object,bootFrames:int=0,bootWatching:Boolean=false,bootLogged:Boolean=false;\n'
        '      private var originalInventory:Object;')
    text=one(text,'         if(app.indexOf("rconnect-coop-")<0)return;host=app.indexOf("-host-")>=0;',
        '         if(!/^pfe-modsettings-rconnect-coop-(host|join)-[a-f0-9]{10}$/.test(app))return;host=app.indexOf("-host-")>=0;')
    text=one(text,'''         var wc:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         standby=wc.create(g,"lmg",0);standby.setPers(g,g.pers);standby.addVisual();
         if(oldGun!=null)oldGun.remVisual();
         g.currentWeapon=standby;g.childObjs=[standby,g.punchWeapon];g.throwWeapon=null;''',
        '''         originalInventory={weapons:g.invent.weapons,fav:g.invent.fav,favIds:g.invent.favIds};
         g.invent.weapons=copyArray(g.invent.weapons);g.invent.fav=copyArray(g.invent.fav);g.invent.favIds=copyArray(g.invent.favIds);
         g.childObjs=g.childObjs.concat();g.changeWeapon("not",true);
         g.invent.weapons.lmg=null;standby=g.invent.addWeapon("lmg");g.changeWeapon("lmg",true);
         g.throwWeapon=null;
         check(g.currentWeapon===standby && g.invent.weapons.lmg===standby && g.childObjs.indexOf(standby)>=0,
            "standby uses native owned inventory and equipment path");''')
    text=one(text,'''            var g:Object=mod.game.gg,wc:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
            gun=wc.create(g,spec.id,0);gun.setPers(g,g.pers);gun.lvl=0;gun.perslvl=0;''',
        '''            var g:Object=mod.game.gg;
            g.invent.weapons[spec.id]=null;gun=g.invent.addWeapon(spec.id);
            gun.setPers(g,g.pers);gun.lvl=0;gun.perslvl=0;''')
    text=one(text,'''               g.throwWeapon=gun;gun.loc=mod.game.loc;gun.setNull();
               check(g.currentWeapon!==gun && g.childObjs.indexOf(gun)<0,"quick throw uses native throwWeapon outside currentWeapon/childObjs id="+spec.id);''',
        '''               g.invent.favItem(spec.id,29);
               check(g.invent.weapons[spec.id]===gun && g.throwWeapon===gun && g.invent.fav[29]==spec.id
                  && g.currentWeapon!==gun && g.childObjs.indexOf(gun)<0,
                  "quick throw uses native owned inventory/favourite outside currentWeapon/childObjs id="+spec.id);''')
    text=one(text,'         if(gun!=null){gun.remVisual();gun=null;}',
        '         if(gun!=null){if(g.throwWeapon===gun)g.invent.favItem(gun.id,29);gun.remVisual();gun=null;}')
    text=one(text,'         g.currentWeapon=standby;g.childObjs=[standby,g.punchWeapon];g.throwWeapon=null;g.magicWeapon=null;',
        '         if(g.currentWeapon!==standby)g.changeWeapon("lmg",true);g.throwWeapon=null;g.magicWeapon=null;')
    text=one(text,'''               if(standby!=null)standby.remVisual();
               g.currentWeapon=oldGun;g.childObjs=oldChildren;g.throwWeapon=oldThrow;g.magicWeapon=oldMagic;g.pers.grenader=oldGrenader;''',
        '''               g.changeWeapon("not",true);
               g.invent.weapons=originalInventory.weapons;g.invent.fav=originalInventory.fav;g.invent.favIds=originalInventory.favIds;
               g.childObjs=oldChildren;if(oldGun!=null)g.changeWeapon(oldGun.id,true);
               g.throwWeapon=oldThrow;g.magicWeapon=oldMagic;g.pers.grenader=oldGrenader;
               check(g.currentWeapon===oldGun && g.invent.weapons===originalInventory.weapons
                  && g.invent.fav===originalInventory.fav && g.invent.favIds===originalInventory.favIds,
                  "original owned inventory and equipped weapon restored");''')
    text=one(text,'      private function tick(e:TimerEvent):void {','''      private function bootState():Object {
         var g:Object=mod.game.gg,w:Object=mod.game.world;
         return {role:host?"host":"join",at:getTimer(),timerTicks:t.currentCount,frames:bootFrames,
            ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,transition:mod.game.isTransitioning(),
            hp:Number(g.hp),sost:int(g.sost),dead:g.pers.dead,animOff:g.animOff,control:g.ggControl,
            disabled:g.disabled,work:g.work,t_work:g.t_work,t_die:w.t_die,t_exit:w.t_exit,comLoad:w.comLoad,
            clickReq:w.clickReq,onPause:w.onPause,allStat:w.allStat,roomActive:mod.game.loc!=null?mod.game.loc.active:null,
            blackVisible:w.vblack.visible,blackAlpha:w.vblack.alpha,
            label:g.vis!=null && g.vis.osn!=null?g.vis.osn.currentLabel:null};
      }
      private function bootWorldReady():Boolean {
         var g:Object=mod.game.gg,w:Object=mod.game.world,loc:Object=mod.game.loc;
         return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning()
            && loc!=null && loc.active && g.loc===loc && int(g.sost)==1 && Number(g.hp)>0 && !g.pers.dead
            && !w.onPause && int(w.allStat)==1 && int(w.clickReq)==0
            && (!w.vblack.visible || Number(w.vblack.alpha)<=0) && g.vis!=null && g.vis.stage!=null;
      }
      private function bootFrame(e:Event):void {
         if(phase!="boot" || bootActor==null)return;
         var g:Object=mod.game.gg;
         if(g===bootActor && mod.game.loc===bootRoom && bootWorldReady()
            && !g.animOff && g.ggControl && !g.disabled && g.work!="die" && g.work!="res"
            && g.vis.osn.currentLabel!="die")bootFrames++;
         else bootFrames=0;
      }
      private function prepareBootActor():void {
         if(!bootWorldReady())return;
         var g:Object=mod.game.gg;
         if(bootActor!==g || bootRoom!==mod.game.loc) {
            // A living character can retain the prologue's stopped artwork.
            // Clear it through native methods only after room/loading gates.
            // Actual deaths are rejected above; never heal or set sost/t_die.
            Log.d("ACID BOOT PREPARE "+JSON.stringify(bootState()));
            bootActor=g;bootRoom=mod.game.loc;bootFrames=0;bootLogged=false;
            g.anim();g.controlOn();g.invulner=true;
         }
         if(bootFrames>=2 && !bootLogged) {
            bootLogged=true;Log.d("ACID BOOT READY "+JSON.stringify(bootState()));
         }
      }
      private function tick(e:TimerEvent):void {''')
    text=one(text,'         var w:Object=mod.game.world;mod.game.gg.invulner=true;',
        '''         var w:Object=mod.game.world;mod.game.gg.invulner=true;
         if(!bootWatching){bootWatching=true;mod.stage.addEventListener(Event.ENTER_FRAME,bootFrame,false,-2147483647);}''')
    text=one(text,'         if(getTimer()-at>(phase=="boot"?70000:26000)){fail("timeout "+phase);return;}',
        '''         if(getTimer()-at>(phase=="boot"?180000:26000)) {
            if(phase=="boot")Log.d("ACID BOOT TIMEOUT "+JSON.stringify(bootState()));
            fail("timeout "+phase);return;
         }
         if(phase=="boot")prepareBootActor();''')
    text=one(text,'if(phase=="boot" && !host && t.currentCount>130 && getTimer()-readyAt>500 && (!w.vblack.visible || w.vblack.alpha<=0))',
        'if(phase=="boot" && !host && bootFrames>=2 && bootWorldReady() && getTimer()-readyAt>500)')
    text=one(text,'if(host && p.stage=="ready" && phase=="boot")',
        'if(host && p.stage=="ready" && phase=="boot" && bootFrames>=2 && bootWorldReady())')
    text=one(text,'         if(mod!=null) {\n            mod.stage.removeEventListener(Event.ENTER_FRAME,before);',
        '         if(mod!=null) {\n            mod.stage.removeEventListener(Event.ENTER_FRAME,bootFrame);\n            mod.stage.removeEventListener(Event.ENTER_FRAME,before);')
    text=one(text,'         restoreWeapon();round=n;spec=cases[int(n/2)];source=host==(n%2==0);',
        '         if(ground!=null)ground.dispose();\n         restoreWeapon();round=n;spec=cases[int(n/2)];source=host==(n%2==0);\n         gameFrame=inputReleased=0;issued=false;')
    text=one(text,'         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr[spec.part];',
        '         ground=new AcidGroundProbe(mod,source,round);\n         var emitter:Object=mod.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter").arr[spec.part];')
    text=one(text,'         if(!saved || phase=="done")return;','         if(!saved || phase=="done")return;gameFrame++;')
    text=one(text,'if(phase=="run" && source && gun!=null && gun.b==null)',
        'if(phase=="run" && source && !issued && gun!=null && gun.b==null)')
    text=one(text,'         mod.stage.invalidate();','         if(source && issued && !ctr.keyGrenad && inputReleased==0)inputReleased=gameFrame;\n         mod.stage.invalidate();')
    text=one(text,'                  nativeBullet=gun.b;nativeBirth=now;nativeClass=getQualifiedClassName(nativeBullet.vis);',
        '                  nativeBullet=gun.b;issued=true;nativeBirth=now;nativeClass=getQualifiedClassName(nativeBullet.vis);')
    text=one(text,'               if(source && nativeEnd>0 && getTimer()-nativeEnd>=2100)complete();\n               else if(!source && peerEnd>0 && getTimer()-peerEnd>=2100)complete();',
        '''               var ended:int=source?nativeEnd:peerEnd;
               if(ended>0 && ((ground.allEnded && getTimer()-ground.lastBirth>=500)
                  || (ground.count==0 && getTimer()-ended>=6000)))complete();''')
    # Keep the native explosive/Part observations, but no early bitmap readout.
    text=one(text,'                  if(explosionPixels==0 && pixels(o.vis as DisplayObject)>0)explosionPixels++;','')
    start=text.index('               if(cname=="fe.graph::Part" && spec.ground!=null) {')
    end=text.index('               if(!source && (cname=="fe.weapon::Bullet"',start)
    text=text[:start]+text[end:]
    old_render=body(text,'render');new_render=one(old_render,'         } catch(err:Error){fail(err.getStackTrace());}',
        '            ground.scan(gameFrame);groundCount=ground.count;\n         } catch(err:Error){fail(err.getStackTrace());}')
    text=one(text,old_render,new_render)
    text=one(text,'            if(pixels(v)==0)return false;flightPixelSeen[v]=true;','            flightPixelSeen[v]=true;')
    # Remove now-unused readback method rather than retain an accidental hot path.
    text=one(text,body(text,'pixels'),'')
    text=one(text,body(text,'complete'),'''      private function complete():void {
         var endpoint:Object=source?nativeExplosion:peerExplosion,proof:Object=ground.result();
         localResult={source:source,id:spec.id,water:spec.water,shots:sourceShots,flight:flightFrames,
            unexpected:unexpectedBullets,explosion:endpoint,inputReleased:inputReleased,proof:proof};
         Log.d("ACID GROUND RESULT "+JSON.stringify({round:round,role:host?"host":"join",value:localResult}));
         check(endpoint!=null && Boolean(endpoint.water)==Boolean(spec.water),"actual native acid detonation uses requested dry/water branch");
         check(flightFrames>0,"real projectile display existed before native terminal");
         check(proof.rows.length>0 && !proof.overflow,"actual native acid Part objects exist; acidexpl alone is insufficient");
         check(proof.pixel!=null && proof.pixel.pixels>0,"acid Part contributes final-stage pixels; readback deferred until expiry");
         check(proof.allEnded,"every observed acid Part expires through native lifetime");
         var properties:Boolean=proof.rows.length>0,life:Boolean=properties,animated:Boolean=false,faded:Boolean=false;
         for each(var row:Object in proof.rows) {
            properties=properties && row.partClass=="fe.graph::Part" && row.visualClass=="visualAcid" && row.stable;
            life=life && row.mliv>=100 && row.mliv<=129 && row.firstLiv>0 && row.removedFrame>row.bornFrame && row.detached && row.finalLiv<=0;
            animated=animated || row.animated;faded=faded || row.alphaMax>=.5 && row.alphaMin<row.alphaMax;
         }
         check(properties,"ground entities use native stationary Part/visualAcid");
         check(life,"native 100..129-frame acid lifespan reaches removal and detaches its display");
         check(animated && faded,"actual acid artwork animates and changes native alpha");
         if(source) {
            check(sourceShots==1 && inputReleased>0,"one real G throw, input released before ground terminal");
            var onSurface:Boolean=proof.rows.length>0;
            for each(row in proof.rows) {
               var tile:Object=row.surface;
               onSurface=onSurface && tile!=null && tile.ty>1 && (tile.phis>0 || tile.shelf)
                  && (tile.zForm!=0 || tile.above==0) && Math.abs(row.x-tile.x)<=2.01 && Math.abs(row.y-tile.y)<.01;
            }
            check(onSurface,"source acid Part uses actual exposed native tile surface, without fire -33 offset");
         } else check(unexpectedBullets==0,"receiver does not create another native damaging acid projectile");
         setPhase("result");if(host)advance();else send("result",{value:localResult});
      }''')
    text=one(text,body(text,'advance'),'''      private function advance():void {
         if(!host || localResult==null || peerResult==null)return;
         var origin:Object=localResult.source?localResult:peerResult,remote:Object=localResult.source?peerResult:localResult;
         var a:Array=origin.proof.rows,b:Array=remote.proof.rows,used:Object={},matches:Array=[];
         var equal:Boolean=a.length>0 && a.length==b.length;
         for each(var r:Object in b) {
            var chosen:int=-1,distance:Number=1e30;
            for(var i:int=0;i<a.length;i++)if(!used[i]) {
               var dx:Number=Math.abs(Number(r.x)-Number(a[i].x)),dy:Number=Math.abs(Number(r.y)-Number(a[i].y));
               if(dx<=4 && dy<=4 && dx*dx+dy*dy<distance){chosen=i;distance=dx*dx+dy*dy;}
            }
            if(chosen<0)equal=false;
            else {used[chosen]=true;matches.push({source:a[chosen].id,remote:r.id,dx:r.x-a[chosen].x,dy:r.y-a[chosen].y});}
         }
         check(equal,"one-to-one ground footprint follows real source Parts within +/-4px, source="+a.length+" remote="+b.length);
         Log.d("ACID GROUND COMPARE "+JSON.stringify({round:round,water:spec.water,matches:matches,matched:equal}));
         nextRound();
      }''')
    text=one(text,'         if(phase=="done")return;setPhase("done");t.stop();',
        '         if(phase=="done")return;setPhase("done");t.stop();if(ground!=null)ground.dispose();')
    # The independent suite does not claim the original explosion/flight gates.
    start=text.index('   /** Native player input');end=text.index('   public class ',start)
    text=text[:start]+'''   /** Dedicated ground-acid suite: native G input -> actual PhisBullet/Part
    * -> production TCP -> actual receiving Part and stage pixels. Four trials:
    * dry host/join source, water host/join source. Not a flight/FPS benchmark. */
'''+text[end:]
    target=HERE/'native'/(ENTRY+'.as');target.write_text(text,encoding='utf-8')
    (HERE/'driver.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),text.splitlines(True),
        fromfile='existing/ExplosiveVisualTestDoc.as',tofile='isolated/'+ENTRY+'.as')),encoding='utf-8')
    plan=dict(entry=ENTRY,baseline=str(BASE.relative_to(ROOT)),baseline_sha256=sha(BASE),
        source_sha256=sha(target),files={p.name:sha(p) for p in sorted((HERE/'native').glob('*.as'))},
        rounds=4,seconds=360,compiled=False,air_started=False,performance_qualified=False,
        image_readback='after all observed ground Parts expire; PNG saved to isolated application storage',
        position_tolerance_px=4,generator_sha256=sha(Path(__file__)))
    (HERE/'native-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(entry=ENTRY,files=len(plan['files']),rounds=4,compiled=False,air_started=False)))


if __name__=='__main__':main()
