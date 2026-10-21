"""Thin freeze/build adapter: one reason overlay, reuse registered compiler only."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import sys
from generate import HERE,ROOT,BASE,BASE_SHA,REL,read,sha,stripped,transformed


def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module);return module


LEGACY=HERE.parent/'recovery-room-restore-diagnostics'
_saved=sys.modules.get('generate')
sys.modules['generate']=load('view_legacy_generator',LEGACY/'generate.py')
try: compiler=load('view_legacy_compiler',LEGACY/'prepare.py')
finally:
    if _saved is None:sys.modules.pop('generate',None)
    else:sys.modules['generate']=_saved
inventory,save=compiler.inventory,compiler.save
KIND='isolated-room-view-reason-diagnostic'


def proposal():
    p=read(HERE/'inputs.json');base=read(BASE/'prepared.json')
    assert base['compiled'] and base['version']=='0.2.24-recovery11'
    assert base['sha256']==p['base_sha256']==BASE_SHA==sha((BASE/'RConnectMod.swf').read_bytes())
    assert p['base_manifest_sha256']==sha((BASE/'prepared.json').read_bytes())
    assert inventory(BASE/'src')==base['source'] and inventory(BASE/'tools')==base['inputs']
    assert inventory(HERE/'src')==p['overlay'] and set(p['overlay'])=={REL}
    original=(BASE/'src'/REL).read_bytes();text=(HERE/'src'/REL).read_text(encoding='utf-8')
    assert p['source'][REL]==sha(original) and stripped(text).encode()==original
    assert transformed(original.decode())==text and p['generator_sha256']==sha((HERE/'generate.py').read_bytes())
    return p,base


def verify(out):
    meta=read(out/'prepared.json');p,base=proposal()
    assert out.parent==(ROOT/'build/m52').resolve() and meta['kind']==KIND and meta['diagnostic_only'] is True
    assert meta['recipe_sha256']==sha(Path(__file__).read_bytes())
    assert meta['base_sha256']==BASE_SHA and meta['base_manifest_sha256']==p['base_manifest_sha256']
    assert inventory(out/'src')==meta['source'] and inventory(out/'tools')==meta['inputs']==base['inputs']
    expected=dict(base['source']);expected.update(p['overlay']);assert meta['source']==expected
    assert inventory(out/'diagnostic-inputs')==meta['diagnostic_inputs']
    assert meta['compiler_adapter_sha256']==sha((LEGACY/'prepare.py').read_bytes())
    assert meta['gameplay_qualified'] is False and meta['performance_qualified'] is False
    if meta['compiled']:assert meta['sha256']==meta['candidate_sha256']==sha((out/'RConnectMod.swf').read_bytes())
    return meta


def freeze(out):
    p,base=proposal();assert out.parent==(ROOT/'build/m52').resolve() and not out.exists()
    shutil.copytree(BASE/'src',out/'src');shutil.copytree(BASE/'tools',out/'tools')
    shutil.copyfile(HERE/'src'/REL,out/'src'/REL)
    audit=out/'diagnostic-inputs';audit.mkdir()
    for name in ('inputs.json','generate.py','prepare.py','run_native.py','check.py','diagnostic.patch','README.md'):
        shutil.copyfile(HERE/name,audit/name)
    driver=ROOT/'build/m52/room-travel-driver-12'
    meta=dict(kind=KIND,version=base['version'],base=str(BASE.relative_to(ROOT)),base_sha256=BASE_SHA,
        base_manifest_sha256=p['base_manifest_sha256'],recipe_sha256=sha(Path(__file__).read_bytes()),
        compiler_adapter_sha256=sha((LEGACY/'prepare.py').read_bytes()),source=inventory(out/'src'),inputs=inventory(out/'tools'),
        diagnostic_inputs=inventory(audit),stripped_equal=True,scene_driver=dict(path=str(driver.relative_to(ROOT)),
        manifest_sha256=sha((driver/'prepared.json').read_bytes())),diagnostic_only=True,compiled=False,air_started=False,
        installed=False,gameplay_qualified=False,performance_qualified=False)
    save(out/'prepared.json',meta);verify(out)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--build',action='store_true');ap.add_argument('--registry-wait',type=float,default=900)
    args=ap.parse_args();out=(ROOT/args.output).resolve()
    if not out.exists():freeze(out)
    else:assert args.build,'Existing evidence is not regenerated';verify(out)
    if args.build:
        sys.path.insert(0,str(ROOT/'tools/validation'));from run_security_terminals import installation
        before=installation();assert len(before)==22
        compiler.verify=verify
        try:compiler.build(out,args.registry_wait)
        finally:
            after=installation();save(out/'compile-installation-audit.json',dict(before=before,after=after,unchanged=before==after))
            assert before==after,'Installation changed during diagnostic compilation'
    print(out)


if __name__=='__main__':main()
