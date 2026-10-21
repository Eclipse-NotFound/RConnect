"""Four-class gas Part observer derived from recovery11. Text only; no JVM/AIR."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-11'
BASE_SHA='cd721f0e56679302747ab2c9e687e20bd877a1ee8f520d6d589c7c43fa64ebb5'
PINNED={
 'UnitPresentation.as':'3e408515983fc28ad7b1a383c9e7353c5c137c960ae6ecf88e086204addb63cd',
 'EnergyImpactVisuals.as':'d049d4a3fd996ac3088eb5bd2e4f8c765b954efe61f34a0899fa26e29cd72dee',
 'ProjectileExplosionVisuals.as':'9851281cbe57419762a8b7c167e89aa8d29237d72840c33c5f62f35e334ecefb',
 'DeathVisuals.as':'16bf7e1903bf72890cdbcb15b3da175e5b8afe268d24e14406f5229bb3fd2f89'}
REAL=['UnitPresentation','EnergyImpactVisuals','ProjectileVisuals','ProjectileExplosionVisuals',
      'ImpactEventQueue','ProjectileFrameStream','RemoteMotion','DeathVisuals']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,text):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(text.encode('utf-8'))
def one(text,old,new):
 assert text.count(old)==1,old
 return text.replace(old,new,1)

def derive():
 assert sha(BASE/'RConnectMod.swf')==BASE_SHA
 old={n:(BASE/'src/rconnect/game'/n).read_text(encoding='utf-8') for n in PINNED}
 assert all(sha(BASE/'src/rconnect/game'/n)==h for n,h in PINNED.items())
 new=dict(old)
 t=old['EnergyImpactVisuals.as']
 t=one(t,'visualFlame:true,visualFlare:true};','visualFlame:true,visualFlare:true,visualGas:true,visualPinkGas:true};')
 t=one(t,'if(CLIPS[cls]===true && get(o,"in_chain")===true',
       'if(CLIPS[cls]===true && cls!="visualGas" && cls!="visualPinkGas" && get(o,"in_chain")===true')
 t=one(t,'      private var serial:int=0;', '''      private var serial:int=0;
      private var gasRoom:Object,gasRecords:Array=[],gasSeen:Dictionary=new Dictionary(true);
      private var gasKinds:Dictionary=new Dictionary(true),gasClips:Dictionary=new Dictionary(true);
      private static var replayedParts:Dictionary=new Dictionary(true);

      /** Old packets still use native Emitter recipes. Never send their cosmetic
       * result back as a newly observed source Part. New gas packets use clips. */
      public static function ignoreNativePart(p:Object):void {if(p!=null)replayedParts[p]=true;}
      public function beginGasFrame(loc:Object):void {
         if(gasRoom===loc)return;
         gasRoom=loc;gasRecords=[];gasSeen=new Dictionary(true);
      }
      /** Called inside the existing object-chain traversal, not once per gun.
       * Cached native class identities avoid repeated class-name formatting. */
      public function observeGasPart(p:Object,stamp:int):void {
         if(p==null || stamp<=0 || replayedParts[p])return;
         var kind:Object=p.constructor;
         if(gasKinds[kind]===undefined)gasKinds[kind]=getQualifiedClassName(p)=="fe.graph::Part";
         if(gasKinds[kind]!==true || gasSeen[p] || get(p,"loc")!==gasRoom || get(p,"in_chain")!==true)return;
         var v:DisplayObject=get(p,"vis") as DisplayObject;if(v==null)return;
         kind=Object(v).constructor;
         if(gasClips[kind]===undefined) {
            var name:String=getQualifiedClassName(v);
            gasClips[kind]=(name=="visualGas" || name=="visualPinkGas")?name:"";
         }
         var clip:String=String(gasClips[kind]);if(clip=="")return;
         gasSeen[p]=true;
         gasRecords.push({part:p,loc:gasRoom,wire:{id:++serial,cls:clip,layer:int(get(p,"sloy")),
            blend:String(v.blendMode),frames:[],end:0,strictEnd:true}});
      }
      public function finishGasFrame(stamp:int):void {sampleRecords(gasRecords,stamp);}
      public function captureGas(loc:Object):Array {return loc===gasRoom?deltaRecords(gasRecords,64):[];}
''')
 start=t.index('         for each(record in list) {')
 end=t.index('\n      public function capture(w:Object):Array',start)
 body=t[start:end]
 assert body.endswith('      }\n')
 body=body.replace('for each(record in list)','for each(var record:Object in list)',1).replace('            p=record.part;','            var p:Object=record.part;',1)
 t=t[:start]+'         sampleRecords(list,stamp);\n      }\n\n      private function sampleRecords(list:Array,stamp:int):void {\n'+body+t[end:]
 t=one(t,'''      public function captureDelta(w:Object):Array {
         var out:Array=[],list:Array=sources[w] as Array;''','''      public function captureDelta(w:Object):Array {return deltaRecords(sources[w] as Array);}
      private function deltaRecords(list:Array,pointBudget:int=0):Array {
         var out:Array=[],remaining:int=pointBudget;''')
 t=one(t,'''         for each(var record:Object in list) {
            var wire:Object=record.wire,all:Array=wire.frames as Array;''', '''         for each(var record:Object in list) {
            if(pointBudget>0 && remaining<=0)break;
            var wire:Object=record.wire,all:Array=wire.frames as Array;''')
 t=one(t,'''            if(points.length==0)points.push(all[all.length-1]);
            out.push''', '''            if(points.length==0)points.push(all[all.length-1]);
            if(pointBudget>0 && points.length>remaining)points=points.slice(0,remaining);
            // A bounded prefix is not permission to end before later native
            // samples. Only consume the transmitted prefix and its true end.
            var end:int=pointBudget==0 || points[points.length-1]===all[all.length-1]?int(wire.end):0;
            remaining-=points.length;
            out.push''')
 t=one(t,'out.push({id:wire.id,cls:wire.cls,layer:wire.layer,blend:wire.blend,frames:points,end:wire.end,delta:true});',
 '''var packet:Object={id:wire.id,cls:wire.cls,layer:wire.layer,blend:wire.blend,frames:points,end:end,delta:true};
            if(wire.strictEnd===true)packet.strictEnd=true;
            out.push(packet);''')
 t=one(t,'record.fastEnd=wire.end;','record.fastEnd=end;')
 t=one(t,'            if(ended) {','''            // A persistent gas cloud has a real sampled end. Do not apply the
            // short flash's missed-frame recovery to extend its native lifetime.
            if(ended && s.strictEnd===true) {remove(i);continue;}
            if(ended) {''')
 t=one(t,'         chainLoc=null;chainStamp=-1;bullets=new Dictionary(true);parts={};',
 '''         chainLoc=null;chainStamp=-1;bullets=new Dictionary(true);parts={};
         gasRoom=null;gasRecords=[];gasSeen=new Dictionary(true);''')
 new['EnergyImpactVisuals.as']=t

 t=old['UnitPresentation.as']
 t=one(t,'      private var shotStream:int=0;','      private var shotStream:int=0,gasStream:int=0;')
 t=one(t,'         scannedLoc=loc;scannedAt=stamp;frameBullets=new Dictionary(true);',
 '''         if(loc!==scannedLoc)gasStream=++shotStream;
         scannedLoc=loc;scannedAt=stamp;frameBullets=new Dictionary(true);
         energyImpacts.beginGasFrame(loc);''')
 t=one(t,'            if(!(o is Bullet))continue;',
 '            if(!(o is Bullet)){energyImpacts.observeGasPart(o,stamp);continue;}')
 t=one(t,'            frameBullets[w].push(o);\n         }\n      }',
 '            frameBullets[w].push(o);\n         }\n         energyImpacts.finishGasFrame(stamp);\n      }')
 t=one(t,'         return result;\n      }\n\n      /** Terminal state',
 '''         if(playerDisplay) {
            // This explicit room stream merely rides the local player's packet.
            // It identifies actual Part objects, never their presumed shooter.
            var gas:Array=energyImpacts.captureGas(get(u,"loc"));
            if(gas.length>0)result.push({id:"@room-gas",variant:0,stream:gasStream,
               roomParts:true,effectsOnly:true,main:false,sampleTime:frameTime,events:[],impacts:gas});
         }
         return result;
      }

      /** Terminal state''')
 new['UnitPresentation.as']=t

 t=old['ProjectileExplosionVisuals.as']
 t=one(t,'custom:custom==null?"":String(custom),ground:BurnVisuals.captureGround(b)};',
 '''custom:custom==null?"":String(custom),ground:BurnVisuals.captureGround(b),
            nativeGasParts:custom=="gas" || custom=="pinkgas" || ((custom==null || custom=="")
               && (int(GameBridge.probe(b,"tipDamage"))==7 || int(GameBridge.probe(b,"tipDamage"))==19))};''')
 t=one(t,'            emitter.emit(name,loc,x,y+(name=="balefire"?-60:0),options);',
 '''            if(name=="gas" || name=="pinkgas") {
               // New packets carry each actually created Part separately. Keep
               // the once-only explosion sound even when native maxkol emits none.
               if(state.nativeGasParts===true)continue;
               // Legacy cosmetic replay is still allowed, but never recaptured.
               EnergyImpactVisuals.ignoreNativePart(emitter.arr[name].cast(loc,x,y,options));
            } else emitter.emit(name,loc,x,y+(name=="balefire"?-60:0),options);''')
 new['ProjectileExplosionVisuals.as']=t
 t=old['DeathVisuals.as']
 t=one(t,'return {armed:u.lootIsDrop!=true,type:type,water:false};',
       'return {armed:u.lootIsDrop!=true,type:type,water:false,nativeGasParts:type==7 || type==19};')
 t=one(t,'            emitter.emit(name,loc,x,y+(name=="balefire"?-60:0),options);',
 '''            if(name=="gas" || name=="pinkgas") {
               if(s.nativeGasParts===true)continue;
               EnergyImpactVisuals.ignoreNativePart(emitter.arr[name].cast(loc,x,y,options));
            } else emitter.emit(name,loc,x,y+(name=="balefire"?-60:0),options);''')
 new['DeathVisuals.as']=t
 return old,new

def expected():
 old,new=derive()
 out={'src/rconnect/game/'+n:t for n,t in new.items()}
 out['proposal.patch']=''.join(''.join(difflib.unified_diff(old[n].splitlines(True),new[n].splitlines(True),
  fromfile='recovery-11/'+n,tofile='recovery-gas-pulse/'+n)) for n in old)
 return out

def verify():
 for n,t in expected().items():assert (HERE/n).read_bytes()==t.encode(),n
 meta=json.loads((HERE/'inputs.json').read_text())
 files={p.relative_to(HERE).as_posix():sha(p) for tree in ('src','tests','components')
        for p in sorted((HERE/tree).rglob('*')) if p.is_file()}
 assert files==meta['files'] and sha(Path(__file__))==meta['prepare_sha256']
 assert sha(HERE/'proposal.patch')==meta['patch_sha256']
 return dict(verified=True,overlays=4,expected_assertions=meta['expected_assertions'],JVM_started=False,AIR_started=False)

def build_sources():
 for n,t in expected().items():put(HERE/n,t)
 for variant in ('control','candidate'):
  dest=HERE/'components'/variant
  assert not dest.exists(),'Do not replace delivered components'
  shutil.copytree(HERE/'tests',dest)
  for name in REAL:
   rel='rconnect/game/'+name+'.as'
   origin=HERE/'src'/rel if variant=='candidate' and (HERE/'src'/rel).is_file() else BASE/'src'/rel
   put(dest/rel,origin.read_text(encoding='utf-8'))
  put(dest/'rconnect/net/BinaryMessageCodec.as',(BASE/'src/rconnect/net/BinaryMessageCodec.as').read_text())
 meta=dict(base=str(BASE.relative_to(ROOT)),base_sha256=BASE_SHA,source=PINNED,
  files={p.relative_to(HERE).as_posix():sha(p) for tree in ('src','tests','components')
         for p in sorted((HERE/tree).rglob('*')) if p.is_file()},
  prepare_sha256=sha(Path(__file__)),patch_sha256=sha(HERE/'proposal.patch'),expected_assertions=63,
  compiled=False,air_started=False,gameplay_qualified=False,performance_qualified=False)
 put(HERE/'inputs.json',json.dumps(meta,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--verify',action='store_true');args=ap.parse_args()
 if args.verify:print(json.dumps(verify()))
 else:build_sources();print(json.dumps(verify()))
