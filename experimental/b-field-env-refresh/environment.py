"""Audit/freeze a B environment and assemble a SMALL isolated overlay, never install.

audit is read-only; lock writes a new JSON under this directory. assemble only
writes a fresh subdirectory here. Binary inputs are pinned before/after copying.
No game resources, user preferences, saves, or retired ModSettings are copied.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, zlib

HERE=Path(__file__).resolve().parent
RC=HERE.parents[1]
GAME=RC.parents[1]
OLD=RC/'build/ab/b3-playable-190/game'
NATIVE_SHA='eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063'
OFF={'ContinuousSceneMod','RealisticVisionMod','LightAndDarknessMod'}
BRIDGES={
 'SandevistanMod':('SandyAuthorityAPI','attach'),
 'TDFCMod':('TDFCAuthorityCarrier','attachAuthority'),
 'MoreSkillsWeaponsMod':('MSWAuthorityAPI','beforePlayer','afterRoom','present'),
 'PermanentInjuryMod':('PermanentInjuryCarrier','attachAuthority','presentAuthority'),
 'FirearmAttachmentsMod':('FAAuthorityAPI','attach'),
 'AddictionSystemMod':('AddictionAuthorityAPI','attach'),
}
INDEPENDENT={'SandevistanMod','TDFCMod','PermanentInjuryMod','FirearmAttachmentsMod','AddictionSystemMod'}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save_new(p,value):
 with Path(p).open('x',encoding='utf-8') as f:json.dump(value,f,ensure_ascii=False,indent=2)
def bounded(name):
 p=Path(name);p=(p if p.is_absolute() else HERE/p).resolve()
 if not p.is_relative_to(HERE) or p==HERE:raise ValueError('Only this independent preparation directory is writable')
 return p
def swf_strings(p,names):
 data=Path(p).read_bytes()
 if data[:3]==b'CWS':data=data[:8]+zlib.decompress(data[8:])
 elif data[:3]!=b'FWS':raise ValueError('Unsupported SWF compression: '+str(p))
 return {s:s.encode() in data for s in names}
def inventory():
 launcher=GAME/'mods/ModLoader/RemainsModLauncher.exe'
 result=subprocess.run([str(launcher),'--root',str(GAME),'--list','--json','--no-ui'],capture_output=True,check=True)
 raw=json.loads(result.stdout.decode('utf-8-sig'))
 # The scanner is the source of truth. A changed schema must fail visibly.
 rows=raw if isinstance(raw,list) else raw.get('mods') or raw.get('Mods')
 if not isinstance(rows,list):raise ValueError('Unknown launcher JSON schema: '+str(raw)[:500])
 mods=[]
 for row in rows:
  entry=row.get('entry') or row.get('Entry')
  directory=row.get('directory') or row.get('Directory')
  if not entry or not directory:raise ValueError('Unknown scanner row: '+str(row))
  if entry=='ModSettingsMod':continue
  directory=Path(directory).name
  source=GAME/'mods'/directory/'release'/(entry+'.swf')
  if not source.is_file():raise ValueError('Scanner path does not resolve: '+str(source))
  old=OLD/'mods'/directory/'release'/(entry+'.swf')
  mods.append(dict(entry=entry,directory=directory,path=source.relative_to(GAME).as_posix(),sha256=sha(source),
    bytes=source.stat().st_size,enabled=entry not in OFF,old_sha256=sha(old) if old.is_file() else None,
    bridge_symbols=swf_strings(source,BRIDGES.get(entry,())),independent_required=entry in INDEPENDENT))
 if {m['entry'] for m in mods}&OFF!=OFF:raise ValueError('One of the three requested disabled modules is missing')
 if not {'RConnectMod','ModLoaderMod',*INDEPENDENT}.issubset(m['entry'] for m in mods):raise ValueError('Required environment module missing')
 aux=['mods/ModLoader/RemainsModLauncher.exe','mods/ModLoader/supported-mods.txt',
      'mods/RandomRooms/release/RandomRoomsEditor.swf','mods/PermanentInjury/default-config.json',
      'mods/Sandevistan/release/sandy_theme.mp3']
 return dict(schema=1,kind='b-environment-source-lock',native_baseline_sha256=NATIVE_SHA,
   disabled=sorted(OFF),mods=mods,auxiliary={p:sha(GAME/p) for p in aux},
   preferences='fresh test AIR identity; compiled defaults; never copy LocalStore or player preferences')
def verify_lock(lock,candidates=None):
 candidates=candidates or {}
 for m in lock['mods']:
  e=m['entry']
  if e in candidates:
   # The formal digest stays in the review lock as history, but this source
   # is not copied. Pin the independent replacement that assemble will use.
   c=candidates[e];p=Path(c['path']).resolve()
   if not p.is_relative_to(RC) or p.is_relative_to(RC/'release'):raise ValueError('Candidate must be an independent RConnect artifact: '+e)
   if sha(p)!=c['sha256']:raise ValueError('Candidate digest mismatch: '+e)
  elif sha(GAME/m['path'])!=m['sha256']:raise ValueError('Release changed since review: '+e)
 for p,h in lock['auxiliary'].items():
  if sha(GAME/p)!=h:raise ValueError('Auxiliary source changed: '+p)
def assemble(lock,receipt,out):
 if out.exists():raise FileExistsError('Use a new overlay directory')
 if receipt.get('kind')!='b-environment-candidate-inputs':raise ValueError('Explicit candidate input receipt required')
 if receipt.get('base_native_sha256')!=NATIVE_SHA:raise ValueError('Wrong B native baseline')
 # Do not silently omit an unadapted default-on mod. A build receipt need not
 # claim runtime qualification, but must identify each actual interface.
 candidates=receipt.get('modules',{})
 required=INDEPENDENT|{'RConnectMod'}
 if not required.issubset(candidates):raise ValueError('Missing independent candidates: '+','.join(sorted(required-set(candidates))))
 verify_lock(lock,candidates)
 inputs={}
 for m in lock['mods']:
  e=m['entry'];p=GAME/m['path'];expected=m['sha256']
  if e in candidates:
   c=candidates[e];p=Path(c['path']).resolve();expected=c['sha256']
   if not p.is_relative_to(RC) or p.is_relative_to(RC/'release'):raise ValueError('Candidate must be an independent RConnect artifact: '+e)
   if e in INDEPENDENT and c.get('authority_api')!=1:raise ValueError('Missing B authority contract: '+e)
  if sha(p)!=expected:raise ValueError('Candidate digest mismatch: '+e)
  if e in BRIDGES and not all(swf_strings(p,BRIDGES[e]).values()):raise ValueError('Required B API symbols missing: '+e)
  inputs[m['path']]=(p,expected)
 native=receipt.get('native',{})
 p=Path(native.get('path','')).resolve()
 if not p.is_relative_to(RC) or not p.is_file() or sha(p)!=native.get('sha256'):raise ValueError('Pinned candidate native host required')
 if not {'b3-v12','permanent-injury-v1'}.issubset(native.get('capabilities',[])):raise ValueError('B and PI native interfaces both required')
 if not all(swf_strings(p,['rconnectRoomStep','piEvent','piFactor','piShot']).values()):raise ValueError('Native interface symbols absent')
 inputs['pfe.swf']=(p,native['sha256'])
 out.mkdir(parents=True)
 for name,(p,h) in inputs.items():
  dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dest)
  if sha(dest)!=h or sha(p)!=h:raise ValueError('Copy verification failed: '+name)
 for name,h in lock['auxiliary'].items():
  if name.endswith('default-config.json'):name_to='mods/PermanentInjury/release/config.json'
  else:name_to=name
  dest=out/name_to;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(GAME/name,dest)
  if sha(dest)!=h:raise ValueError('Auxiliary copy mismatch: '+name)
 # These files intentionally supersede copied runtime overrides only inside a
 # future test root. Local game files contain cooldown=0, not factory defaults.
 defaults={
  'mods/Sandevistan/release/config.txt':'# B test: use compiled factory defaults.\n',
  'mods/RealisticVision/release/config.txt':'# B test: disabled by launcher.\n',
  'mods/WallBlend/release/config.json':'{}\n',
 }
 for name,text in defaults.items():
  dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text,encoding='utf-8')
 enabled=[m['entry'] for m in lock['mods'] if m['enabled']]
 plan=dict(kind='b-environment-overlay',source_lock=lock,inputs=receipt,enabled=enabled,
   disabled=sorted(OFF),launcher_arguments=['--root','<isolated-game>','--only',','.join(enabled),'--no-ui'],
   config_requirements={'remove':['rv'],'required':['tdfc','msw','sandy','injury','fa','addiction']},
   clear_only_in_isolated_test=['mods/RModifier/config/active.json','mods/RModifier/config/active.previous.json','mods/RModifier/config/map-pools.json'],
   require_fresh_test_storage=True,installed=False,runtime_qualified=False,
   note='Merge this overlay into an independently prepared test runtime; run launcher there. Never copy A RConnectMod or player preferences.')
 plan['files']={p.relative_to(out).as_posix():sha(p) for p in out.rglob('*') if p.is_file()}
 save_new(out/'assembly.json',plan);verify_lock(lock,candidates)
 return {'overlay':str(out),'files':len(plan['files']),'installed':False,'runtime_qualified':False}
def main():
 ap=argparse.ArgumentParser();sub=ap.add_subparsers(dest='mode',required=True)
 sub.add_parser('audit')
 p=sub.add_parser('lock');p.add_argument('--output',default='environment-lock.json')
 p=sub.add_parser('assemble');p.add_argument('--lock',default='environment-lock.json');p.add_argument('--inputs',required=True);p.add_argument('--output',required=True)
 a=ap.parse_args()
 if a.mode=='audit':value=inventory()
 elif a.mode=='lock':value=inventory();save_new(bounded(a.output),value)
 else:value=assemble(read(bounded(a.lock)),read(Path(a.inputs)),bounded(a.output))
 print(json.dumps(value,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
