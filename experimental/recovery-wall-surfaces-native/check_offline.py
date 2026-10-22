"""Offline counterexamples and exact shared-runner adaptation checks. No JVM/AIR."""
import copy
import inspect
import json
import re
from pathlib import Path
import sys
import tempfile
from PIL import Image

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import verify_results as v
import native_tool as tool


def rows(n=0):
    weapon,role,count=v.CASES[n];base=[0xff505050]*(128*128);final=base.copy()
    for i in range(50,56):final[i]=0xff123456+i
    sparse=[x for i in range(50,56) for x in (i,final[i])]
    frames=[dict(at=10,wall=10010,cost=1,native=[],display=[]),dict(at=510,wall=10510,cost=1,native=sparse,display=sparse),
            dict(at=10010,wall=20010,cost=1,native=sparse,display=sparse)]
    surface=dict(x=1900,y=980,side=320,gutter=20,width=360,height=360,revision=0,scratchDifferent=True,staged=True)
    common=dict(round=n,weapon=weapon,target=dict(x=2000,y=1100),area=dict(x=1936,y=1036,w=128,h=128),
        start=10,startWall=10010,end=10011,shots=count,hits=[dict(x=2001,y=1100)]*count,sourceFirst=10500,
        attackAttempts=count,attackAccepted=count,firstAttack=dict(accepted=True),firstRejected=None,
        nativeOracle=sparse,baseline=base,baselineDisplay=base,finalNative=final,finalDisplay=final,
        frames=frames,surfaces=[surface],finalSurfaces=[surface],maxCaptureMs=1)
    a=copy.deepcopy(common);a.update(role=role,source=True)
    b=copy.deepcopy(common);b.update(role='join' if role=='host' else 'host',source=False,nativeOracle=[],sourceFirst=0,shots=0,hits=[],
        attackAttempts=0,attackAccepted=0,firstAttack=None)
    return a,b


def main():
    checks=[]
    def test(label,fn):
        try:fn();checks.append(dict(label=label,passed=True))
        except Exception as e:checks.append(dict(label=label,passed=False,error=repr(e)))
    def ok(value):assert value
    def reject(a,b):
        try:r=v.compare(a,b)
        except (AssertionError,KeyError,ValueError):return
        assert not r['functional_pass'],'Invalid observation was accepted'
    for n in range(4):test('exact two-way '+str(n),lambda n=n:ok(v.compare(*rows(n))['functional_pass']))
    def negative(label,mutate):
        def check():
            a,b=rows();mutate(a,b);reject(a,b)
        test(label,check)
    negative('Part-only visual cannot stand in for persistent native pixels',lambda a,b:b.update(finalNative=b['baseline']))
    negative('no remote mark fails',lambda a,b:b.update(finalNative=b['baseline'],finalDisplay=b['baselineDisplay']))
    negative('wrong world crop fails',lambda a,b:b['area'].update(x=0))
    negative('small actual hit cannot pass large target label',lambda a,b:a['hits'][0].update(x=200,y=110))
    negative('manual source final absent collision oracle fails',lambda a,b:a.update(nativeOracle=[]))
    negative('extra remote pixel fails',lambda a,b:b['finalNative'].__setitem__(77,123))
    negative('wrong remote original pixels fail',lambda a,b:b['baseline'].__setitem__(77,123))
    negative('scratch alias fails',lambda a,b:b['surfaces'][0].update(scratchDifferent=False))
    negative('partial first frame cannot replace final equality',lambda a,b:b['finalNative'].__setitem__(54,0))
    negative('missing displayed front fails',lambda a,b:b.update(finalDisplay=b['baselineDisplay']))
    negative('short observation cannot pass',lambda a,b:b.update(end=9000))
    negative('no matching complete frame fails',lambda a,b:[f.update(native=[],display=[]) for f in b['frames']])
    def disappear(a,b):
        frame=copy.deepcopy(b['frames'][1]);frame.update(at=600,wall=10600,native=[],display=[]);b['frames'].insert(2,frame)
    negative('later persistent mark disappearance cannot pass via first/final frame',disappear)
    negative('source and remote display baselines differ fails',lambda a,b:b['baselineDisplay'].__setitem__(100,0))
    negative('zero accepted source attacks cannot pass with unrelated wall pixels',lambda a,b:a.update(attackAccepted=0))
    negative('rejected first source attack cannot hide behind later success',lambda a,b:a['firstAttack'].update(accepted=False))
    def native_eligibility():
        # Static contract checks against actual reference class/data and the
        # proven driver. This is not an AS runtime execution claim.
        ref=tool.ROOT.parents[1]/'game-reference/decompiled/1.02/src102/scripts/fe'
        weapon=(ref/'weapon/Weapon.as').read_text(encoding='utf-8')
        pers=(ref/'unit/Pers.as').read_text(encoding='utf-8')
        data=(ref/'AllData.as').read_text(encoding='utf-8')
        old=(tool.ROOT/'tests/WallImpactTestDoc.as').read_text(encoding='utf-8')
        actor=(HERE/'tests/LargeWallSurfaceTestDoc.as').read_text(encoding='utf-8')
        for name,level in [('lmg',5),('plamg',4)]:
            tag=re.search(r"<weapon id='"+name+r"'[^>]+>",data).group(0)
            assert "lvl='"+str(level)+"'" in tag and level-0>2
        assert 'this.lvl - (this.owner as UnitPlayer).pers.getWeapLevel(this.skill)' in weapon
        assert 'else if(_loc1_ > 2)' in weapon and 'if(!this.checkAvail())' in weapon
        assert 'this.skills[sk.@id] = 0;' in pers
        assert 'gun.lvl=gun.perslvl=0;' in old and actor.count('gun.lvl=gun.perslvl=0;')==1
        prepare=actor.split('private function prepare(',1)[1].split('private function attackState(',1)[0]
        assert prepare.index('g.changeWeapon(id,true)')<prepare.index('gun.lvl=gun.perslvl=0;')<prepare.index('gun.hold=gun.holder')
        player=(ref/'unit/UnitPlayer.as').read_text(encoding='utf-8')
        assert 'currentWeapon.setPers(this,this.pers);' in player
        assert 'g.invent.addWeapon(id)' in prepare and 'g.childObjs=g.childObjs.concat()' in prepare
        assert 'g.invent.weapons=oldInventory.weapons' in actor and 'g.childObjs=oldChildren' in actor
        assert actor.count('gun.attack()')==1 and 'var accepted:Boolean=gun.attack();' in actor
        before=actor.split('private function before(',1)[1].split('private function remember(',1)[0]
        assert 'Log.d(' not in before and 'attackAttempts==0?attackState():null' in before
        assert 'firstRejected==null' in before
    test('real native level gate and proven fixture preparation preserved without per-attempt IO',native_eligibility)
    def previous_source_rows():
        run=tool.ROOT/'build/cooperation/df0cb3dad0';actual=[]
        for role in ('host','join'):
            for line in (run/(role+'.log')).read_text(encoding='utf-8-sig').splitlines():
                if line.startswith('LARGE WALL PROOF '):
                    row=json.loads(line.split('LARGE WALL PROOF ',1)[1])
                    if row['source']:actual.append((row['round'],role,row['shots'],row['hits'],row['nativePixels']))
        assert sorted(actual)==[(0,'host',0,0,0),(1,'join',0,0,0),(2,'host',0,0,0),(3,'join',0,0,0)]
    test('df0 source roles all failed admission; receiver zero shots not treated as source failure',previous_source_rows)
    def duplicates():
        try:v.pairs([1,2,1,3])
        except AssertionError:return
        raise AssertionError('duplicate sparse pixel accepted')
    test('duplicate coordinate fails',duplicates)
    def adaptation():
        import run
        fn,source,_=tool.adapted_native(run)
        original=inspect.getsource(run.native)
        # All five changes are narrow bindings. Existing startup, full result
        # parsing, clean-up and qualification blocks must remain verbatim.
        for anchor in ["require(process.returncode == 0", "suite = SUITES[entry]", "result['runtime_input_audit'] = native_inputs", "finally:\n        clean_native_copies(run, result)"]:
            assert anchor in original and anchor in source
        assert source.count("command += ['--game-candidate'")==1
        for flag in ("'--require-exclusive-air'","'--all-mods'","'--private-desktop'","'--wait-host-world'","'--keep-copies'"):
            assert flag in source
        assert run.EXPECTED_INSTALLATION_FILES==22
    test('existing full native framework gates retained',adaptation)
    def audited_hosts():
        old=tool.host_evidence();new=tool.host_evidence(tool.WALL_HOST)
        assert old['candidate_sha256']=='fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e'
        assert new['candidate_sha256']==tool.WALL_SHA and new['validated']
        assert old['installation']==new['installation'] and len(new['installation'])==22
        assert new['original_failed_receipt_preserved'] and not new['gameplay_qualified']
        assert tool.prepare.read(tool.WALL_HOST/'prepared.json')['validated'] is False
        assert str(tool.WALL_RECHECK) in tool.tools()
    test('FD92 default and explicit ACC pass exact independent readbacks and same 22 inputs',audited_hosts)
    def reject_other_host():
        for folder in [tool.ROOT/'build/m52/recovery-wall-surfaces-host-source-only',tool.ROOT/'build/m52/recovery-native-travel-host-01',HERE]:
            try:tool.host_evidence(folder)
            except AssertionError:continue
            raise AssertionError('Unapproved host accepted: '+str(folder))
    test('arbitrary and source-only host directories cannot pass by kind',reject_other_host)
    def timing():
        actor=(HERE/'tests/LargeWallSurfaceTestDoc.as').read_text(encoding='utf-8')
        probe=(HERE/'tests/NativeWallSurfaceProbe.as').read_text(encoding='utf-8')
        sample=actor.split('private function before(',1)[1].split('private function savePNG(',1)[0]
        assert 'getVector(' not in sample and 'encode(' not in sample
        assert 'if(phase!="sampled")throw' in actor and 'sampledSent' in actor and 'peerSampled' in actor
        assert probe.count('getVector(')==1 and 'public static function words(' in probe
        for forbidden in ('.receive(','.hitTile(','.dyrka(','.setPixel', 'applyTilePatch(', 'Emitter.emit(', 'sceneEnsure('):
            assert forbidden not in actor+probe,forbidden
        assert 'core.intersection(area)' in probe and 'core' in probe and 'out.copyPixels(data' in probe
        assert 'data===g.frontBmp' in probe and 'native.bitmapData!==data' in probe
        assert 'beginMission("random_mane")' in actor
    test('readback after both sampling stops and no synthetic production wall writes',timing)
    def artifact_pipeline():
        with tempfile.TemporaryDirectory(prefix='offline-proof-',dir=HERE) as name:
            folder=Path(name).resolve();assert folder.parent==HERE.resolve()
            log_rows={role:[] for role in ('host','join')}
            logs={role:folder/(role+'.log') for role in ('host','join')}
            for n in range(4):
                for row in rows(n):
                    role=row['role'];target=folder/role;target.mkdir(exist_ok=True)
                    payload=json.dumps(row,separators=(',',':'));proof=target/f'round-{n}-proof.json';proof.write_text(payload,encoding='utf-8')
                    files=[]
                    for suffix,field in [('before-native','baseline'),('after-native','finalNative'),('before-display','baselineDisplay'),('after-display','finalDisplay')]:
                        path=target/f'round-{n}-{suffix}.png';im=Image.new('RGBA',(128,128))
                        im.putdata([((v>>16)&255,(v>>8)&255,v&255,(v>>24)&255) for v in row[field]]);im.save(path)
                        files.append(dict(name=path.name,bytes=path.stat().st_size,width=128,height=128))
                    log_rows[role].append(dict(round=n,role=role,bytes=proof.stat().st_size,target=row['target'],source=row['source'],
                        shots=row['shots'],hits=len(row['hits']),sourceFirst=row['sourceFirst'],samples=len(row['frames']),
                        attackAttempts=row['attackAttempts'],attackAccepted=row['attackAccepted'],firstAttack=row['firstAttack'],firstRejected=row['firstRejected'],
                        nativePixels=len(row['nativeOracle'])//2,files=files))
            def write_logs():
                for role in logs:logs[role].write_text('\n'.join('LARGE WALL PROOF '+json.dumps(row) for row in log_rows[role]),encoding='utf-8')
            write_logs();assert v.analyze(folder,logs)['passed']
            image=folder/'join/round-0-after-native.png';original=image.read_bytes()
            im=Image.open(image).convert('RGBA');im.putpixel((50,0),(0,0,0,255));im.save(image)
            # Update the byte count too: content validation must still reject.
            log_rows['join'][0]['files'][1]['bytes']=image.stat().st_size;write_logs()
            assert not v.analyze(folder,logs)['passed'],'Unrelated PNG passed after byte-count repair'
            image.write_bytes(original);log_rows['join'][0]['files'][1]['bytes']=len(original);write_logs()
            assert v.analyze(folder,logs)['passed']
            log_rows['join'].append(copy.deepcopy(log_rows['join'][0]));write_logs()
            assert not v.analyze(folder,logs)['passed'],'Duplicate proof log accepted'
    test('32 PNG and 8 JSON exact proof pipeline rejects forged image and duplicate receipt',artifact_pipeline)
    result=dict(passed=all(r['passed'] for r in checks),checks=checks,count=len(checks),failed=sum(not r['passed'] for r in checks),
                offline_only=True,jvm_started=False,air_started=False,native_qualified=False)
    (HERE/'offline-result.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False));return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
