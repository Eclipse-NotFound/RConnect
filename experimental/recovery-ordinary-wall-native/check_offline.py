"""Ordinary admission/strict-color counterexamples; no AS/JVM/AIR execution."""
from pathlib import Path
import copy, hashlib, inspect, json, tempfile
from PIL import Image
import native_tool as tool
import prepare_sources as sources
import verify_results as v

HERE=Path(__file__).resolve().parent
def rows(n=0):
 weapon,role,count=v.CASES[n];base=[0xff505050]*(128*128);final=base.copy()
 for i in range(50,56):final[i]=0xff123456+i
 sparse=[x for i in range(50,56) for x in (i,final[i])]
 frames=[dict(at=10,wall=10010,cost=1,native=[],display=[]),dict(at=510,wall=10510,cost=1,native=sparse,display=sparse),
         dict(at=10010,wall=20010,cost=1,native=sparse,display=sparse)]
 surface=dict(mode='ordinary',sceneLarge=False,x=0,y=0,width=1920,height=1000,originX=0,originY=0,
              roomWidth=48,roomHeight=25,residentChunks=0,backingIdentity=True,uniqueFront=True,staged=True,visible=True)
 common=dict(round=n,weapon=weapon,target=dict(x=1800,y=420),area=dict(x=1736,y=356,w=128,h=128),
  start=10,startWall=10010,end=10011,shots=count,hits=[dict(x=1801,y=420)]*count,sourceFirst=10500,
  attackAttempts=count,attackAccepted=count,firstAttack=dict(accepted=True),firstRejected=None,nativeOracle=sparse,
  baseline=base,baselineDisplay=base,finalNative=final,finalDisplay=final,frames=frames,
  surfaces=[surface],finalSurfaces=[surface],maxCaptureMs=1)
 a=copy.deepcopy(common);a.update(role=role,source=True)
 b=copy.deepcopy(common);b.update(role='join' if role=='host' else 'host',source=False,nativeOracle=[],sourceFirst=0,
                              shots=0,hits=[],attackAttempts=0,attackAccepted=0,firstAttack=None)
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
  assert not r['functional_pass'],'Invalid proof accepted'
 def negative(label,change):
  def check():
   a,b=rows();change(a,b);reject(a,b)
  test(label,check)
 for n in range(4):test('exact ordinary two-way '+str(n),lambda n=n:ok(v.compare(*rows(n))['functional_pass']))
 negative('large-mode front scratch rejects',lambda a,b:b['surfaces'][0].update(sceneLarge=True))
 negative('chunk-size scratch rejects',lambda a,b:b['surfaces'][0].update(width=360,height=360))
 negative('nonresident or unrelated Bitmap rejects',lambda a,b:b['surfaces'][0].update(backingIdentity=False))
 negative('duplicate staged front rejects',lambda a,b:b['surfaces'][0].update(uniqueFront=False))
 negative('hidden native Bitmap rejects',lambda a,b:b['surfaces'][0].update(visible=False))
 negative('leftover chunk rejects',lambda a,b:b['surfaces'][0].update(residentChunks=1))
 negative('nonzero scene origin rejects',lambda a,b:b['surfaces'][0].update(originX=320))
 negative('late switch to scratch rejects',lambda a,b:b.update(finalSurfaces=[dict(b['surfaces'][0],sceneLarge=True)]))
 negative('crop exceeds native front rejects',lambda a,b:(a['area'].update(x=1800),b['area'].update(x=1800)))
 negative('no real wall hit rejects',lambda a,b:a.update(hits=[]))
 negative('no native source mark rejects',lambda a,b:a.update(nativeOracle=[]))
 negative('first native attack rejected cannot pass',lambda a,b:a['firstAttack'].update(accepted=False))
 negative('particle-only remote display rejects',lambda a,b:b.update(finalNative=b['baseline']))
 negative('extra remote pixel rejects',lambda a,b:b['finalNative'].__setitem__(77,0xff505051))
 negative('opaque one-channel one-level difference rejects',lambda a,b:b['finalNative'].__setitem__(50,a['finalNative'][50]+1))
 negative('partial final state rejects',lambda a,b:b['finalNative'].__setitem__(54,0))
 negative('different native baseline rejects',lambda a,b:b['baseline'].__setitem__(77,0))
 negative('different displayed baseline rejects',lambda a,b:b['baselineDisplay'].__setitem__(77,0))
 negative('short observation rejects',lambda a,b:b.update(end=9000))
 negative('no complete intermediate frame rejects',lambda a,b:[f.update(native=[],display=[]) for f in b['frames']])
 def disappear(a,b):
  frame=copy.deepcopy(b['frames'][1]);frame.update(at=600,wall=10600,native=[],display=[]);b['frames'].insert(2,frame)
 negative('persistent mark disappearance before final frame rejects',disappear)
 def source_static():
  actor=(HERE/'tests/LargeWallSurfaceTestDoc.as').read_text(encoding='utf-8')
  assert actor==sources.adapted()[0]
  probe=(HERE/'tests/NativeWallSurfaceProbe.as').read_text(encoding='utf-8')
  between=actor.split('private function before(',1)[1].split('private function savePNG(',1)[0]
  assert 'getVector(' not in between and 'encode(' not in between
  assert 'if(phase!="sampled")throw' in actor and 'peerSampled' in actor and 'sampledSent' in actor
  assert actor.count('gun.attack()')==1 and 'g.invent.addWeapon(id)' in actor and 'g.changeWeapon(id,true)' in actor
  assert 'gun.lvl=gun.perslvl=0;' in actor and 'gun.hold=gun.holder' in actor
  assert 'beginMission("random_mane")' in actor and 'prepareMap(land,SEED,true)' in actor
  assert 'sceneClass.nativeEnabled=false' in actor and 'loc.spaceX-3' not in actor
  for bad in ('.receive(','.hitTile(','.dyrka(','.setPixel','applyTilePatch(', 'Emitter.emit(', 'sceneEnsure('):
   assert bad not in actor+probe,bad
  for gate in ('g.sceneLarge!==false','g.sceneX!=0','g.sceneY!=0','g.rconnectRasterPending===true','g.loc.spaceX!=48',
               'data.width!=1920','data.rect.containsRect(area)','chunks.length!=0','candidate.bitmapData===data',
               'found!=1','bitmap.stage==null','bitmap.visible','bitmap.scaleX!=1'):
   assert gate in probe,gate
  assert probe.count('getVector(')==1 and 'public static function words(' in probe
  assert 'baselineWall:baseline.wall' in actor
 test('source is exact driver04 narrow adaptation with real weapon and post-sampling readback',source_static)
 def runner():
  main,source=tool.adapted_main()
  for gate in ("host_evidence(host_dir)","meta['extension']['tools']==tools()",'audit(candidate)',
               "assert drivers.parent==candidate.parent",'code=run.main()',"source_analyzer_sha256=prepare.sha(path)"):
   assert gate in source,gate
  assert "host_dir==WALL_HOST.resolve()" in source and "default=WALL_HOST" in source
  assert "candidate==(ROOT/'build/m52/recovery-22').resolve()" in source
  import run
  _,native,_=tool.shared.adapted_native(run)
  for flag in ("'--require-exclusive-air'","'--all-mods'","'--private-desktop'","'--wait-host-world'","'--keep-copies'"):
   assert flag in native,flag
  assert run.EXPECTED_INSTALLATION_FILES==22
  for anchor in ('runtime_input_audit',"finally:\n        clean_native_copies(run, result)","require(process.returncode == 0"):
   assert anchor in native,anchor
 test('thin exact22 ACC binding retains existing registry input memory DONE cleanup gates',runner)
 def reviewed_result():
  q=tool.shared.prepare.read(HERE/'recovery22-large-review.json')
  for name,digest in q['inputs'].items():assert tool.shared.prepare.sha(Path(name))==digest,name
  actual=tool.shared.prepare.read(tool.ROOT/'experimental/recovery-wall-surfaces-native-proof-review/recovery22-reanalysis-01.json')
  for name,digest in actual['input_sha256'].items():assert tool.shared.prepare.sha(Path(name))==digest,name
  result=tool.shared.prepare.read(tool.ROOT/'build/m52/recovery22-wall-surfaces-native-01/result.json')
  assert result['frozen_inputs_unchanged'] and result['installation_changes']=={}
  assert all(len(result['runtime_input_audit'][role])==22 for role in ('host','join'))
  assert all(r['functional_pass'] and r['native_wrong']==r['native_extra']==0 for r in actual['rows'])
 test('actual22 large evidence all45 hashes and strict four rounds retained',reviewed_result)
 def artifact_pipeline():
  with tempfile.TemporaryDirectory(prefix='ordinary-proof-',dir=HERE) as name:
   folder=Path(name);logs={role:folder/(role+'.log') for role in ('host','join')};log_rows={role:[] for role in logs}
   for n in range(4):
    for row in rows(n):
     role=row['role'];target=folder/role;target.mkdir(exist_ok=True);proof=target/f'round-{n}-proof.json'
     proof.write_text(json.dumps(row,separators=(',',':')),encoding='utf-8');files=[]
     for suffix,field in [('before-native','baseline'),('after-native','finalNative'),('before-display','baselineDisplay'),('after-display','finalDisplay')]:
      path=target/f'round-{n}-{suffix}.png';im=Image.new('RGBA',(128,128))
      im.putdata([((x>>16)&255,(x>>8)&255,x&255,(x>>24)&255) for x in row[field]]);im.save(path)
      files.append(dict(name=path.name,bytes=path.stat().st_size,width=128,height=128))
     log_rows[role].append(dict(round=n,role=role,bytes=proof.stat().st_size,target=row['target'],source=row['source'],shots=row['shots'],hits=len(row['hits']),
      sourceFirst=row['sourceFirst'],samples=len(row['frames']),attackAttempts=row['attackAttempts'],attackAccepted=row['attackAccepted'],
      firstAttack=row['firstAttack'],firstRejected=row['firstRejected'],nativePixels=len(row['nativeOracle'])//2,files=files))
   def write_logs():
    for role in logs:logs[role].write_text('\n'.join('LARGE WALL PROOF '+json.dumps(r) for r in log_rows[role]),encoding='utf-8')
   write_logs();assert v.analyze(folder,logs)['passed']
   image=folder/'join/round-0-after-native.png';original=image.read_bytes()
   im=Image.open(image).convert('RGBA');im.putpixel((50,0),(0,0,0,255));im.save(image)
   log_rows['join'][0]['files'][1]['bytes']=image.stat().st_size;write_logs();assert not v.analyze(folder,logs)['passed']
   image.write_bytes(original);log_rows['join'][0]['files'][1]['bytes']=len(original);write_logs();assert v.analyze(folder,logs)['passed']
   log_rows['join'].append(copy.deepcopy(log_rows['join'][0]));write_logs();assert not v.analyze(folder,logs)['passed']
 test('32 PNG and8 JSON pipeline rejects forged pixels despite fixed file size and duplicate logs',artifact_pipeline)
 result=dict(passed=all(r['passed'] for r in checks),count=len(checks),failed=sum(not r['passed'] for r in checks),checks=checks,
             offline_only=True,compiled=False,jvm_started=False,air_started=False,native_qualified=False)
 (HERE/'offline-result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result));return 0 if result['passed'] else 1
if __name__=='__main__':raise SystemExit(main())
