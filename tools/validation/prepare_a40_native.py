"""Freeze published WallBlend native tests; only adapt exact version expectations."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from prepare_a33_rv import compile_as

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT.parents[1]
WB=ROOT.parent/'WallBlend'
BASE='f32e4a99643ccc901dc4f8e8caac29a6cde441b4'
KINDS=('Harness','Destruction','Coverage','Scene','Field')

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('candidate',type=Path)
    ap.add_argument('--runtime',type=Path,default=Path('build/m52/a22-map-runtime-17'))
    args=ap.parse_args();out=(ROOT/args.candidate).resolve();runtime=(ROOT/args.runtime).resolve()
    assert out.parent==runtime.parent==ROOT/'build/m52'
    m=json.loads((out/'prepared.json').read_text(encoding='utf-8'))
    r=json.loads((runtime/'inputs.json').read_text(encoding='utf-8'))
    assert sha(out/'WallBlendMod.swf')==m['candidate_sha256']
    assert sha(out/'control.swf')==m['baseline_sha256']
    assert not (out/'native').exists()
    native=out/'native';native.mkdir()
    files=subprocess.check_output(['git','-C',str(WB),'ls-tree','-r','--name-only',BASE,'tests'],text=True).splitlines()
    original={n:subprocess.check_output(['git','-C',str(WB),'show',BASE+':'+n]) for n in files if n.endswith('.as')}
    records={}
    air=GAME/'mods/Sandevistan/build/tools/airsdk/frameworks/libs/air/airglobal.swc'
    for role,version in (('control','0.5.4-scene'),('candidate',m['version'])):
        dest=native/role/'tests';dest.mkdir(parents=True)
        for name,body in original.items():
            # Exact identity is updated, no behavioral or performance condition.
            updated=body.replace(b'entry["status"].version=="0.5.3"',('entry["status"].version=="'+version+'"').encode())
            updated=updated.replace(b'status.version=="0.5.3"',('status.version=="'+version+'"').encode())
            p=dest/Path(name).relative_to('tests');p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(updated)
            records[p.relative_to(native).as_posix()]=dict(source=hashlib.sha256(body).hexdigest(),adapted=sha(p))
        for kind in KINDS:
            compile_as(dest/('WallBlend'+kind+'Doc.as'),native/role/('WallBlend'+kind+'.swf'),[dest],[air])
    config=subprocess.check_output(['git','-C',str(WB),'show',BASE+':build/config.modes.example.json'])
    (native/'config.json').write_bytes(config)
    assets={n:h for n,h in r['files'].items() if n=='pfe.swf' or n.startswith('Rooms/') or
        n in ('texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','text_en.xml','rooms.xml')}
    assert 'pfe.swf' in assets
    for n,h in assets.items():assert sha(runtime/'game'/n)==h,n
    manifest=dict(test_commit=BASE,records=records,runtime=str(runtime),runtime_manifest=sha(runtime/'inputs.json'),
        assets=assets,config_sha256=sha(native/'config.json'),candidate=m['candidate_sha256'],control=m['baseline_sha256'],
        swfs={p.relative_to(native).as_posix():sha(p) for p in native.glob('*/*.swf')},preparer_sha256=sha(__file__),
        adaptation='Only exact expected WallBlend version; all behavior, pixels, workload and performance assertions unchanged.')
    (native/'prepared.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps(dict(tests=len(manifest['swfs']),asset_files=len(assets),asset_bytes=sum((runtime/'game'/n).stat().st_size for n in assets))))

if __name__=='__main__':main()
