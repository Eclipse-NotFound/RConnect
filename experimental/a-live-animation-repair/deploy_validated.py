"""Install exactly the qualified animation candidate, with a separate real-install smoke receipt."""
from pathlib import Path
import argparse,json,os,uuid
from build_probe import ROOT,GAME,sha,save,installation,Registration
from build_product import inventory,BASE
KEY='mods/Rconnect/release/RConnectMod.swf'
RELEASE=ROOT/'release/RConnectMod.swf'
OLD='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
def read(p):return json.loads(p.read_text('utf-8-sig'))
def verify(product):
 meta=read(product/'prepared.json');compiled=read(product/'compile.json');gate=read(product/'qualification.json')
 assert meta['base_sha256']==OLD and compiled['compiled'] and compiled['reaped'] and compiled['installation_unchanged']
 assert inventory(product/'src')==meta['source'] and compiled['candidate_sha256']==sha(product/'RConnectMod.swf')==gate['candidate_sha256']
 assert gate['passed'] is True
 for path,digest in gate['evidence'].items():assert sha(ROOT/path)==digest,path
 baseline=read(BASE/'prepared.json')['source']
 assert len(meta['source'])==81 and {k for k in baseline if baseline[k]!=meta['source'][k]}==set(meta['overlay'])
 assert set(meta['overlay'])=={'RConnectMod.as','rconnect/game/GameBridge.as','rconnect/game/UnitPresentation.as','rconnect/game/ProjectileVisuals.as','rconnect/game/RemoteMotion.as'}
 assert '0.2.24-animfix1' in (product/'src/RConnectMod.as').read_text('utf8')
 return meta,compiled,gate
def replace(expected,payload,digest):
 assert sha(RELEASE)==expected
 temp=RELEASE.with_name('RConnectMod.swf.animfix-'+uuid.uuid4().hex+'.tmp')
 owned=False
 try:
  with temp.open('xb') as f:owned=True;f.write(payload);f.flush();os.fsync(f.fileno())
  assert sha(temp)==digest and sha(RELEASE)==expected
  os.replace(temp,RELEASE);owned=False
  assert sha(RELEASE)==digest
 finally:
  if owned and temp.exists():temp.unlink()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('product');ap.add_argument('output');ap.add_argument('--install',action='store_true');ap.add_argument('--finish');ap.add_argument('--rollback',action='store_true');args=ap.parse_args()
 product=(ROOT/args.product).resolve();out=(ROOT/args.output).resolve()
 assert product.parent==out.parent==ROOT/'build/m52'
 meta,compiled,gate=verify(product);new=compiled['candidate_sha256'];before=meta['installation_before'];after=dict(before);after[KEY]=new
 assert len(before)==22 and before[KEY]==OLD
 if args.finish:
  installed=read(out/'installation.json');assert installed['status']=='installed-awaiting-smoke'
  run=(ROOT/'build/cooperation'/args.finish).resolve();assert run.parent==ROOT/'build/cooperation'
  info=read(run/'run.json');result=read(run/'registry-result.json');selection=read(run/'reduced-selection-result.json')
  assert Path(info['candidate']).resolve()==RELEASE.resolve() and info['sha256']==new
  assert result['passed'] and selection['passed'] and selection['enabled']==['RConnectMod']
  assert read(run/'reduced-installation-after.json')['unchanged'] and installation()==after
  save(out/'verified.json',dict(status='verified',version='0.2.24-animfix1',release_sha256=new,smoke_run=args.finish,
       smoke_receipt_sha256=sha(run/'registry-result.json'),selection_receipt_sha256=sha(run/'reduced-selection-result.json'),
       installation_after=after,backup_sha256=sha(out/'RConnectMod.before.swf')))
  print('VERIFIED',new);return
 if args.rollback:
  assert sha(out/'RConnectMod.before.swf')==OLD and installation()==after
  with Registration(owner='RConnect / 动画修复回滚',purpose='Restore own RC deployment after failed smoke',run_dir=out,evidence=out/'rollback.json',wait=900) as reg:
   assert installation()==after;replace(new,(out/'RConnectMod.before.swf').read_bytes(),OLD)
   assert installation()==before;save(out/'rollback.json',dict(status='rolled-back',release_sha256=OLD));reg.outcome='completed'
  print('ROLLED BACK');return
 assert installation()==before and sha(RELEASE)==OLD
 if not args.install:print('CHECK PASS',new);return
 assert not out.exists();out.mkdir()
 with Registration(owner='RConnect / 动画修复部署',purpose='Verified RC-only atomic install; no AIR',run_dir=out,evidence=out/'installation.json',wait=900) as reg:
  assert installation()==before
  backup=out/'RConnectMod.before.swf';replaced=False
  state=dict(status='not-installed',version='0.2.24-animfix1',before_sha256=OLD,candidate_sha256=new,
      installation_before=before,expected_installation_after=after,backup=str(backup),
      qualification_sha256=sha(product/'qualification.json'),script_sha256=sha(__file__),registry_id=reg.id)
  try:
   with backup.open('xb') as f:f.write(RELEASE.read_bytes());f.flush();os.fsync(f.fileno())
   assert sha(backup)==OLD
   save(out/'intent.json',state)
   assert installation()==before
   replace(OLD,(product/'RConnectMod.swf').read_bytes(),new);replaced=True
   assert installation()==after
   state.update(status='installed-awaiting-smoke',installation_after=after);reg.outcome='completed'
  except BaseException as error:
   state['error']=repr(error)
   if replaced and sha(RELEASE)==new:replace(new,backup.read_bytes(),OLD);state['status']='rolled-back'
   raise
  finally:
   state['actual_release_sha256']=sha(RELEASE);save(out/'installation.json',state)
 print(state['status'],new)
if __name__=='__main__':main()
