"""Append a separate host03 acceptance receipt, never rewrite frozen evidence.

Pure file verification only. Does not compile, launch a game or modify install.
"""
import argparse,hashlib,json,sys
from pathlib import Path
from readback import verify_grafon

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
HOST=M52/'recovery-first-raster-host-03';BASE=M52/'recovery-native-travel-host-01/pfe.swf'
HOST_SHA='fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e'
RECEIPT_SHA='1dfa42c494c33eafb0cab1ca5b6ad43f5a6ae73419ce657827e952a4dfd74312'
REL='fe/graph/Grafon.as'
REPRESENTATIVES=('MainFE','fe.World','fe.loc.Game','fe.loc.Land','fe.loc.Location','fe.inter.Camera','fe.inter.GUI')
sys.path.insert(0,str(ROOT/'tools/validation'))
from prepare_recovery_native_travel import normalized,movie_header
from run_security_terminals import installation
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from patch_native import swf_tags

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def inventory(path):return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*')) if p.is_file()}

def verify():
    before=inventory(HOST);receipt=read(HOST/'prepared.json')
    assert sha(HOST/'prepared.json')==RECEIPT_SHA and sha(HOST/'pfe.swf')==receipt['candidate_sha256']==HOST_SHA
    assert receipt['kind']=='isolated-first-raster-host' and receipt['compiled'] is True
    assert receipt['validated'] is False and receipt['error']=="AssertionError('sceneEnsure')"
    assert receipt['source_unchanged'] and receipt['installed_unchanged'] and not receipt['air_started']
    assert sha(BASE)==receipt['base_sha256']
    # The old verifier is not edited either: every recorded source/tool input
    # must remain byte-identical, with no exempted hash or synthetic manifest.
    for path,h in receipt['inputs'].items():assert sha(path)==h,path
    for name,h in receipt['import_sources'].items():assert sha(HOST/'import'/name)==h,name
    installed=installation();assert len(installed)==22 and installed==receipt['installation_before']
    for label in ('before.log','import.log','after.log','before-classes.txt','after-classes.txt'):
        assert (HOST/label).is_file() and (HOST/(label+'.stderr.log')).is_file(),label
        error=(HOST/(label+'.stderr.log')).read_text(encoding='utf-8',errors='replace')
        assert not any(v in error for v in ('SEVERE:','Unknown preprocessor instruction','Exception in thread')),label
    reference=ROOT/'build/m52/recovery-native-travel-host-01/after/scripts'/REL
    assert normalized((HOST/'before/scripts'/REL).read_text(encoding='utf-8-sig'))==normalized(reference.read_text(encoding='utf-8-sig'))
    verify_grafon((HOST/'import'/REL).read_text(encoding='utf-8-sig'))
    verify_grafon((HOST/'after/scripts'/REL).read_text(encoding='utf-8-sig'))
    representatives={}
    for name in REPRESENTATIVES:
        relative=Path(*name.split('.')).with_suffix('.as')
        original=normalized((HOST/'before/scripts'/relative).read_text(encoding='utf-8-sig'))
        actual=normalized((HOST/'after/scripts'/relative).read_text(encoding='utf-8-sig'))
        assert original==actual,name
        representatives[name]=hashlib.sha256(original.encode()).hexdigest()
    old,new=swf_tags(BASE),swf_tags(HOST/'pfe.swf');assert len(old)==len(new);changed=[]
    for index,(a,b) in enumerate(zip(old,new)):
        assert a[0]==b[0]
        if a!=b:assert a[0] in (72,82);changed.append(index)
    assert changed and movie_header(BASE)==movie_header(HOST/'pfe.swf')
    assert normalized((HOST/'before-classes.txt').read_text(encoding='utf-8-sig'))==normalized((HOST/'after-classes.txt').read_text(encoding='utf-8-sig'))
    assert inventory(HOST)==before and installation()==installed
    return dict(kind='isolated-first-raster-host-readback-recheck',validated=True,passed=True,
        candidate_sha256=HOST_SHA,original_failed_receipt_sha256=RECEIPT_SHA,
        original_receipt_preserved=True,original_source_and_tool_inputs_unchanged=True,
        host_directory=str(HOST),host_files=before,installation=installed,
        installation_unchanged=True,representatives=representatives,changed_code_tags=changed,
        non_code_tags_unchanged=True,loader_unchanged=True,class_list_unchanged=True,movie_header_unchanged=True,
        verifier_inputs={str(p):sha(p) for p in (Path(__file__),HERE/'readback.py',HERE/'test_readback.py')},
        compiled_in_this_run=False,air_started=False,gameplay_qualified=False,performance_qualified=False,
        audit_scope='Guard branch semantics plus original class/source/tag/header checks; not full ABC semantic audit')

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==M52 and not out.exists(),'Use a fresh direct build/m52 output'
    result=verify();out.mkdir()
    (out/'receipt.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=True,candidate_sha256=HOST_SHA,output=str(out),air_started=False)))
if __name__=='__main__':main()
