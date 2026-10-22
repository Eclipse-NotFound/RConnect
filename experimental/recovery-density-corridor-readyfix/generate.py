"""Derive setup-only AS source from the exact compiled corridor02; no build/AIR."""
import hashlib
import json
from pathlib import Path
import shutil

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-density-corridor-drivers-02'
MANIFEST='d014852ab877dcb750c9bfcf4fe03d2b78080f23c5af639eb5db0933c690bcb3'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

EDITS=[
('                  gun.hold=10000;gun.damage=1;gun.destroy=0;gun.damageExpl=0;gun.precision=0;gun.deviation=0;gun.critCh=0;',
 '                  DensityWeaponPreparation.configure(gun);'),
('         CorridorFixture.apply(mod,loadActors,loadGuns,true);',
 '         CorridorFixture.apply(mod,loadActors,loadGuns,true);\n         DensityWeaponPreparation.bindHost(loadActors);'),
('direction:Number(u.storona),hp:Number(u.hp),weapon:u.currentWeapon==null?null:String(u.currentWeapon.id)};',
 'direction:Number(u.storona),hp:Number(u.hp),weapon:DensityWeaponPreparation.identity(u)};'),
('            objects.push(u);var row:Object=arenaIdentity(u);actual.push(row);\n            if(DensityFixture.canonical(row)!=DensityFixture.canonical(arenaExpected[i]))identityOK=false;',
 '            objects.push(u);'),
('         if(!host && objects.length==80 && !arenaCleaned) {',
 '         if(!host && objects.length==80 && !arenaCleaned && DensityWeaponPreparation.modelsMatch(objects,arenaExpected)) {'),
('            arenaRemoved=DensityFixture.removeExtras(mod,objects);arenaCleaned=true;loadActors=objects;\n            CorridorFixture.apply(mod,loadActors,loadGuns,false);\n         }',
 '            arenaRemoved=DensityFixture.removeExtras(mod,objects);loadActors=objects;\n            CorridorFixture.apply(mod,loadActors,loadGuns,false);\n            DensityWeaponPreparation.prepareMirrors(objects,arenaExpected);arenaCleaned=true;\n         }\n         for(i=0;i<objects.length;i++) {\n            var row:Object=arenaIdentity(objects[i]);actual.push(row);\n            if(DensityFixture.canonical(row)!=DensityFixture.canonical(arenaExpected[i]))identityOK=false;\n         }'),
('            if(identity.weapon!=null)weapons[identity.weapon]=int(weapons[identity.weapon])+1;}',
 '            if(identity.weapon!=null)weapons[identity.weapon.id]=int(weapons[identity.weapon.id])+1;}'),
('         return {ok:objects.length==80 && identityOK && arenaCleaned && extras.length==0',
 '         return {ok:objects.length==80 && identityOK && arenaCleaned && DensityWeaponPreparation.bound(objects) && extras.length==0'),
]

def expected_source():
    assert sha(BASE/'prepared.json')==MANIFEST
    meta=json.loads((BASE/'prepared.json').read_text(encoding='utf-8-sig'))
    path=BASE/'tests/SustainedDensityTestDoc.as'
    assert sha(path)==meta['files']['tests/SustainedDensityTestDoc.as']
    text=path.read_text(encoding='utf-8-sig')
    for old,new in EDITS:
        assert text.count(old)==1,old
        text=text.replace(old,new)
    return text

def main():
    source=expected_source()
    meta=json.loads((BASE/'prepared.json').read_text(encoding='utf-8-sig'))
    for path in sorted((BASE/'tests').rglob('*.as')):
        rel=path.relative_to(BASE).as_posix();assert sha(path)==meta['files'][rel]
        target=HERE/rel;assert not target.exists(),target
        target.parent.mkdir(parents=True,exist_ok=True)
        if rel=='tests/SustainedDensityTestDoc.as':target.write_text(source,encoding='utf-8',newline='\n')
        else:shutil.copyfile(path,target)
    (HERE/'edits.json').write_text(json.dumps(EDITS,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'source_only':True,'compiled':False,'air_started':False,'base':str(BASE)}))

if __name__=='__main__':main()
