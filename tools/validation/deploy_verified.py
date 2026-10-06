"""Own release only, after independently audited joint checks. Never changes game SWFs."""
import argparse,datetime,hashlib,json,os,shutil,uuid
from pathlib import Path
from run_final_regressions import required_entries
from validation_baseline import verify_protected
ROOT=Path(__file__).resolve().parents[2];GAME=ROOT.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
ap=argparse.ArgumentParser();ap.add_argument('--snapshot',type=Path,required=True);args=ap.parse_args()
out=args.snapshot.resolve();assert out.parent==ROOT/'build/m46' and out.name.startswith('final')
m=read(out/'source-input.json');e=read(ROOT/'knowledge/experiments/m46-validation-evidence.json')
REQUIRED=required_entries(m);baseline=verify_protected(m)
assert e['required_entries']==REQUIRED and len(e['runs'])==len(REQUIRED) and e['fail']==0
assert {r['entry'] for r in e['runs']}==set(REQUIRED) and all(r['exit']==0 and r['fail']==0 for r in e['runs'])
assert e['candidate']['sha256']==m['candidate_sha256'] and e['candidate']['source_manifest_sha256']==sha(out/'source-input.json')
assert e['candidate']['verification_manifest_sha256']==sha(out/'verified-test-input.json')
source=out/'RConnectMod.swf';target=ROOT/'release/RConnectMod.swf'
actual={line.split()[0] for line in (out/'classes.txt').read_text(encoding='utf-8-sig').splitlines() if line.strip()}
expected={p.relative_to(out/'src').with_suffix('').as_posix().replace('/','.') for p in (out/'src').rglob('*.as')}
assert actual==expected and len(actual)==m['classes']==e['candidate']['classes']
assert sha(source)==m['candidate_sha256'] and m['build_exit']==0
for name,digest in m['source'].items():assert sha(ROOT/name)==sha(out/name)==digest,name
for name,digest in read(out/'verified-test-input.json').items():assert sha(ROOT/name)==sha(out/'verified-files'/name)==digest,name
for name,digest in e['protected']['hashes'].items():assert sha(GAME/name)==digest,name
old=baseline['release_sha256'];assert sha(target)==old
receipt=out/'deployment.json';assert not receipt.exists()
stamp=datetime.datetime.now().astimezone();token=stamp.strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:6]
backup=ROOT/'build/backup'/('m46-release-'+token);backup.mkdir(parents=True,exist_ok=False)
saved=backup/'RConnectMod.before.swf';shutil.copy2(target,saved);assert sha(saved)==old
record={'status':'deployed-awaiting-smoke','at':stamp.isoformat(),'version':m['version'],'sha256':sha(source),
    'size':source.stat().st_size,'classes':len(actual),'previous_sha256':old,'backup':saved.relative_to(ROOT).as_posix(),
    'snapshot':out.relative_to(ROOT).as_posix(),'protected':e['protected']['count'],
    'authorization':'既有用户候选部署授权及三方由本会话统一部署；仅更新本模组release，保留已部署紧凑UI。',
    'baseline_path':m.get('baseline_path','build/m46/integration-baseline'),
    'deployment_script_sha256':sha(Path(__file__))}
receipt.write_text(json.dumps(record,indent=2,ensure_ascii=False),encoding='utf-8')
temp=target.with_name('RConnectMod.'+uuid.uuid4().hex+'.tmp')
try:
    shutil.copy2(source,temp);assert sha(temp)==m['candidate_sha256'];os.replace(temp,target)
finally:
    if temp.exists():temp.unlink()
assert sha(target)==record['sha256'];print(json.dumps(record,ensure_ascii=False))
