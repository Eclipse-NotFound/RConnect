"""Create a separately named, auditable workload from frozen AB007. No compiler/game."""
from pathlib import Path
import hashlib
import json
import shutil
import difflib

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / 'build/ab/ab-driver-007'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    original = json.loads((BASE / 'build-input.json').read_text())
    for name, digest in original['sources'].items():
        if sha(BASE / name) != digest: raise ValueError('Frozen AB007 changed: ' + name)
    if (HERE / 'src').exists(): raise FileExistsError(HERE / 'src')
    shutil.copytree(BASE / 'src', HERE / 'src')
    shutil.copytree(BASE / 'stubs', HERE / 'stubs')
    path = HERE / 'src/ABBench.as'
    before = path.read_text()
    text = before
    def change(old, new):
        nonlocal text
        if text.count(old) != 1: raise ValueError('Unexpected AB007 anchor: ' + old[:70])
        text = text.replace(old, new)
    change('private var anchors:Array=[];', '''private var anchors:Array=[];
  private static const MAGAZINE:int=1000,SAMPLE_MS:int=750;
  private var phaseReserve:Array=[],peerMagazineReady:Boolean=false,magazineReported:Boolean=false,beginAllowed:Boolean=false;
  private function weaponState():Array {
   var rows:Array=[];
   for each(var g:Object in actors()) {var gun:Object=g.currentWeapon;
    rows.push({id:gun.id,capacity:gun.holder,hold:gun.hold,reload:gun.t_reload,
     reserve:g.invent.items[gun.ammo].kol,attack:gun.t_attack});}
   return rows;
  }
  private function prepareMagazines():void {
   if(!isB || !host)throw new Error("Sustained preparation requires authoritative B host");
   phaseReserve=[];var records:Array=[];
   for each(var actor:Object in mod.host.actors) {
    if(actor.id!=records.length)throw new Error("Unexpected actor order");
    mod.access.scope.run(actor.context,function():void {
     var g:Object=actor.unit,gun:Object=g.currentWeapon;
     if(gun==null || gun.id!="lmg" || gun.variant!=0 || gun.ammo!="p556" || gun.rapid!=2 || gun.rashod!=1 || gun.kol!=1)
      throw new Error("Unexpected native LMG");
     var row:Object={player:actor.id,beforeCapacity:gun.holder,beforeHold:gun.hold,
      reload:gun.t_reload,attack:gun.t_attack,reserve:g.invent.items[gun.ammo].kol};
     gun.holder=MAGAZINE;gun.hold=MAGAZINE;
     phaseReserve.push(row.reserve);row.capacity=gun.holder;row.hold=gun.hold;records.push(row);
    });
   }
   if(records.length!=2)throw new Error("Missing authoritative actors");
   log("magazine-prepared",{phase:phase,capacity:MAGAZINE,sampleMs:SAMPLE_MS,players:records});
  }
  private function checkMagazines(full:Boolean):void {
   var members:Array=actors();
   if(!isB || members.length!=(host?2:1) || phaseReserve.length!=members.length)throw new Error("Missing magazine baseline");
   for(var i:int=0;i<members.length;i++) {
    var g:Object=members[i],gun:Object=g.currentWeapon;
    if(gun==null || gun.id!="lmg" || gun.holder!=MAGAZINE || gun.hold<=0 || gun.hold>MAGAZINE ||
       (full && gun.hold!=MAGAZINE) || gun.t_reload!=0 || g.invent.items[gun.ammo].kol!=phaseReserve[i])
     throw new Error("Sustained magazine contract: phase "+phase+", player "+i);
   }
  }''')
    change('phase=int(v.phase);preparedAt=getTimer();started=0;prev=0;armed=false;',
           'phase=int(v.phase);preparedAt=getTimer();started=0;prev=0;armed=false;magazineReported=false;beginAllowed=false;phaseReserve=[];')
    change('if(v.op=="ping")', '''if(v.op=="magazine-ready" && host && v.phase===phase && v.capacity===MAGAZINE && v.hold===MAGAZINE && v.reload===0)peerMagazineReady=true;
   if(v.op=="begin" && !host && v.phase===phase)beginAllowed=true;
   if(v.op=="ping")''')
    change('if(host && peerReady && !armed && (phase<0 || started<0)){',
           'if(host && peerReady && !armed && (phase<0 || started<0) && (mod.host.inputs[1].buttons&8)==0 && !mod.host.actors[1].context.ctr.keyAttack){')
    change('spawn(phaseCounts[phase]);preparedAt=now;',
           'spawn(phaseCounts[phase]);prepareMagazines();peerMagazineReady=false;preparedAt=now;')
    change('if(started==0 && now-preparedAt>=5000){started=now;', '''if(!host && started==0 && !magazineReported && w.gg.currentWeapon.holder==MAGAZINE && w.gg.currentWeapon.hold==MAGAZINE && w.gg.currentWeapon.t_reload==0) {
     phaseReserve=[w.gg.invent.items[w.gg.currentWeapon.ammo].kol];checkMagazines(true);magazineReported=true;
     log("magazine-observed",{phase:phase,players:weaponState()});
     send({op:"magazine-ready",phase:phase,capacity:MAGAZINE,hold:MAGAZINE,reload:0});
    }
    if(started==0 && (host?now-preparedAt>=5000 && peerMagazineReady:beginAllowed && magazineReported)){
     if(host){checkMagazines(true);send({op:"begin",phase:phase});}else checkMagazines(false);
     started=now;''')
    change('if(started<=0)return;\n    if(prev>0)', 'if(started<=0)return;\n    checkMagazines(false);\n    if(prev>0)')
    change('if(now-lastSample>=1000)', 'if(now-lastSample>=SAMPLE_MS)')
    change('v.weapons.push({hold:', 'v.weapons.push({id:a.currentWeapon.id,capacity:a.currentWeapon.holder,hold:')
    path.write_text(text, encoding='utf-8', newline='\n')
    (HERE / 'AB007-to-sustained.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True), text.splitlines(True), fromfile='AB007/ABBench.as', tofile='sustained/ABBench.as')), encoding='utf-8')
    source_files={p.relative_to(HERE).as_posix():sha(p) for folder in ('src','stubs') for p in sorted((HERE/folder).rglob('*.as'))}
    (HERE / 'source-plan.json').write_text(json.dumps(dict(base=original['source_id'],sources=source_files,magazine=1000,sample_ms=750,measurement_seconds=60,qualification='new workload; old failures preserved'),indent=2),encoding='utf-8')
    print('Prepared separate source; no runtime or frozen AB007 change')

if __name__=='__main__': main()
