"""Use the existing registered scene-driver compiler; bind only isolated metadata."""
import argparse,hashlib,importlib.util,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
CONTROL=ROOT/'experimental/recovery-seed-raster-control'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('output')
    ap.add_argument('--candidate',default='build/m52/recovery-13');ap.add_argument('--gate-expect',choices=['on','off'],default='on')
    ap.add_argument('--compile',action='store_true');ap.add_argument('--registry-wait',type=float,default=900);a=ap.parse_args()
    out=(ROOT/a.output).resolve();candidate=(ROOT/a.candidate).resolve()
    assert out.parent==M52 and not out.exists()
    manifest=read(HERE/'source-manifest.json')
    for name,digest in manifest['files'].items():assert sha(HERE/name)==digest,name
    for name,digest in manifest['ancestors'].items():assert sha(ROOT/name)==digest,name
    sys.path.insert(0,str(CONTROL));from control_inputs import audit,host_input,HOST
    audit(candidate,a.gate_expect)
    sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
    installed=installation();host=host_input(HOST,installed)
    # Reuse the original compiler/registration/22-input checks; no second SWF
    # copy/build implementation. Its HERE hook selects only this test source.
    spec=importlib.util.spec_from_file_location('registered_scene_driver_prepare',CONTROL/'prepare_driver.py')
    tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool);tool.HERE=HERE
    old_argv=sys.argv
    try:
        sys.argv=[str(CONTROL/'prepare_driver.py'),a.output,'--registry-wait',str(a.registry_wait)]+(['--compile'] if a.compile else [])
        tool.main()
    finally:sys.argv=old_argv
    meta=read(out/'prepared.json');assert meta['kind']=='scene-seed-gate-comparison-driver'
    digest=sha(candidate/'RConnectMod.swf')
    save(out/'scene/driver-input.json',dict(candidate_sha256=digest,identical_driver=sha(out/'scene/EffectsDriver.swf') if meta['compiled'] else None))
    save(out/'scene/seed-gate-intent.json',dict(schema=1,expectSeedTicket=a.gate_expect=='on',candidateSha=digest))
    command=[sys.executable,'-B','-X','utf8',str(CONTROL/'native_runner.py'),
        '--candidate',str(candidate/'RConnectMod.swf'),'--effects','--effects-driver',str(out/'scene'),
        '--all-mods','--land','rbl','--seconds','600','--expected-version',
        '0.2.24-recovery13' if a.gate_expect=='on' else '0.2.24-recovery13-seed-off',
        '--port','0','--private-desktop','--defer-visible','--wait-host-world','--require-exclusive-air',
        '--registry-wait',str(a.registry_wait),'--game-candidate',str(HOST/'pfe.swf')]
    save(out/'runtime-command.json',command)
    assert installation()==installed
    meta.update(diagnostic_only=True,diagnostic_kind='round0-join-input-cpu',performance_qualified=False,
        sampler_ancestor_manifest=manifest['ancestor_manifest'],candidate=str(candidate),candidate_sha256=digest,
        seed_gate_expect=a.gate_expect,native_host=host,adapter=str(HERE),adapter_manifest_sha256=sha(HERE/'source-manifest.json'),
        runtime_entry='existing recovery-seed-raster-control/native_runner.py; no copied runner',runtime_tested=False)
    for name in manifest['files']:meta['source_inputs'][str(HERE/name)]=sha(HERE/name)
    meta['source_inputs'][str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
    meta['files']={p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='prepared.json'}
    save(out/'prepared.json',meta)
    print('Diagnostic only. Existing registered runtime command: '+str(out/'runtime-command.json'))
if __name__=='__main__':main()
